--
-- TLP Streamer - Host Packet Loopback Module
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.tlp_streamer_records.all;

entity tlp_streamer_loopback is
    port(
        sys_clk_i   : in std_logic;
        sys_reset_i : in std_logic;
        -- Input from dispatch
        dispatch_i : in dispatch_producer_r;
        dispatch_o : out dispatch_consumer_r;
        -- Output to TX
        arbiter_i : in arbiter_producer_r;
        arbiter_o : out arbiter_consumer_r);
end entity tlp_streamer_loopback;

architecture RTL of tlp_streamer_loopback is

component fifo_36_36_prim IS
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(35 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    valid : OUT STD_LOGIC);
END component fifo_36_36_prim;

signal loopback_wr_en_s: std_logic;

begin

loopback_fifo: fifo_36_36_prim
    port map (
        rst => sys_reset_i,
        wr_clk => sys_clk_i,
        rd_clk => sys_clk_i,
        din => dispatch_i.dispatch_wr_data,
        wr_en => loopback_wr_en_s,
        rd_en => arbiter_i.arbiter_rd_en,
        dout => arbiter_o.arbiter_rd_data,
        full => dispatch_o.dispatch_wr_full,
        empty => arbiter_o.arbiter_rd_empty,
        valid => arbiter_o.arbiter_rd_valid);

loopback_wr_en_s <= dispatch_i.dispatch_wr_en and dispatch_i.dispatch_valid;

end architecture RTL;
