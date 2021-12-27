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
        dispatch_input : in rx_queue_output_out;
        dispatch_output : out rx_queue_out_in;
        -- Output to TX
        loop_wr_en_o : out std_logic;
        loop_wr_full_i : in std_logic;
        loop_wr_data_o : out std_logic_vector(35 downto 0));
end entity tlp_streamer_loopback;

architecture RTL of tlp_streamer_loopback is

begin

-- Only write data to the TX FIFO if the output data from the
-- RX FIFO is valid
dispatch_output.dispatch_output_wr_full <= loop_wr_full_i;
loop_wr_data_o <= dispatch_input.dispatch_output_wr_data;
loop_wr_en_o <= dispatch_input.dispatch_output_wr_en and
                dispatch_input.dispatch_output_valid;

end architecture RTL;
