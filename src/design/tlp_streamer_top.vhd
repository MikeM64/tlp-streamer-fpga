--
-- TLP Streamer - Top Module
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

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

component tlp_streamer_pcie is
    port(
        user_led_ld2 : out std_logic;
        sys_reset_i : in std_logic;
        pcie_clk_p_i  : in std_logic;
        pcie_clk_n_i  : in std_logic;
        pcie_perst_n_i : in std_logic;
        pcie_wake_n_o : out std_logic;
        pcie_txp_o    : out std_logic_vector(0 downto 0);
        pcie_txn_o    : out std_logic_vector(0 downto 0);
        pcie_rxp_i    : in std_logic_vector(0 downto 0);
        pcie_rxn_i    : in std_logic_vector(0 downto 0);
        pcie_usr_link_up_o : out std_logic);
end component tlp_streamer_pcie;

-- Signals related to USB loopback
signal fifo_rx_tx_loopback_data_s: std_logic_vector(35 downto 0);
signal fifo_loopback_rd_wr_en_s: std_logic;
signal fifo_loopback_rd_en_s, fifo_loopback_rd_empty_s, ft601_usb_loopback_rd_valid_s: std_logic;
signal ft601_loopback_tx_wr_en_s, ft601_loopback_tx_wr_full_s: std_logic;

-- Signals for system reset
signal reset_hold_count64_s: unsigned(63 downto 0) := (others => '0');
signal tlp_streamer_reset_s: std_logic;

begin

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
        ft601_rx_fifo_rd_en_i => fifo_loopback_rd_en_s,
        ft601_rx_fifo_rd_empty_o => fifo_loopback_rd_empty_s,
        ft601_rx_fifo_rd_valid_o => ft601_usb_loopback_rd_valid_s,
        ft601_rx_fifo_rd_data_o => fifo_rx_tx_loopback_data_s,
        ft601_tx_fifo_wr_en_i => ft601_loopback_tx_wr_en_s,
        ft601_tx_fifo_wr_full_o => ft601_loopback_tx_wr_full_s,
        ft601_tx_fifo_wr_data_i => fifo_rx_tx_loopback_data_s);

comp_tlp_streamer_pcie: tlp_streamer_pcie
    port map (
        user_led_ld2 => user_led_ld2,
        sys_reset_i => tlp_streamer_reset_s,
        pcie_clk_p_i => pcie_clk_p_i,
        pcie_clk_n_i => pcie_clk_n_i,
        pcie_perst_n_i => pcie_perst_n_i,
        pcie_wake_n_o => pcie_wake_n_o,
        pcie_txp_o => pcie_txp_o,
        pcie_txn_o => pcie_txn_o,
        pcie_rxp_i => pcie_rxp_i,
        pcie_rxn_i => pcie_rxn_i,
        pcie_usr_link_up_o => open);

reset_process: process(sys_clk, reset_hold_count64_s, tlp_streamer_reset_s)
begin
    user_led_ld1 <= not tlp_streamer_reset_s;

    -- Self-generate a 500ns reset pulse
    if (reset_hold_count64_s < to_unsigned(50, 64)) then
        tlp_streamer_reset_s <= '1';
    else
        tlp_streamer_reset_s <= '0';
    end if;

    if (rising_edge(sys_clk)) then
        reset_hold_count64_s <= reset_hold_count64_s + 1;
    end if;

end process reset_process;

fifo_loopback_ctrl: process(fifo_loopback_rd_empty_s, ft601_loopback_tx_wr_full_s,
                            ft601_usb_loopback_rd_valid_s)
begin

    fifo_loopback_rd_wr_en_s <= '0';

    if (ft601_loopback_tx_wr_full_s = '0') then
        if (fifo_loopback_rd_empty_s = '0' or ft601_usb_loopback_rd_valid_s = '1') then
            fifo_loopback_rd_wr_en_s <= '1';
        end if;
    end if;

end process fifo_loopback_ctrl;


sys_clk_process: process(sys_clk, tlp_streamer_reset_s, fifo_loopback_rd_wr_en_s,
                         ft601_usb_loopback_rd_valid_s)
begin

    -- Only write data to the TX FIFO if the output data from the
    -- RX FIFO is valid
    ft601_loopback_tx_wr_en_s <= fifo_loopback_rd_wr_en_s and ft601_usb_loopback_rd_valid_s;

    if (tlp_streamer_reset_s = '1') then
        fifo_loopback_rd_en_s <= '0';
        ft601_loopback_tx_wr_en_s <= '0';
    elsif (rising_edge(sys_clk)) then
        -- An additional buffer is needed for the FIFO wr_en signal
        -- so that it is in sync with the data. Without the extra register
        -- the wr_en signal would be asserted before the data was ready.
        fifo_loopback_rd_en_s <= fifo_loopback_rd_wr_en_s;
    end if;

end process sys_clk_process;

end architecture RTL;
