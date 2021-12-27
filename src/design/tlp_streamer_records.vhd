--
-- TLP Streamer Records - Record Package
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;

package tlp_streamer_records is

type rx_queue_output_out is record
    dispatch_output_wr_en : std_logic;
    dispatch_output_valid : std_logic;
    dispatch_output_empty : std_logic;
    dispatch_output_wr_data : std_logic_vector(35 downto 0);
end record rx_queue_output_out;

type rx_queue_out_in is record
    dispatch_output_wr_full : std_logic;
end record rx_queue_out_in;

type rx_dispatch_queue_out_array is array (integer range <>) of rx_queue_output_out;
type rx_dispatch_queue_in_array is array (integer range <>) of rx_queue_out_in;

end package tlp_streamer_records;
