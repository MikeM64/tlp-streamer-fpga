--
-- TLP Streamer - PCIe TLP Interface
--
-- (c) MikeM64 - 2022
--

-- From this component's perspective, all references to TX are for Host -> PCIe direction
-- and all RX references are PCIe -> Host

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.tlp_streamer_records.all;

entity tlp_streamer_pcie_tlp is
    port (
        sys_clk_i   : in std_logic;
        pcie_clk_i  : in std_logic;
        pcie_rst_i  : in std_logic;
        -- Host Packet RX/TX management
        dispatch_i : in dispatch_producer_r;
        dispatch_o : out dispatch_consumer_r;
        arbiter_i : in arbiter_producer_r;
        arbiter_o : out arbiter_consumer_r;
        -- PCIe Core TLP Interface
        pcie_tlp_tx_producer_i : in pcie_tlp_tx_port_producer_r;
        pcie_tlp_tx_consumer_o : out pcie_tlp_tx_port_consumer_r;
        pcie_tlp_rx_producer_i : in pcie_tlp_rx_port_producer_r;
        pcie_tlp_rx_consumer_o : out pcie_tlp_rx_port_consumer_r);
end entity tlp_streamer_pcie_tlp;

architecture RTL of tlp_streamer_pcie_tlp is

component fifo_pcie_tlp_r64_w32_4096_bram IS
  port (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    valid : OUT STD_LOGIC;
    wr_rst_busy : OUT STD_LOGIC;
    rd_rst_busy : OUT STD_LOGIC
  );
end component fifo_pcie_tlp_r64_w32_4096_bram;

component fifo_pcie_tlp_r32_w64_4096_bram IS
  port (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    valid : OUT STD_LOGIC;
    wr_rst_busy : OUT STD_LOGIC;
    rd_rst_busy : OUT STD_LOGIC
  );
end component fifo_pcie_tlp_r32_w64_4096_bram;

component pcie_tlp_ila IS
    port (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe5 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        probe6 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        probe7 : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        probe8 : IN STD_LOGIC_VECTOR(63 DOWNTO 0)
);
end component pcie_tlp_ila;

-- TX FSM Signals and types
type pcie_tlp_tx_req_state is (PCIE_TLP_TX_IDLE, PCIE_TLP_TX_PACKET_START, PCIE_TLP_TX_PACKET_PARSE_HEADER,
                               PCIE_TLP_TX_PACKET);

signal current_pcie_tlp_tx_req_state, next_pcie_tlp_tx_req_state: pcie_tlp_tx_req_state;

signal pcie_tlp_fifo_tx_wr_en_s, next_pcie_tlp_fifo_tx_wr_en_s: std_logic;
signal pcie_tlp_fifo_tx_rd_en_s: std_logic;
signal pcie_tlp_fifo_tx_rd_data_s: std_logic_vector(63 downto 0);
signal pcie_tlp_fifo_tx_rd_empty_s: std_logic;
signal pcie_tlp_fifo_tx_rd_valid_s: std_logic;

-- This is the number of qwords to read from the TX FIFO when transmitting
-- packets towards the PCIe core
-- 514 is (1024 DW Max TLP Payload + 4 DW Max TLP Header == 1028 DW == 514 QW)
signal pcie_tlp_tx_qwords_to_read, next_pcie_tlp_tx_qwords_to_read: integer range 0 to 514;


-- RX FSM Signals and types
type pcie_tlp_rx_req_state is (PCIE_TLP_AWAIT_RX, PCIE_TLP_RX_WRITE_HEADER, PCIE_TLP_RX_WRITE_TLP);

signal current_pcie_tlp_rx_req_state, next_pcie_tlp_rx_req_state: pcie_tlp_rx_req_state;
signal ila_current_tlp_state: std_logic_vector(2 downto 0);

signal pcie_tlp_fifo_rx_wr_data_s, next_pcie_tlp_fifo_rx_wr_data_s: std_logic_vector(63 downto 0);
-- Buffer to allow time for the header to be added to the RX FIFO ahead of the RXd TLP
signal pcie_tlp_rx_buffer_s_1, pcie_tlp_rx_buffer_s_2: std_logic_vector(63 downto 0);
signal pcie_tlp_rx_buffer_valid_s_1, pcie_tlp_rx_buffer_valid_s_2: std_logic;
signal pcie_tlp_fifo_rx_wr_en_s, next_pcie_tlp_fifo_rx_wr_en_s: std_logic;
signal pcie_tlp_fifo_rx_rd_data_s: std_logic_vector(31 downto 0);
signal pcie_tlp_fifo_rx_rd_en_s, next_pcie_tlp_fifo_rx_rd_en_s: std_logic;
signal pcie_tlp_fifo_rx_wr_full_s: std_logic;

begin

comp_pcie_tlp_tx_fifo: fifo_pcie_tlp_r64_w32_4096_bram
    port map(
        rst => pcie_rst_i,
        wr_clk => sys_clk_i,
        rd_clk => pcie_clk_i,
        din => dispatch_i.dispatch_wr_data(31 downto 0),
        wr_en => pcie_tlp_fifo_tx_wr_en_s,
        rd_en => pcie_tlp_fifo_tx_rd_en_s,
        dout => pcie_tlp_fifo_tx_rd_data_s,
        full => dispatch_o.dispatch_wr_full,
        empty => pcie_tlp_fifo_tx_rd_empty_s,
        valid => pcie_tlp_fifo_tx_rd_valid_s,
        wr_rst_busy => open,
        rd_rst_busy => open);

comp_pcie_tlp_rx_fifo: fifo_pcie_tlp_r32_w64_4096_bram
    port map(
        rst => pcie_rst_i,
        wr_clk => pcie_clk_i,
        rd_clk => sys_clk_i,
        din => pcie_tlp_fifo_rx_wr_data_s,
        wr_en => pcie_tlp_fifo_rx_wr_en_s,
        rd_en => arbiter_i.arbiter_rd_en,
        dout(31 downto 24) => pcie_tlp_fifo_rx_rd_data_s(7 downto 0),
        dout(23 downto 16) => pcie_tlp_fifo_rx_rd_data_s(15 downto 8),
        dout(15 downto 8) => pcie_tlp_fifo_rx_rd_data_s(23 downto 16),
        dout(7 downto 0) => pcie_tlp_fifo_rx_rd_data_s(31 downto 24),
        full => pcie_tlp_fifo_rx_wr_full_s,
        empty => arbiter_o.arbiter_rd_empty,
        valid => arbiter_o.arbiter_rd_valid,
        wr_rst_busy => open,
        rd_rst_busy => open);

pcie_tlp_rx_tx_async_process: process(dispatch_i, pcie_tlp_fifo_rx_rd_data_s)
begin

    pcie_tlp_fifo_tx_wr_en_s <= dispatch_i.dispatch_wr_en and
                                dispatch_i.dispatch_valid;
    -- The extra 1's here correspond to the byte_enable portion of the
    -- data sent to the FT601
    arbiter_o.arbiter_rd_data <= "1111" & pcie_tlp_fifo_rx_rd_data_s;

end process pcie_tlp_rx_tx_async_process;

pcie_tlp_tx_fsm_clock_process: process(pcie_clk_i, pcie_rst_i, next_pcie_tlp_tx_req_state,
                                       next_pcie_tlp_tx_qwords_to_read)
begin

    if (pcie_rst_i = '1') then
        current_pcie_tlp_tx_req_state <= PCIE_TLP_TX_IDLE;
        pcie_tlp_tx_qwords_to_read <= 0;
    elsif (rising_edge(pcie_clk_i)) then
        current_pcie_tlp_tx_req_state <= next_pcie_tlp_tx_req_state;
        pcie_tlp_tx_qwords_to_read <= next_pcie_tlp_tx_qwords_to_read;
    end if;

end process pcie_tlp_tx_fsm_clock_process;

pcie_tlp_tx_fsm_data_output_process: process(current_pcie_tlp_tx_req_state,
                                             pcie_tlp_tx_qwords_to_read, pcie_tlp_fifo_tx_rd_data_s,
                                             pcie_tlp_fifo_tx_rd_valid_s)
begin

    pcie_tlp_fifo_tx_rd_en_s <= '0';
    next_pcie_tlp_tx_qwords_to_read <= pcie_tlp_tx_qwords_to_read;
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tdata <= (others => '0');
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tuser <= (others => '0');
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tkeep <= (others => '0');
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tlast <= '0';
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tvalid <= '0';

    case current_pcie_tlp_tx_req_state is
        when PCIE_TLP_TX_IDLE =>
            next_pcie_tlp_tx_qwords_to_read <= 0;
        when PCIE_TLP_TX_PACKET_START =>
            pcie_tlp_fifo_tx_rd_en_s <= '1';
            next_pcie_tlp_tx_qwords_to_read <= 0;
        when PCIE_TLP_TX_PACKET_PARSE_HEADER =>
            -- The first double-word out of the FIFO is the tlp_streamer header.
            -- Use the length to know when to stop transmitting towards the
            -- PCIe core
            next_pcie_tlp_tx_qwords_to_read <= to_integer(unsigned(pcie_tlp_fifo_tx_rd_data_s(63 downto 48))) / 2;
            pcie_tlp_fifo_tx_rd_en_s <= '1';
        when PCIE_TLP_TX_PACKET =>
            pcie_tlp_fifo_tx_rd_en_s <= '1';
            pcie_tlp_tx_consumer_o.tlp_axis_tx_tdata <= pcie_tlp_fifo_tx_rd_data_s;
            pcie_tlp_tx_consumer_o.tlp_axis_tx_tkeep <= (others => '1');
            if (pcie_tlp_tx_qwords_to_read = 0) then
                pcie_tlp_tx_consumer_o.tlp_axis_tx_tlast <= '1';
            end if;
            pcie_tlp_tx_consumer_o.tlp_axis_tx_tvalid <= pcie_tlp_fifo_tx_rd_valid_s;
            next_pcie_tlp_tx_qwords_to_read <= pcie_tlp_tx_qwords_to_read - 1;
    end case;

end process pcie_tlp_tx_fsm_data_output_process;

pcie_tlp_tx_fsm_state_select_process: process(current_pcie_tlp_tx_req_state, pcie_tlp_fifo_tx_rd_empty_s,
                                              pcie_tlp_tx_producer_i, pcie_tlp_tx_qwords_to_read)
begin

    next_pcie_tlp_tx_req_state <= current_pcie_tlp_tx_req_state;

    case current_pcie_tlp_tx_req_state is
        when PCIE_TLP_TX_IDLE =>
            if (pcie_tlp_fifo_tx_rd_empty_s = '0' and
                pcie_tlp_tx_producer_i.tlp_axis_tx_tready = '1') then
                next_pcie_tlp_tx_req_state <= PCIE_TLP_TX_PACKET_START;
            end if;
        when PCIE_TLP_TX_PACKET_START =>
            next_pcie_tlp_tx_req_state <= PCIE_TLP_TX_PACKET_PARSE_HEADER;
        when PCIE_TLP_TX_PACKET_PARSE_HEADER =>
            next_pcie_tlp_tx_req_state <= PCIE_TLP_TX_PACKET;
        when PCIE_TLP_TX_PACKET =>
            if (pcie_tlp_tx_qwords_to_read = 0) then
                next_pcie_tlp_tx_req_state <= PCIE_TLP_TX_IDLE;
            end if;
    end case;

end process pcie_tlp_tx_fsm_state_select_process;

comp_pcie_tlp_ila: pcie_tlp_ila
    port map(
        clk => pcie_clk_i,
        probe0(0) => pcie_tlp_rx_producer_i.tlp_axis_rx_tvalid,
        probe1(0) => pcie_tlp_rx_producer_i.tlp_axis_rx_tlast,
        probe2(0) => pcie_tlp_rx_buffer_valid_s_1,
        probe3(0) => pcie_tlp_rx_buffer_valid_s_2,
        probe4(0) => pcie_tlp_fifo_rx_wr_en_s,
        probe5 => ila_current_tlp_state,
        probe6 => pcie_tlp_rx_buffer_s_1,
        probe7 => pcie_tlp_rx_buffer_s_2,
        probe8 => pcie_tlp_fifo_rx_wr_data_s);

pcie_tlp_rx_clock_process: process(pcie_clk_i, pcie_rst_i, next_pcie_tlp_rx_req_state,
                                   next_pcie_tlp_fifo_rx_wr_data_s, next_pcie_tlp_fifo_rx_wr_en_s,
                                   pcie_tlp_rx_producer_i)
begin

    if (pcie_rst_i = '1') then
        current_pcie_tlp_rx_req_state <= PCIE_TLP_AWAIT_RX;
        pcie_tlp_fifo_rx_wr_data_s <= (others => '0');
        pcie_tlp_fifo_rx_wr_en_s <= '0';
    elsif (rising_edge(pcie_clk_i)) then
        current_pcie_tlp_rx_req_state <= next_pcie_tlp_rx_req_state;
        ila_current_tlp_state <= std_logic_vector(to_unsigned(pcie_tlp_rx_req_state'POS(next_pcie_tlp_rx_req_state), 3));
        pcie_tlp_fifo_rx_wr_data_s <= next_pcie_tlp_fifo_rx_wr_data_s;
        pcie_tlp_fifo_rx_wr_en_s <= next_pcie_tlp_fifo_rx_wr_en_s;

        pcie_tlp_rx_buffer_s_1 <= pcie_tlp_rx_producer_i.tlp_axis_rx_tdata;
        pcie_tlp_rx_buffer_s_2 <= pcie_tlp_rx_buffer_s_1;

        pcie_tlp_rx_buffer_valid_s_1 <= pcie_tlp_rx_producer_i.tlp_axis_rx_tvalid;
        pcie_tlp_rx_buffer_valid_s_2 <= pcie_tlp_rx_buffer_valid_s_1;
    end if;

end process pcie_tlp_rx_clock_process;

pcie_tlp_rx_fsm_data_output_process: process(current_pcie_tlp_rx_req_state, pcie_tlp_fifo_rx_wr_full_s,
                                             pcie_tlp_rx_buffer_s_1, pcie_tlp_rx_buffer_s_2, pcie_tlp_rx_producer_i,
                                             pcie_tlp_rx_buffer_valid_s_2)

variable pcie_tlp_rx_packet_len_v: integer range 0 to 65535;
variable pcie_tlp_hdr_len_v: integer range 3 to 4;

begin

    pcie_tlp_rx_consumer_o.tlp_axis_rx_tready <= not pcie_tlp_fifo_rx_wr_full_s;
    next_pcie_tlp_fifo_rx_wr_en_s <= '0';
    -- Need to word-swap the AXI interface so that the correct word is sent
    -- out on the wire first. Refer to page 47 of pg054.
    next_pcie_tlp_fifo_rx_wr_data_s <= pcie_tlp_rx_buffer_s_2(31 downto 0) &
                                       pcie_tlp_rx_buffer_s_2(63 downto 32);

    case current_pcie_tlp_rx_req_state is
        when PCIE_TLP_AWAIT_RX =>
        when PCIE_TLP_RX_WRITE_HEADER =>
            next_pcie_tlp_fifo_rx_wr_en_s <= '1';
            -- Setup the tlp_streamer header length based on the TLP
            -- format and length contained in the first QW read.
            if (pcie_tlp_rx_buffer_s_1(29) = '1') then
                pcie_tlp_hdr_len_v := 4;
            else
                pcie_tlp_hdr_len_v := 3;
            end if;
            if (pcie_tlp_rx_buffer_s_1(30) = '1') then
                -- This TLP has data attached to it
                if (pcie_tlp_rx_buffer_s_1(9 downto 0) = "0000000000") then
                    pcie_tlp_rx_packet_len_v := 2 + 4 + 1024;
                else
                    pcie_tlp_rx_packet_len_v := 2 + pcie_tlp_hdr_len_v + to_integer(unsigned(pcie_tlp_rx_buffer_s_1(9 downto 0)));
                    if (pcie_tlp_rx_packet_len_v mod 2 = 1) then
                        -- If it's an odd packet length overall, add one more DW to align
                        -- the TXd packet with a QW natural boundary.
                        pcie_tlp_rx_packet_len_v := pcie_tlp_rx_packet_len_v + 1;
                    end if;
                end if;
            else
                -- TLPs are always assumed to have a 4-byte header in the FPGA
                -- to easily align with natural QW/FIFO write boundaries.
                -- The host will ignore the additional bytes when it processes the TLP.
                pcie_tlp_rx_packet_len_v := 2 + 4;
            end if;
            -- The length is stored in network-order when going over the wire
            next_pcie_tlp_fifo_rx_wr_data_s <= "0000000000000010" & -- tsh_msg_type == 2
                                               std_logic_vector(to_unsigned(pcie_tlp_rx_packet_len_v, 16)) &
                                               "0000000000000000" & -- tsh_rsvd_2 == 0
                                               "0000000000000000"; -- tsh_seq_id
        when PCIE_TLP_RX_WRITE_TLP =>
            next_pcie_tlp_fifo_rx_wr_en_s <= pcie_tlp_rx_buffer_valid_s_2;
    end case;

end process pcie_tlp_rx_fsm_data_output_process;

pcie_tlp_rx_fsm_state_select_process: process(current_pcie_tlp_rx_req_state, pcie_tlp_rx_producer_i,
                                              pcie_tlp_rx_buffer_valid_s_2)
begin

    next_pcie_tlp_rx_req_state <= current_pcie_tlp_rx_req_state;

    case current_pcie_tlp_rx_req_state is
        when PCIE_TLP_AWAIT_RX =>
            if (pcie_tlp_rx_producer_i.tlp_axis_rx_tvalid = '1') then
                next_pcie_tlp_rx_req_state <= PCIE_TLP_RX_WRITE_HEADER;
            end if;
        when PCIE_TLP_RX_WRITE_HEADER =>
            next_pcie_tlp_rx_req_state <= PCIE_TLP_RX_WRITE_TLP;
        when PCIE_TLP_RX_WRITE_TLP =>
            if (pcie_tlp_rx_producer_i.tlp_axis_rx_tlast = '1' or
                (pcie_tlp_rx_producer_i.tlp_axis_rx_tvalid = '0' and pcie_tlp_rx_buffer_valid_s_2 = '0')) then
                next_pcie_tlp_rx_req_state <= PCIE_TLP_AWAIT_RX;
            end if;
    end case;

end process pcie_tlp_rx_fsm_state_select_process;


end architecture RTL;
