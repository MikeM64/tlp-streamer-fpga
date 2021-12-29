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

--
-- Signals produced by the TX arbitrator
--
type arbiter_producer_r is record
    arbiter_rd_en : std_logic;
    arbiter_wr_full : std_logic;
end record arbiter_producer_r;

--
-- Signals consumed by the TX arbitrator
--
type arbiter_consumer_r is record
    arbiter_rd_data : std_logic_vector(35 downto 0);
    arbiter_rd_empty : std_logic;
    arbiter_rd_valid : std_logic;
end record arbiter_consumer_r;

type arbiter_producer_r_array is array (integer range <>) of arbiter_producer_r;
type arbiter_consumer_r_array is array (integer range <>) of arbiter_consumer_r;

type pcie_cfg_mgmt_port_producer_r is record
        cfg_mgmt_do : STD_LOGIC_VECTOR(31 DOWNTO 0);
        cfg_mgmt_rd_wr_done : STD_LOGIC;
end record pcie_cfg_mgmt_port_producer_r;

type pcie_cfg_mgmt_port_consumer_r is record
        cfg_mgmt_di : STD_LOGIC_VECTOR(31 DOWNTO 0);
        cfg_mgmt_byte_en : STD_LOGIC_VECTOR(3 DOWNTO 0);
        cfg_mgmt_dwaddr : STD_LOGIC_VECTOR(9 DOWNTO 0);
        cfg_mgmt_wr_en : STD_LOGIC;
        cfg_mgmt_rd_en : STD_LOGIC;
        cfg_mgmt_wr_readonly : STD_LOGIC;
        cfg_mgmt_wr_rw1c_as_rw : STD_LOGIC;
end record pcie_cfg_mgmt_port_consumer_r;

end package tlp_streamer_records;
