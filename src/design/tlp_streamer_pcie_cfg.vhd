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

signal cfg_clk_s: std_logic;

signal cfg_mgmt_do : std_logic_vector(31 downto 0);
signal cfg_mgmt_rd_wr_done : std_logic;

begin

cfg_clk_s <= sys_clk_i;

cfg_mgmt_do <= pcie_cfg_mgmt_producer_i.cfg_mgmt_do;
cfg_mgmt_rd_wr_done <= pcie_cfg_mgmt_producer_i.cfg_mgmt_rd_wr_done;

pcie_cfg_mgmt_consumer_o.cfg_mgmt_di <= (others => '0');
pcie_cfg_mgmt_consumer_o.cfg_mgmt_byte_en <= (others => '0');
pcie_cfg_mgmt_consumer_o.cfg_mgmt_dwaddr <= (others => '0');
pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_en <= '0';
pcie_cfg_mgmt_consumer_o.cfg_mgmt_rd_en <= '0';
pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_readonly <= '0';
pcie_cfg_mgmt_consumer_o.cfg_mgmt_wr_rw1c_as_rw <= '0';

end architecture RTL;