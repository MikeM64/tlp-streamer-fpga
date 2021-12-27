--
-- TLP Streamer Records - Record Package
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;

package tlp_streamer_records is

--
-- Signals produced by the dispatch queue
--
type dispatch_producer_r is record
    dispatch_wr_en : std_logic;
    dispatch_valid : std_logic;
    dispatch_empty : std_logic;
    dispatch_wr_data : std_logic_vector(35 downto 0);
end record dispatch_producer_r;

--
-- Signals consumed by the dispatch queue
--
type dispatch_consumer_r is record
    dispatch_wr_full : std_logic;
end record dispatch_consumer_r;

-- Array versions of the above records
type dispatch_producer_r_array is array (integer range <>) of dispatch_producer_r;
type dispatch_consumer_r_array is array (integer range <>) of dispatch_consumer_r;

end package tlp_streamer_records;
