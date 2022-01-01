--
-- TLP Streamer - PCIe TLP Interface
--
-- (c) MikeM64 - 2022
--

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

type pcie_tlp_req_state is (PCIE_TLP_IDLE, PCIE_TLP_TX_PACKET_START, PCIE_TLP_TX_PACKET_PARSE_HEADER,
                            PCIE_TLP_TX_PACKET);

signal current_pcie_tlp_req_state, next_pcie_tlp_req_state: pcie_tlp_req_state;

signal pcie_tlp_fifo_rx_wr_en_s, next_pcie_tlp_fifo_rx_wr_en_s: std_logic;
signal pcie_tlp_fifo_rx_rd_en_s: std_logic;
signal pcie_tlp_fifo_rx_rd_data_s: std_logic_vector(63 downto 0);
signal pcie_tlp_fifo_rx_rd_empty_s: std_logic;
signal pcie_tlp_fifo_rx_rd_valid_s: std_logic;

-- This is the number of qwords to read from the RX FIFO when transmitting
-- packets towards the PCIe core
signal pcie_tlp_rx_qwords_to_read, next_pcie_tlp_rx_qwords_to_read: integer range 0 to 2061;

signal pcie_tlp_fifo_tx_wr_data_s, next_pcie_tlp_fifo_tx_wr_data_s: std_logic_vector(63 downto 0);
signal pcie_tlp_fifo_tx_wr_en_s, next_pcie_tlp_fifo_tx_wr_en_s: std_logic;
signal pcie_tlp_fifo_tx_rd_data_s: std_logic_vector(31 downto 0);
signal pcie_tlp_fifo_tx_rd_en_s, next_pcie_tlp_fifo_tx_rd_en_s: std_logic;
signal pcie_tlp_fifo_tx_wr_full_s: std_logic;

begin

comp_pcie_tlp_rx_fifo: fifo_pcie_tlp_r64_w32_4096_bram
    port map(
        rst => pcie_rst_i,
        wr_clk => sys_clk_i,
        rd_clk => pcie_clk_i,
        din => dispatch_i.dispatch_wr_data(31 downto 0),
        wr_en => pcie_tlp_fifo_rx_wr_en_s,
        rd_en => pcie_tlp_fifo_rx_rd_en_s,
        dout => pcie_tlp_fifo_rx_rd_data_s,
        full => dispatch_o.dispatch_wr_full,
        empty => pcie_tlp_fifo_rx_rd_empty_s,
        valid => pcie_tlp_fifo_rx_rd_valid_s,
        wr_rst_busy => open,
        rd_rst_busy => open);

comp_pcie_tlp_tx_fifo: fifo_pcie_tlp_r32_w64_4096_bram
    port map(
        rst => pcie_rst_i,
        wr_clk => pcie_clk_i,
        rd_clk => sys_clk_i,
        din => pcie_tlp_fifo_tx_wr_data_s,
        wr_en => pcie_tlp_fifo_tx_wr_en_s,
        rd_en => arbiter_i.arbiter_rd_en,
        dout => pcie_tlp_fifo_tx_rd_data_s,
        full => pcie_tlp_fifo_tx_wr_full_s,
        empty => arbiter_o.arbiter_rd_empty,
        valid => arbiter_o.arbiter_rd_valid,
        wr_rst_busy => open,
        rd_rst_busy => open);

pcie_tlp_rx_tx_async_process: process(dispatch_i, pcie_tlp_fifo_tx_rd_data_s)
begin

    pcie_tlp_fifo_rx_wr_en_s <= dispatch_i.dispatch_wr_en and
                                dispatch_i.dispatch_valid;
    -- The extra 1's here correspond to the byte_enable portion of the
    -- data sent to the FT601
    arbiter_o.arbiter_rd_data <= "1111" & pcie_tlp_fifo_tx_rd_data_s;

end process pcie_tlp_rx_tx_async_process;

pcie_tlp_fsm_state_process: process(pcie_clk_i, pcie_rst_i, next_pcie_tlp_fifo_tx_wr_data_s,
                                    next_pcie_tlp_fifo_tx_wr_en_s, next_pcie_tlp_req_state,
                                    next_pcie_tlp_rx_qwords_to_read)
begin

    if (pcie_rst_i = '1') then
        current_pcie_tlp_req_state <= PCIE_TLP_IDLE;
        pcie_tlp_fifo_tx_wr_data_s <= (others => '0');
        pcie_tlp_fifo_tx_wr_en_s <= '0';
        pcie_tlp_rx_qwords_to_read <= 0;
    elsif (rising_edge(pcie_clk_i)) then
        current_pcie_tlp_req_state <= next_pcie_tlp_req_state;
        pcie_tlp_fifo_tx_wr_data_s <= next_pcie_tlp_fifo_tx_wr_data_s;
        pcie_tlp_fifo_tx_wr_en_s <= next_pcie_tlp_fifo_tx_wr_en_s;
        pcie_tlp_rx_qwords_to_read <= next_pcie_tlp_rx_qwords_to_read;
    end if;

end process pcie_tlp_fsm_state_process;

pcie_tlp_fsm_data_output_process: process(current_pcie_tlp_req_state,
                                          pcie_tlp_rx_qwords_to_read, pcie_tlp_fifo_rx_rd_data_s,
                                          pcie_tlp_fifo_rx_rd_valid_s)
begin

    pcie_tlp_fifo_rx_rd_en_s <= '0';
    next_pcie_tlp_rx_qwords_to_read <= pcie_tlp_rx_qwords_to_read;
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tdata <= (others => '0');
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tuser <= (others => '0');
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tkeep <= (others => '0');
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tlast <= '0';
    pcie_tlp_tx_consumer_o.tlp_axis_tx_tvalid <= '0';

    case current_pcie_tlp_req_state is
        when PCIE_TLP_IDLE =>
            next_pcie_tlp_rx_qwords_to_read <= 0;
        when PCIE_TLP_TX_PACKET_START =>
            pcie_tlp_fifo_rx_rd_en_s <= '1';
            next_pcie_tlp_rx_qwords_to_read <= 0;
        when PCIE_TLP_TX_PACKET_PARSE_HEADER =>
            -- The first double-word out of the FIFO is the tlp_streamer header.
            -- Use the length to know when to stop transmitting towards the
            -- PCIe core
            next_pcie_tlp_rx_qwords_to_read <= to_integer(unsigned(pcie_tlp_fifo_rx_rd_data_s(63 downto 48))) / 2;
            pcie_tlp_fifo_rx_rd_en_s <= '1';
        when PCIE_TLP_TX_PACKET =>
            pcie_tlp_fifo_rx_rd_en_s <= '1';
            pcie_tlp_tx_consumer_o.tlp_axis_tx_tdata <= pcie_tlp_fifo_rx_rd_data_s;
            pcie_tlp_tx_consumer_o.tlp_axis_tx_tkeep <= (others => '1');
            if (pcie_tlp_rx_qwords_to_read = 0) then
                pcie_tlp_tx_consumer_o.tlp_axis_tx_tlast <= '1';
            end if;
            pcie_tlp_tx_consumer_o.tlp_axis_tx_tvalid <= pcie_tlp_fifo_rx_rd_valid_s;
            next_pcie_tlp_rx_qwords_to_read <= pcie_tlp_rx_qwords_to_read - 1;
    end case;

end process pcie_tlp_fsm_data_output_process;

pcie_tlp_fsm_state_select_process: process(current_pcie_tlp_req_state, pcie_tlp_fifo_rx_rd_empty_s,
                                           pcie_tlp_tx_producer_i)
begin

    next_pcie_tlp_req_state <= current_pcie_tlp_req_state;

    case current_pcie_tlp_req_state is
        when PCIE_TLP_IDLE =>
            if (pcie_tlp_fifo_rx_rd_empty_s = '0' and
                pcie_tlp_tx_producer_i.tlp_axis_tx_tready = '1') then
                next_pcie_tlp_req_state <= PCIE_TLP_TX_PACKET_START;
            end if;
        when PCIE_TLP_TX_PACKET_START =>
            next_pcie_tlp_req_state <= PCIE_TLP_TX_PACKET_PARSE_HEADER;
        when PCIE_TLP_TX_PACKET_PARSE_HEADER =>
            next_pcie_tlp_req_state <= PCIE_TLP_TX_PACKET;
        when PCIE_TLP_TX_PACKET =>
            -- TODO
            next_pcie_tlp_req_state <= PCIE_TLP_IDLE;
    end case;

end process pcie_tlp_fsm_state_select_process;

end architecture RTL;
