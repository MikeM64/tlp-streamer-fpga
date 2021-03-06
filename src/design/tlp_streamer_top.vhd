--
-- TLP Streamer - Top Module
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.tlp_streamer_records.all;

entity tlp_streamer is
    port (
        -- FT601 Pins
        ft601_clk_i     : in    std_logic;
        ft601_be_io     : inout std_logic_vector(3 downto 0);
        ft601_data_io   : inout std_logic_vector(31 downto 0);
        ft601_oe_n_o    : out   std_logic;
        ft601_rxf_n_i   : in    std_logic;
        ft601_rd_n_o    : out   std_logic;
        ft601_rst_n_o   : out   std_logic;
        ft601_txe_n_i   : in    std_logic;
        ft601_wr_n_o    : out   std_logic;
        ft601_siwu_n_o  : out   std_logic;
        -- PCIe Pins
        pcie_clk_p_i    : in    std_logic;
        pcie_clk_n_i    : in    std_logic;
        pcie_perst_n_i  : in    std_logic;
        pcie_wake_n_o   : out   std_logic;
        pcie_txp_o      : out   std_logic_vector(0 downto 0);
        pcie_txn_o      : out   std_logic_vector(0 downto 0);
        pcie_rxp_i      : in    std_logic_vector(0 downto 0);
        pcie_rxn_i      : in    std_logic_vector(0 downto 0);
        -- Others
        user_led_ld1    : out   std_logic;
        user_led_ld2    : out   std_logic;
        sys_clk         : in    std_logic);
end entity tlp_streamer;

architecture RTL of tlp_streamer is

component tlp_streamer_reset is
    port(
        sys_clk_i   : in std_logic;
        sys_reset_o : out std_logic);
end component tlp_streamer_reset;

component tlp_streamer_ft601 is
    port (
        sys_clk_i       : in    std_logic;
        sys_reset_i     : in    std_logic;
        ft601_clk_i     : in    std_logic;
        ft601_be_io     : inout std_logic_vector(3 downto 0);
        ft601_data_io   : inout std_logic_vector(31 downto 0);
        ft601_oe_n_o    : out   std_logic;
        ft601_rxf_n_i   : in    std_logic;
        ft601_rd_n_o    : out   std_logic;
        ft601_rst_n_o   : out   std_logic;
        ft601_txe_n_i   : in    std_logic;
        ft601_wr_n_o    : out   std_logic;
        ft601_siwu_n_o  : out   std_logic;
        ft601_rx_fifo_rd_en_i       : in std_logic;
        ft601_rx_fifo_rd_empty_o    : out std_logic;
        ft601_rx_fifo_rd_valid_o    : out std_logic;
        ft601_rx_fifo_rd_data_o     : out std_logic_vector(35 downto 0);
        ft601_tx_fifo_wr_en_i       : in std_logic;
        ft601_tx_fifo_wr_full_o     : out std_logic;
        ft601_tx_fifo_wr_data_i     : in std_logic_vector(35 downto 0));
end component tlp_streamer_ft601;

component tlp_streamer_rx_dispatch is
    generic(NUM_OUTPUT_QUEUES : integer);
    port(
         sys_clk_i          : in std_logic;
         sys_reset_i        : in std_logic;
         -- Input FIFO to dispatch
         fifo_rd_en_o       : out std_logic;
         fifo_rd_empty_i    : in std_logic;
         fifo_rd_valid_i    : in std_logic;
         fifo_rd_data_i     : in std_logic_vector(35 downto 0);
         -- Output FIFOs to dispatch to
         dispatch_o_arr     : out dispatch_producer_r_array(NUM_OUTPUT_QUEUES-1 downto 0);
         dispatch_i_arr     : in dispatch_consumer_r_array(NUM_OUTPUT_QUEUES-1 downto 0));
end component tlp_streamer_rx_dispatch;

component tlp_streamer_tx_arbiter is
    generic (NUM_INPUT_QUEUES : integer);
    port (
        sys_clk_i   : in std_logic;
        sys_reset_i : in std_logic;
        -- Input FIFOs to arbitrate
        arbiter_o_arr : out arbiter_producer_r_array(NUM_INPUT_QUEUES-1 downto 0);
        arbiter_i_arr : in arbiter_consumer_r_array(NUM_INPUT_QUEUES-1 downto 0);
        -- Output FIFO to feed
        arbiter_output_wr_en_o : out std_logic;
        arbiter_output_wr_full_i : in std_logic;
        arbiter_output_wr_data_o : out std_logic_vector(35 downto 0));
end component tlp_streamer_tx_arbiter;

component tlp_streamer_loopback is
    port(
        sys_clk_i   : in std_logic;
        sys_reset_i : in std_logic;
        -- Input from dispatch
        dispatch_i : in dispatch_producer_r;
        dispatch_o : out dispatch_consumer_r;
        -- Output to TX
        arbiter_i : in arbiter_producer_r;
        arbiter_o : out arbiter_consumer_r);
end component tlp_streamer_loopback;

component tlp_streamer_pcie is
    port(
        user_led_ld2 : out std_logic;
        sys_clk_i : in std_logic;
        sys_reset_i : in std_logic;
        pcie_clk_p_i  : in std_logic;
        pcie_clk_n_i  : in std_logic;
        pcie_perst_n_i : in std_logic;
        pcie_wake_n_o : out std_logic;
        pcie_txp_o    : out std_logic_vector(0 downto 0);
        pcie_txn_o    : out std_logic_vector(0 downto 0);
        pcie_rxp_i    : in std_logic_vector(0 downto 0);
        pcie_rxn_i    : in std_logic_vector(0 downto 0);
        pcie_usr_link_up_o : out std_logic;
        pcie_cfg_dispatch_i : in dispatch_producer_r;
        pcie_cfg_dispatch_o : out dispatch_consumer_r;
        pcie_cfg_arbiter_i : in arbiter_producer_r;
        pcie_cfg_arbiter_o : out arbiter_consumer_r;
        pcie_tlp_dispatch_i : in dispatch_producer_r;
        pcie_tlp_dispatch_o : out dispatch_consumer_r;
        pcie_tlp_arbiter_i : in arbiter_producer_r;
        pcie_tlp_arbiter_o : out arbiter_consumer_r);
end component tlp_streamer_pcie;

-- Signals for FT601 RX/TX
signal ft601_rx_fifo_data_s, ft601_wr_data_s: std_logic_vector(35 downto 0);
signal ft601_rx_fifo_rd_en_s, ft601_rx_fifo_rd_empty_s, ft601_rx_fifo_rd_valid_s: std_logic;
signal ft601_tx_wr_en_s, ft601_wr_full_s : std_logic;

-- Signals for system reset
signal tlp_streamer_reset_s: std_logic;

-- Signals for RX dispatch queues
signal loopback_queue_out: dispatch_producer_r;
signal loopback_queue_in: dispatch_consumer_r;
signal pcie_cfg_rx_dispatch_out: dispatch_producer_r;
signal pcie_cfg_rx_dispatch_in: dispatch_consumer_r;
signal pcie_tlp_rx_dispatch_out: dispatch_producer_r;
signal pcie_tlp_rx_dispatch_in: dispatch_consumer_r;

-- Signals for TX arbitration
signal loopback_tx_out: arbiter_producer_r;
signal loopback_tx_in: arbiter_consumer_r;
signal pcie_cfg_tx_arbiter_out: arbiter_producer_r;
signal pcie_cfg_tx_arbiter_in: arbiter_consumer_r;
signal pcie_tlp_tx_arbiter_out: arbiter_producer_r;
signal pcie_tlp_tx_arbiter_in: arbiter_consumer_r;

begin

comp_tlp_streamer_reset: tlp_streamer_reset
    port map(
        sys_clk_i => sys_clk,
        sys_reset_o => tlp_streamer_reset_s);

comp_tlp_streamer_ft601: tlp_streamer_ft601
    port map (
        sys_clk_i => sys_clk,
        sys_reset_i => tlp_streamer_reset_s,
        ft601_clk_i => ft601_clk_i,
        ft601_be_io => ft601_be_io,
        ft601_data_io => ft601_data_io,
        ft601_oe_n_o => ft601_oe_n_o,
        ft601_rxf_n_i => ft601_rxf_n_i,
        ft601_rd_n_o => ft601_rd_n_o,
        ft601_rst_n_o => ft601_rst_n_o,
        ft601_txe_n_i => ft601_txe_n_i,
        ft601_wr_n_o => ft601_wr_n_o,
        ft601_siwu_n_o => ft601_siwu_n_o,
        ft601_rx_fifo_rd_en_i => ft601_rx_fifo_rd_en_s,
        ft601_rx_fifo_rd_empty_o => ft601_rx_fifo_rd_empty_s,
        ft601_rx_fifo_rd_valid_o => ft601_rx_fifo_rd_valid_s,
        ft601_rx_fifo_rd_data_o => ft601_rx_fifo_data_s,
        ft601_tx_fifo_wr_en_i => ft601_tx_wr_en_s,
        ft601_tx_fifo_wr_full_o => ft601_wr_full_s,
        ft601_tx_fifo_wr_data_i => ft601_wr_data_s);

comp_tlp_streamer_pcie: tlp_streamer_pcie
    port map (
        user_led_ld2 => user_led_ld2,
        sys_clk_i => sys_clk,
        sys_reset_i => tlp_streamer_reset_s,
        pcie_clk_p_i => pcie_clk_p_i,
        pcie_clk_n_i => pcie_clk_n_i,
        pcie_perst_n_i => pcie_perst_n_i,
        pcie_wake_n_o => pcie_wake_n_o,
        pcie_txp_o => pcie_txp_o,
        pcie_txn_o => pcie_txn_o,
        pcie_rxp_i => pcie_rxp_i,
        pcie_rxn_i => pcie_rxn_i,
        pcie_usr_link_up_o => open,
        -- Conguration management port
        pcie_cfg_dispatch_i => pcie_cfg_rx_dispatch_out,
        pcie_cfg_dispatch_o => pcie_cfg_rx_dispatch_in,
        pcie_cfg_arbiter_i => pcie_cfg_tx_arbiter_out,
        pcie_cfg_arbiter_o => pcie_cfg_tx_arbiter_in,
        -- TLP Packet handling
        pcie_tlp_dispatch_i => pcie_tlp_rx_dispatch_out,
        pcie_tlp_dispatch_o => pcie_tlp_rx_dispatch_in,
        pcie_tlp_arbiter_i => pcie_tlp_tx_arbiter_out,
        pcie_tlp_arbiter_o => pcie_tlp_tx_arbiter_in);

comp_tlp_streamer_rx_dispatch: tlp_streamer_rx_dispatch
    generic map (NUM_OUTPUT_QUEUES => 3)
    port map(
         sys_clk_i => sys_clk,
         sys_reset_i => tlp_streamer_reset_s,
         -- Input FIFO to dispatch
         fifo_rd_en_o => ft601_rx_fifo_rd_en_s,
         fifo_rd_empty_i => ft601_rx_fifo_rd_empty_s,
         fifo_rd_valid_i => ft601_rx_fifo_rd_valid_s,
         fifo_rd_data_i => ft601_rx_fifo_data_s,
         -- Output Components
         -- These MUST correspond to tsh_msg_type_et.
         dispatch_o_arr(0) => loopback_queue_out,
         dispatch_o_arr(1) => pcie_cfg_rx_dispatch_out,
         dispatch_o_arr(2) => pcie_tlp_rx_dispatch_out,
         dispatch_i_arr(0) => loopback_queue_in,
         dispatch_i_arr(1) => pcie_cfg_rx_dispatch_in,
         dispatch_i_arr(2) => pcie_tlp_rx_dispatch_in);

comp_tlp_streamer_tx_arbiter: tlp_streamer_tx_arbiter
    generic map (NUM_INPUT_QUEUES => 3)
    port map (
        sys_clk_i => sys_clk,
        sys_reset_i => tlp_streamer_reset_s,
        -- Input FIFOs to arbitrate
        arbiter_o_arr(0) => loopback_tx_out,
        arbiter_o_arr(1) => pcie_cfg_tx_arbiter_out,
        arbiter_o_arr(2) => pcie_tlp_tx_arbiter_out,
        arbiter_i_arr(0) => loopback_tx_in,
        arbiter_i_arr(1) => pcie_cfg_tx_arbiter_in,
        arbiter_i_arr(2) => pcie_tlp_tx_arbiter_in,
        -- Output FIFO to feed
        arbiter_output_wr_en_o => ft601_tx_wr_en_s,
        arbiter_output_wr_full_i => ft601_wr_full_s,
        arbiter_output_wr_data_o => ft601_wr_data_s);

comp_tlp_streamer_loopback: tlp_streamer_loopback
    port map(
        sys_clk_i => sys_clk,
        sys_reset_i => tlp_streamer_reset_s,
        -- Input from dispatch
        dispatch_i => loopback_queue_out,
        dispatch_o => loopback_queue_in,
        -- Output to TX
        arbiter_i => loopback_tx_out,
        arbiter_o => loopback_tx_in);

user_led_ld1 <= tlp_streamer_reset_s;

end architecture RTL;
