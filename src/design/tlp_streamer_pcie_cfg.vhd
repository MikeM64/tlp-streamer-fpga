--
-- TLP Streamer - PCIe Configuration Space Request Management
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.tlp_streamer_records.all;

entity tlp_streamer_pcie_cfg is
    port (
        sys_clk_i   : in std_logic;
        pcie_clk_i  : in std_logic;
        sys_reset_i : in std_logic;
        -- PCIe Configuration Port from PCIe IP
        pcie_cfg_mgmt_producer_i : in pcie_cfg_mgmt_port_producer_r;
        pcie_cfg_mgmt_consumer_o : out pcie_cfg_mgmt_port_consumer_r;
        -- Input Requests from the host to handle
        dispatch_i : in dispatch_producer_r;
        dispatch_o : out dispatch_consumer_r;
        -- Output Packets towards the host
        arbiter_i : in arbiter_producer_r;
        arbiter_o : out arbiter_consumer_r);
end entity tlp_streamer_pcie_cfg;

architecture RTL of tlp_streamer_pcie_cfg is

component fifo_32_32_bram IS
    port (
        rst : IN STD_LOGIC;
        wr_clk : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC;
        valid : OUT STD_LOGIC;
        wr_rst_busy : OUT STD_LOGIC;
        rd_rst_busy : OUT STD_LOGIC
    );
end component fifo_32_32_bram;

type pcie_cfg_req_state is (PCIE_CFG_IDLE, PCIE_CFG_AWAIT_HEADER, PCIE_CFG_PARSE_HEADER_1,
                            PCIE_CFG_PARSE_HEADER_2, PCIE_CFG_PARSE_CMD_1, PCIE_CFG_PARSE_CMD_2,
                            PCIE_CFG_READ_1, PCIE_CFG_READ_2, PCIE_CFG_WRITE_1, PCIE_CFG_WRITE_2,
                            PCIE_CFG_TX_PACKET_1, PCIE_CFG_TX_PACKET_2, PCIE_CFG_TX_PACKET_3,
                            PCIE_CFG_TX_PACKET_4, PCIE_CFG_COMPLETE);

signal current_pcie_cfg_req_state, next_pcie_cfg_req_state: pcie_cfg_req_state;

-- RX/TX FIFO Signals
signal pcie_cfg_fifo_rx_wr_en_s: std_logic;
signal pcie_cfg_fifo_rx_rd_en_s, pcie_cfg_fifo_rx_rd_empty_s, pcie_cfg_fifo_rx_rd_valid_s: std_logic;
signal pcie_cfg_fifo_rx_rd_data_s: std_logic_vector(31 downto 0);

signal pcie_cfg_fifo_tx_wr_en_s, next_pcie_cfg_fifo_tx_wr_en_s, pcie_cfg_fifo_tx_wr_full_s: std_logic;
signal pcie_cfg_fifo_tx_wr_data_s, next_pcie_cfg_fifo_tx_wr_data_s, pcie_cfg_fifo_tx_rd_data_s: std_logic_vector(31 downto 0);

-- Current packet signals
signal pcie_cfg_req_seq_id_s, next_pcie_cfg_req_seq_id_s: std_logic_vector(15 downto 0);
signal pcie_cfg_cmd_write_be_s, next_pcie_cfg_cmd_write_be_s: std_logic_vector(3 downto 0);
signal pcie_cfg_cmd_write_s, next_pcie_cfg_cmd_write_s: std_logic;
signal pcie_cfg_cmd_write_readonly_s, next_pcie_cfg_cmd_write_readonly_s: std_logic;
signal pcie_cfg_cmd_write_rw1c_as_rw_s, next_pcie_cfg_cmd_write_rw1c_as_rw_s: std_logic;
signal pcie_cfg_cmd_addr_s, next_pcie_cfg_cmd_addr_s: std_logic_vector(9 downto 0);
signal pcie_cfg_cmd_data_s, next_pcie_cfg_cmd_data_s: std_logic_vector(31 downto 0);

begin

comp_pcie_cfg_rx_fifo: fifo_32_32_bram
    port map (
        rst => sys_reset_i,
        wr_clk => sys_clk_i,
        rd_clk => pcie_clk_i,
        din => dispatch_i.dispatch_wr_data(31 downto 0),
        wr_en => pcie_cfg_fifo_rx_wr_en_s,
        rd_en => pcie_cfg_fifo_rx_rd_en_s,
        dout => pcie_cfg_fifo_rx_rd_data_s,
        full => dispatch_o.dispatch_wr_full,
        empty => pcie_cfg_fifo_rx_rd_empty_s,
        valid => pcie_cfg_fifo_rx_rd_valid_s,
        wr_rst_busy => open,
        rd_rst_busy => open);

comp_pcie_cfg_tx_fifo: fifo_32_32_bram
    port map (
        rst => sys_reset_i,
        wr_clk => pcie_clk_i,
        rd_clk => sys_clk_i,
        din => pcie_cfg_fifo_tx_wr_data_s,
        wr_en => pcie_cfg_fifo_tx_wr_en_s,
        rd_en => arbiter_i.arbiter_rd_en,
        dout => pcie_cfg_fifo_tx_rd_data_s,
        full => pcie_cfg_fifo_tx_wr_full_s,
        empty => arbiter_o.arbiter_rd_empty,
        valid => arbiter_o.arbiter_rd_valid,
        wr_rst_busy => open,
        rd_rst_busy => open);

pcie_cfg_rx_tx_async_process: process(dispatch_i, pcie_cfg_fifo_tx_rd_data_s)
begin

    pcie_cfg_fifo_rx_wr_en_s <= dispatch_i.dispatch_wr_en and
                                dispatch_i.dispatch_valid;
    -- The extra 1's here correspond to the byte_enable portion of the
    -- data sent to the FT601
    arbiter_o.arbiter_rd_data <= "1111" & pcie_cfg_fifo_tx_rd_data_s;

end process pcie_cfg_rx_tx_async_process;

pcie_cfg_fsm_state_process: process(pcie_clk_i, sys_reset_i, next_pcie_cfg_req_state, current_pcie_cfg_req_state,
                                    next_pcie_cfg_req_seq_id_s, next_pcie_cfg_cmd_write_be_s,
                                    next_pcie_cfg_cmd_write_s, next_pcie_cfg_cmd_addr_s,
                                    next_pcie_cfg_cmd_data_s, next_pcie_cfg_fifo_tx_wr_data_s,
                                    next_pcie_cfg_cmd_write_readonly_s, next_pcie_cfg_cmd_write_rw1c_as_rw_s)
begin

    if (sys_reset_i = '1') then
        current_pcie_cfg_req_state <= PCIE_CFG_IDLE;
        pcie_cfg_req_seq_id_s <= (others => '0');
        pcie_cfg_cmd_write_be_s <= (others => '0');
        pcie_cfg_cmd_write_s <= '0';
        pcie_cfg_cmd_addr_s <= (others => '0');
        pcie_cfg_cmd_data_s <= (others => '0');
        pcie_cfg_fifo_tx_wr_data_s <= (others => '0');
        pcie_cfg_fifo_tx_wr_en_s <= '0';
    elsif (rising_edge(pcie_clk_i)) then
        current_pcie_cfg_req_state <= next_pcie_cfg_req_state;

        pcie_cfg_req_seq_id_s <= next_pcie_cfg_req_seq_id_s;
        pcie_cfg_cmd_write_be_s <= next_pcie_cfg_cmd_write_be_s;
        pcie_cfg_cmd_write_s <= next_pcie_cfg_cmd_write_s;
        pcie_cfg_cmd_write_readonly_s <= next_pcie_cfg_cmd_write_readonly_s;
        pcie_cfg_cmd_write_rw1c_as_rw_s <= next_pcie_cfg_cmd_write_rw1c_as_rw_s;
        pcie_cfg_cmd_addr_s <= next_pcie_cfg_cmd_addr_s;
        pcie_cfg_cmd_data_s <= next_pcie_cfg_cmd_data_s;

        pcie_cfg_fifo_tx_wr_data_s <= next_pcie_cfg_fifo_tx_wr_data_s;
        pcie_cfg_fifo_tx_wr_en_s <= next_pcie_cfg_fifo_tx_wr_en_s;
    end if;

end process pcie_cfg_fsm_state_process;

pcie_cfg_fsm_data_output_process: process(current_pcie_cfg_req_state, pcie_cfg_req_seq_id_s,
                                          pcie_cfg_cmd_write_be_s, pcie_cfg_cmd_write_s,
                                          pcie_cfg_cmd_addr_s, pcie_cfg_cmd_data_s,
                                          pcie_cfg_fifo_rx_rd_data_s, pcie_cfg_mgmt_producer_i,
                                          pcie_cfg_fifo_tx_wr_data_s, pcie_cfg_cmd_write_readonly_s,
                                          pcie_cfg_cmd_write_rw1c_as_rw_s)
begin

    pcie_cfg_fifo_rx_rd_en_s <= '0';
    next_pcie_cfg_fifo_tx_wr_en_s <= '0';

    next_pcie_cfg_req_seq_id_s <= pcie_cfg_req_seq_id_s;
    next_pcie_cfg_cmd_write_be_s <= pcie_cfg_cmd_write_be_s;
    next_pcie_cfg_cmd_write_s <= pcie_cfg_cmd_write_s;
    next_pcie_cfg_cmd_write_readonly_s <= pcie_cfg_cmd_write_readonly_s;
    next_pcie_cfg_cmd_write_rw1c_as_rw_s <= pcie_cfg_cmd_write_rw1c_as_rw_s;
    next_pcie_cfg_cmd_addr_s <= pcie_cfg_cmd_addr_s;
    next_pcie_cfg_cmd_data_s <= pcie_cfg_cmd_data_s;
    next_pcie_cfg_fifo_tx_wr_data_s <= pcie_cfg_fifo_tx_wr_data_s;

    pcie_cfg_mgmt_consumer_o.cfg_mgmt_di <= (others => '0');
    pcie_cfg_mgmt_consumer_o.cfg_mgmt_byte_en <= (others => '0');
    pcie_cfg_mgmt_consumer_o.cfg_mgmt_dwaddr <= (others => '0');
    pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_en <= '0';
    pcie_cfg_mgmt_consumer_o.cfg_mgmt_rd_en <= '0';
    pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_readonly <= '0';
    pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_rw1c_as_rw <= '0';

    case current_pcie_cfg_req_state is
        when PCIE_CFG_IDLE =>
        when PCIE_CFG_AWAIT_HEADER =>
            pcie_cfg_fifo_rx_rd_en_s <= '1';
        when PCIE_CFG_PARSE_HEADER_1 =>
            -- First valid header word will be here
            -- tsh_msg_type and tsh_msg_len are not used by this component and ignored.
            pcie_cfg_fifo_rx_rd_en_s <= '1';
        when PCIE_CFG_PARSE_HEADER_2 =>
            next_pcie_cfg_req_seq_id_s <= pcie_cfg_fifo_rx_rd_data_s(15 downto 0) ;
            pcie_cfg_fifo_rx_rd_en_s <= '1';
        when PCIE_CFG_PARSE_CMD_1 =>
            -- struct tlp_streamer_pcie_cfg_cmd is always fully
            -- parsed to simplify the decoding pipeline
            pcie_cfg_fifo_rx_rd_en_s <= '1';
            next_pcie_cfg_cmd_addr_s <= pcie_cfg_fifo_rx_rd_data_s(9 downto 0);
            next_pcie_cfg_cmd_write_s <= pcie_cfg_fifo_rx_rd_data_s(16);
            next_pcie_cfg_cmd_write_readonly_s <= pcie_cfg_fifo_rx_rd_data_s(17);
            next_pcie_cfg_cmd_write_rw1c_as_rw_s <= pcie_cfg_fifo_rx_rd_data_s(18);
            next_pcie_cfg_cmd_write_be_s <= pcie_cfg_fifo_rx_rd_data_s(27 downto 24);
        when PCIE_CFG_PARSE_CMD_2 =>
            next_pcie_cfg_cmd_data_s <= pcie_cfg_fifo_rx_rd_data_s;
        when PCIE_CFG_READ_1 =>
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_rd_en <= '1';
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_dwaddr <= pcie_cfg_cmd_addr_s;
        when PCIE_CFG_READ_2 =>
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_rd_en <= '1';
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_dwaddr <= pcie_cfg_cmd_addr_s;
            next_pcie_cfg_cmd_data_s <= pcie_cfg_mgmt_producer_i.cfg_mgmt_do;
        when PCIE_CFG_WRITE_1 =>
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_en <= '1';
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_readonly <= pcie_cfg_cmd_write_readonly_s;
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_rw1c_as_rw <= pcie_cfg_cmd_write_rw1c_as_rw_s;
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_dwaddr <= pcie_cfg_cmd_addr_s;
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_di <= pcie_cfg_cmd_data_s;
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_byte_en <= pcie_cfg_cmd_write_be_s;
        when PCIE_CFG_WRITE_2 =>
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_en <= '1';
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_readonly <= pcie_cfg_cmd_write_readonly_s;
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_rw1c_as_rw <= pcie_cfg_cmd_write_rw1c_as_rw_s;
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_dwaddr <= pcie_cfg_cmd_addr_s;
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_di <= pcie_cfg_cmd_data_s;
            pcie_cfg_mgmt_consumer_o.cfg_mgmt_byte_en <= pcie_cfg_cmd_write_be_s;
        when PCIE_CFG_TX_PACKET_1 =>
            next_pcie_cfg_fifo_tx_wr_en_s <= '1';
            next_pcie_cfg_fifo_tx_wr_data_s <= "0000010000000000" & "00000000" & "00000001";
        when PCIE_CFG_TX_PACKET_2 =>
            next_pcie_cfg_fifo_tx_wr_en_s <= '1';
            next_pcie_cfg_fifo_tx_wr_data_s <=  "0000000000000000" & pcie_cfg_req_seq_id_s;
        when PCIE_CFG_TX_PACKET_3 =>
            next_pcie_cfg_fifo_tx_wr_en_s <= '1';
            next_pcie_cfg_fifo_tx_wr_data_s <= "0000" & pcie_cfg_cmd_write_be_s & "00000" &
                                                pcie_cfg_cmd_write_rw1c_as_rw_s & pcie_cfg_cmd_write_readonly_s &
                                                pcie_cfg_cmd_write_s & "000000" & pcie_cfg_cmd_addr_s;
        when PCIE_CFG_TX_PACKET_4 =>
            next_pcie_cfg_fifo_tx_wr_en_s <= '1';
            next_pcie_cfg_fifo_tx_wr_data_s <= pcie_cfg_cmd_data_s;
        when PCIE_CFG_COMPLETE =>
            next_pcie_cfg_req_seq_id_s <= (others => '0');
            next_pcie_cfg_cmd_write_be_s <= (others => '0');
            next_pcie_cfg_cmd_write_s <= '0';
            next_pcie_cfg_cmd_write_readonly_s <= '0';
            next_pcie_cfg_cmd_write_rw1c_as_rw_s <= '0';
            next_pcie_cfg_cmd_addr_s <= (others => '0');
            next_pcie_cfg_cmd_data_s <= (others => '0');
    end case;

end process pcie_cfg_fsm_data_output_process;

pcie_cfg_fsm_state_select_process: process(current_pcie_cfg_req_state, pcie_cfg_fifo_rx_rd_empty_s,
                                           pcie_cfg_cmd_write_s, pcie_cfg_mgmt_producer_i)
begin

    next_pcie_cfg_req_state <= current_pcie_cfg_req_state;

    case current_pcie_cfg_req_state is
        when PCIE_CFG_IDLE =>
            if (pcie_cfg_fifo_rx_rd_empty_s = '0') then
                next_pcie_cfg_req_state <= PCIE_CFG_AWAIT_HEADER;
            end if;
        when PCIE_CFG_AWAIT_HEADER =>
                next_pcie_cfg_req_state <= PCIE_CFG_PARSE_HEADER_1;
        when PCIE_CFG_PARSE_HEADER_1 =>
            next_pcie_cfg_req_state <= PCIE_CFG_PARSE_HEADER_2;
        when PCIE_CFG_PARSE_HEADER_2 =>
            next_pcie_cfg_req_state <= PCIE_CFG_PARSE_CMD_1;
        when PCIE_CFG_PARSE_CMD_1 =>
            next_pcie_cfg_req_state <= PCIE_CFG_PARSE_CMD_2;
        when PCIE_CFG_PARSE_CMD_2 =>
            if (pcie_cfg_cmd_write_s = '0') then
                next_pcie_cfg_req_state <= PCIE_CFG_READ_1;
            else
                next_pcie_cfg_req_state <= PCIE_CFG_WRITE_1;
            end if;
        when PCIE_CFG_READ_1 =>
            next_pcie_cfg_req_state <= PCIE_CFG_READ_2;
        when PCIE_CFG_READ_2 =>
            if (pcie_cfg_mgmt_producer_i.cfg_mgmt_rd_wr_done = '1') then
                next_pcie_cfg_req_state <= PCIE_CFG_TX_PACKET_1;
            end if;
        when PCIE_CFG_WRITE_1 =>
            next_pcie_cfg_req_state <= PCIE_CFG_WRITE_2;
        when PCIE_CFG_WRITE_2 =>
            if (pcie_cfg_mgmt_producer_i.cfg_mgmt_rd_wr_done = '1') then
                next_pcie_cfg_req_state <= PCIE_CFG_TX_PACKET_1;
            end if;
        when PCIE_CFG_TX_PACKET_1 =>
            next_pcie_cfg_req_state <= PCIE_CFG_TX_PACKET_2;
        when PCIE_CFG_TX_PACKET_2 =>
            next_pcie_cfg_req_state <= PCIE_CFG_TX_PACKET_3;
        when PCIE_CFG_TX_PACKET_3 =>
            next_pcie_cfg_req_state <= PCIE_CFG_TX_PACKET_4;
        when PCIE_CFG_TX_PACKET_4 =>
            next_pcie_cfg_req_state <= PCIE_CFG_COMPLETE;
        when PCIE_CFG_COMPLETE =>
            next_pcie_cfg_req_state <= PCIE_CFG_IDLE;
    end case;

end process pcie_cfg_fsm_state_select_process;

end architecture RTL;