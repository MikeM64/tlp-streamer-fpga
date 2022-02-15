--
-- TLP Streamer - Reset generator
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tlp_streamer_reset is
    port(
        sys_clk_i   : in std_logic;
        sys_reset_o : out std_logic);
end entity tlp_streamer_reset;

architecture RTL of tlp_streamer_reset is

signal reset_hold_count64_s: unsigned(63 downto 0) := (others => '0');
signal reset_s: std_logic;

begin

reset_process: process(sys_clk_i, reset_hold_count64_s, reset_s)
begin
    sys_reset_o <= reset_s;

    -- Self-generate a 1500ns reset pulse
    if (reset_hold_count64_s < to_unsigned(150, 64)) then
        reset_s <= '1';
    else
        reset_s <= '0';
    end if;

    if (rising_edge(sys_clk_i)) then
        reset_hold_count64_s <= reset_hold_count64_s + 1;
    end if;

end process reset_process;

end architecture RTL;
