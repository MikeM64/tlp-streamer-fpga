--
-- TLP Streamer - USB RX Simulation
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tlp_usb_rx_sim is end tlp_usb_rx_sim;

architecture test of tlp_usb_rx_sim is
    component tlp_streamer
        port(
            ft601_clk_i     : in    std_logic;
            ft601_be_io     : inout std_logic_vector(3 downto 0);
            ft601_data_io   : inout std_logic_vector(31 downto 0);
            ft601_oe_n_o    : out   std_logic;
            ft601_rxf_n_i   : in    std_logic;
            ft601_rd_n_o    : out   std_logic;
            ft601_rst_n_o   : out   std_logic;
            usr_rst_n_i     : in    std_logic);
    end component;

signal test_ft601_clk: std_logic := '0';
signal test_ft601_be: std_logic_vector(3 downto 0) := "0000";
signal test_ft601_data: std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

signal test_ft601_bus_wr_s: std_logic := '1';
signal test_ft601_be_rd_i: std_logic_vector(3 downto 0);
signal test_ft601_data_rd_i: std_logic_vector(31 downto 0);
signal test_ft601_be_wr_o: std_logic_vector(3 downto 0);
signal test_ft601_data_wr_o: std_logic_vector(31 downto 0);

signal test_ft601_oe_n: std_logic := '1';
signal test_ft601_rxf_n: std_logic := '1';
signal test_ft601_rd_n: std_logic := '1';
signal test_ft601_rst_n: std_logic := '1';
signal test_usr_rst_n: std_logic := '1';

begin

UUT: tlp_streamer
    port map(
        ft601_clk_i => test_ft601_clk,
        ft601_be_io => test_ft601_be,
        ft601_data_io => test_ft601_data,
        ft601_oe_n_o => test_ft601_oe_n,
        ft601_rxf_n_i => test_ft601_rxf_n,
        ft601_rd_n_o => test_ft601_rd_n,
        ft601_rst_n_o => test_ft601_rst_n,
        usr_rst_n_i => test_usr_rst_n);

test_ft601_clk <= not test_ft601_clk after 5ns;

bus_write: process(test_ft601_clk) begin

if (test_ft601_clk'EVENT and test_ft601_clk = '0') then
    if (test_ft601_bus_wr_s = '1') then
        test_ft601_be <= test_ft601_be_wr_o;
        test_ft601_data <= test_ft601_data_wr_o;
    else
        test_ft601_be <= "ZZZZ";
        test_ft601_data <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
    end if;

    test_ft601_be_rd_i <= test_ft601_be;
    test_ft601_data_rd_i <= test_ft601_data;
end if;

end process bus_write;

tb: process begin

test_usr_rst_n <= '0';
wait for 100ns;

test_usr_rst_n <= '1';
wait for 100ns;

report "FPGA reset complete";

-- Refer to pg. 17 of the FT601 datasheet for the
-- controller read timing diagram. This is what is
-- being verified here.
test_ft601_rxf_n <= '0';

wait for 20ns;
test_ft601_bus_wr_s <= '1';
test_ft601_be_wr_o <= "1111";
test_ft601_data_wr_o <= "11111111111111111111111111111111";

wait for 10ns;
test_ft601_bus_wr_s <= '1';
test_ft601_be_wr_o <= "1111";
test_ft601_data_wr_o <= "00000000000000000000000000000000";

wait for 10ns;
test_ft601_bus_wr_s <= '1';
test_ft601_be_wr_o <= "1111";
test_ft601_data_wr_o <= "01010101010101010101010101010101";

wait for 10ns;
test_ft601_bus_wr_s <= '1';
test_ft601_be_wr_o <= "1111";
test_ft601_data_wr_o <= "10101010101010101010101010101010";

wait for 10ns;
assert test_ft601_oe_n = '0' report "The core has not asserted OE_N, 3 cycles after RXF_N" severity failure;
test_ft601_bus_wr_s <= '1';
test_ft601_be_wr_o <= "0000";
test_ft601_data_wr_o <= "00000000000000000000000000000000";

wait for 10ns;
assert test_ft601_rd_n = '0' report "The core has not asserted RD_N, 1 cycle after OE_N" severity failure;
test_ft601_rxf_n <= '1';
wait for 30ns;
assert test_ft601_oe_n = '1' report "The core has not de-asserted OE_N, 1 cycle after RXF_N" severity failure;
assert test_ft601_rd_n = '1' report "The core has not de-asserted RD_N, 1 cycle after RXF_N" severity failure;
report "Simulation complete!";

end process tb;

end architecture;