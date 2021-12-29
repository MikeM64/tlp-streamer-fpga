--
-- TLP Streamer - PCIe Interface
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

use work.tlp_streamer_records.all;

entity tlp_streamer_pcie is
    port (
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
        --pcie_usr_clk_o : out std_logic;
        --pcie_usr_rst_o : out std_logic;
        pcie_usr_link_up_o : out std_logic;
        -- Host Packet RX/TX management
        pcie_cfg_dispatch_i : in dispatch_producer_r;
        pcie_cfg_dispatch_o : out dispatch_consumer_r;
        pcie_cfg_arbiter_i : in arbiter_producer_r;
        pcie_cfg_arbiter_o : out arbiter_consumer_r);
        --pcie_usr_app_rdy : out std_logic;
        --pcie_s_axi_tx_tready_o : out std_logic;
        --pcie_s_axi_tx_tdata_i : in std_logic_vector(63 downto 0);
        --pcie_s_axi_tx_tkeep_i : in std_logic_vector(7 downto 0);
        --pcie_s_axi_tx_tlast_i : in std_logic;
        --pcie_s_axi_tx_tvalid_i : in std_logic;
        --pcie_s_axi_tx_tuser_i : in std_logic_vector(3 downto 0);
        --pcie_m_axi_rx_tdata_o : out std_logic_vector(63 downto 0);
        --pcie_m_axi_rx_tkeep_o : out std_logic_vector(7 downto 0);
        --pcie_m_axi_rx_tlast_o : out std_logic;
        --pcie_m_axi_rx_tvalid_o : out std_logic;
        --pcie_m_axi_rx_tready_i : in std_logic;
        --pcie_m_axi_rx_tuser_o : out std_logic_vector(21 downto 0);
end entity tlp_streamer_pcie;

architecture RTL of tlp_streamer_pcie is

component pcie_7x_0 IS
  PORT (
    pci_exp_txp : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    pci_exp_txn : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    pci_exp_rxp : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    pci_exp_rxn : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    user_clk_out : OUT STD_LOGIC;
    user_reset_out : OUT STD_LOGIC;
    user_lnk_up : OUT STD_LOGIC;
    user_app_rdy : OUT STD_LOGIC;
    s_axis_tx_tready : OUT STD_LOGIC;
    s_axis_tx_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    s_axis_tx_tkeep : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axis_tx_tlast : IN STD_LOGIC;
    s_axis_tx_tvalid : IN STD_LOGIC;
    s_axis_tx_tuser : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axis_rx_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axis_rx_tkeep : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axis_rx_tlast : OUT STD_LOGIC;
    m_axis_rx_tvalid : OUT STD_LOGIC;
    m_axis_rx_tready : IN STD_LOGIC;
    m_axis_rx_tuser : OUT STD_LOGIC_VECTOR(21 DOWNTO 0);
    -- PCIe configuration management port
    cfg_mgmt_do : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    cfg_mgmt_rd_wr_done : OUT STD_LOGIC;
    cfg_mgmt_di : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    cfg_mgmt_byte_en : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    cfg_mgmt_dwaddr : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    cfg_mgmt_wr_en : IN STD_LOGIC;
    cfg_mgmt_rd_en : IN STD_LOGIC;
    cfg_mgmt_wr_readonly : IN STD_LOGIC;
    cfg_mgmt_wr_rw1c_as_rw : IN STD_LOGIC;
    cfg_interrupt : IN STD_LOGIC;
    cfg_interrupt_rdy : OUT STD_LOGIC;
    cfg_interrupt_assert : IN STD_LOGIC;
    cfg_interrupt_di : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    cfg_interrupt_do : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    cfg_interrupt_mmenable : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    cfg_interrupt_msienable : OUT STD_LOGIC;
    cfg_interrupt_msixenable : OUT STD_LOGIC;
    cfg_interrupt_msixfm : OUT STD_LOGIC;
    cfg_interrupt_stat : IN STD_LOGIC;
    cfg_pciecap_interrupt_msgnum : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    pl_directed_link_change : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    pl_directed_link_width : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    pl_directed_link_speed : IN STD_LOGIC;
    pl_directed_link_auton : IN STD_LOGIC;
    pl_upstream_prefer_deemph : IN STD_LOGIC;
    pl_sel_lnk_rate : OUT STD_LOGIC; --
    pl_sel_lnk_width : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    pl_ltssm_state : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    pl_lane_reversal_mode : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    pl_phy_lnk_up : OUT STD_LOGIC;
    pl_tx_pm_state : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    pl_rx_pm_state : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    pl_link_upcfg_cap : OUT STD_LOGIC;
    pl_link_gen2_cap : OUT STD_LOGIC;
    pl_link_partner_gen2_supported : OUT STD_LOGIC;
    pl_initial_link_width : OUT STD_LOGIC_VECTOR(2 DOWNTO 0); --
    pl_directed_change_done : OUT STD_LOGIC;
    pl_received_hot_rst : OUT STD_LOGIC;
    pl_transmit_hot_rst : IN STD_LOGIC;
    pl_downstream_deemph_source : IN STD_LOGIC;
    sys_clk : IN STD_LOGIC;
    sys_rst_n : IN STD_LOGIC
  );
END component pcie_7x_0;

component tlp_streamer_pcie_cfg is
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
end component tlp_streamer_pcie_cfg;


component pcie_ila IS
PORT (
    clk : IN STD_LOGIC;
    probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe1 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe2 : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    probe3 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe5 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe6 : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe10 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    probe11 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe12 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe14 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe15 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe16 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
);
END component pcie_ila;

signal pcie_rst_n_s: std_logic;
signal pcie_clk_s: std_logic;

-- Temporary signal until more behaviour is implemented/exposed to other components.
signal user_clk_s, user_lnk_up_s, user_reset_s, user_app_rdy_s: std_logic;

signal s_axis_tx_tready_s, s_axis_tx_tlast_s, s_axis_tx_tvalid_s: std_logic := '0';
signal s_axis_tx_tdata_s: std_logic_vector(63 downto 0) := "0000000000000000000000000000000000000000000000000000000000000000";
signal s_axis_tx_tkeep_s: std_logic_vector(7 downto 0) := "00000000";
signal s_axis_tx_tuser_s: std_logic_vector(3 downto 0) := "0000";

signal m_axis_rx_tlast_s, m_axis_rx_tvalid_s, m_axis_rx_tready_s: std_logic := '0';
signal m_axis_rx_tdata_s: std_logic_vector(63 downto 0) := "0000000000000000000000000000000000000000000000000000000000000000";
signal m_axis_rx_tkeep_s: std_logic_vector(7 downto 0) := "00000000";
signal m_axis_rx_tuser_s: std_logic_vector(21 downto 0) := "0000000000000000000000";

signal cfg_interrupt_s, cfg_interrupt_rdy_s, cfg_interrupt_assert_s,
    cfg_interrupt_msienable_s, cfg_interrupt_msixenable_s,
    cfg_interrupt_msixfm_s, cfg_interrupt_stat_s: std_logic := '0';
signal cfg_interrupt_di_s, cfg_interrupt_do_s: std_logic_vector(7 downto 0) := "00000000";
signal cfg_interrupt_mmenable_s: std_logic_vector(2 downto 0) := "000";
signal cfg_pciecap_interrupt_msgnum_s: std_logic_vector(4 downto 0) := "00000";

signal pl_directed_link_change_s, pl_directed_link_width_s: std_logic_vector(1 downto 0) := "00";
signal pl_directed_link_speed_s, pl_directed_link_auton_s, pl_upstream_prefer_deemph_s,
    pl_sel_lnk_rate_s, pl_phy_lnk_up_s, pl_link_upcfg_cap_s, pl_link_gen2_cap_s,
    pl_link_partner_gen2_supported_s, pl_directed_change_done_s, pl_received_hot_rst_s,
    pl_transmit_hot_rst_s, pl_downstream_deemph_source_s: std_logic := '0';
signal pl_sel_lnk_width_s, pl_lane_reversal_mode_s, pl_rx_pm_state_s: std_logic_vector(1 downto 0) := "00";
signal pl_ltssm_state_s: std_logic_vector(5 downto 0) := "000000";
signal pl_tx_pm_state_s, pl_initial_link_width_s: std_logic_vector(2 downto 0) := "000";

signal pcie_clk_blink_64_s: unsigned(63 downto 0) := (others => '0');

-- Configuration management interface
signal pcie_cfg_mgmt_producer_s: pcie_cfg_mgmt_port_producer_r;
signal pcie_cfg_mgmt_consumer_s: pcie_cfg_mgmt_port_consumer_r;

begin

-- Refer to https://www.xilinx.com/support/documentation/user_guides/ug482_7Series_GTP_Transceivers.pdf
-- Page 24 for IBUFDS_GTE2 configuration options
ibufds_gte2_pcie_clk : IBUFDS_GTE2
    generic map (
        CLKCM_CFG => TRUE,
        CLKRCV_TRST => TRUE,
        CLKSWING_CFG => "11"
    )
    port map (
        O => pcie_clk_s,
        ODIV2 => open,
        CEB => '0',
        I => pcie_clk_p_i,
        IB => pcie_clk_n_i
);

comp_tlp_streamer_pcie_cfg: tlp_streamer_pcie_cfg
    port map (
        sys_clk_i => sys_clk_i,
        pcie_clk_i => user_clk_s,
        sys_reset_i => sys_reset_i,
        -- PCIe Configuration Port from PCIe IP
        pcie_cfg_mgmt_producer_i => pcie_cfg_mgmt_producer_s,
        pcie_cfg_mgmt_consumer_o => pcie_cfg_mgmt_consumer_s,
        -- Input Requests from the host to handle
        dispatch_i => pcie_cfg_dispatch_i,
        dispatch_o => pcie_cfg_dispatch_o,
        -- Output Packets towards the host
        arbiter_i => pcie_cfg_arbiter_i,
        arbiter_o => pcie_cfg_arbiter_o);

comp_pcie_7x_0: pcie_7x_0
    port map(
        pci_exp_txp => pcie_txp_o,
        pci_exp_txn => pcie_txn_o,
        pci_exp_rxp => pcie_rxp_i,
        pci_exp_rxn => pcie_rxn_i,
        user_clk_out => user_clk_s,
        user_reset_out => user_reset_s,
        user_lnk_up => user_lnk_up_s,
        user_app_rdy => user_app_rdy_s,
        s_axis_tx_tready => s_axis_tx_tready_s,
        s_axis_tx_tdata => s_axis_tx_tdata_s,
        s_axis_tx_tkeep => s_axis_tx_tkeep_s,
        s_axis_tx_tlast => s_axis_tx_tlast_s,
        s_axis_tx_tvalid => s_axis_tx_tvalid_s,
        s_axis_tx_tuser => s_axis_tx_tuser_s,
        m_axis_rx_tdata => m_axis_rx_tdata_s,
        m_axis_rx_tkeep => m_axis_rx_tkeep_s,
        m_axis_rx_tlast => m_axis_rx_tlast_s,
        m_axis_rx_tvalid => m_axis_rx_tvalid_s,
        m_axis_rx_tready => m_axis_rx_tready_s,
        m_axis_rx_tuser => m_axis_rx_tuser_s,
        -- Configuration space management port
        cfg_mgmt_do => pcie_cfg_mgmt_producer_s.cfg_mgmt_do,
        cfg_mgmt_rd_wr_done => pcie_cfg_mgmt_producer_s.cfg_mgmt_rd_wr_done,
        cfg_mgmt_di => pcie_cfg_mgmt_consumer_s.cfg_mgmt_di,
        cfg_mgmt_byte_en => pcie_cfg_mgmt_consumer_s.cfg_mgmt_byte_en,
        cfg_mgmt_dwaddr => pcie_cfg_mgmt_consumer_s.cfg_mgmt_dwaddr,
        cfg_mgmt_wr_en => pcie_cfg_mgmt_consumer_s.cfg_mgmt_wr_en,
        cfg_mgmt_rd_en => pcie_cfg_mgmt_consumer_s.cfg_mgmt_rd_en,
        cfg_mgmt_wr_readonly => pcie_cfg_mgmt_consumer_s.cfg_mgmt_wr_readonly,
        cfg_mgmt_wr_rw1c_as_rw => pcie_cfg_mgmt_consumer_s.cfg_mgmt_wr_rw1c_as_rw,
        cfg_interrupt => cfg_interrupt_s,
        cfg_interrupt_rdy => cfg_interrupt_rdy_s,
        cfg_interrupt_assert => cfg_interrupt_assert_s,
        cfg_interrupt_di => cfg_interrupt_di_s,
        cfg_interrupt_do => cfg_interrupt_do_s,
        cfg_interrupt_mmenable => cfg_interrupt_mmenable_s,
        cfg_interrupt_msienable => cfg_interrupt_msienable_s,
        cfg_interrupt_msixenable => cfg_interrupt_msixenable_s,
        cfg_interrupt_msixfm => cfg_interrupt_msixfm_s,
        cfg_interrupt_stat => cfg_interrupt_stat_s,
        cfg_pciecap_interrupt_msgnum => cfg_pciecap_interrupt_msgnum_s,
        pl_directed_link_change => pl_directed_link_change_s,
        pl_directed_link_width => pl_directed_link_width_s,
        pl_directed_link_speed => pl_directed_link_speed_s,
        pl_directed_link_auton => pl_directed_link_auton_s,
        pl_upstream_prefer_deemph => pl_upstream_prefer_deemph_s,
        pl_sel_lnk_rate => pl_sel_lnk_rate_s,
        pl_sel_lnk_width => pl_sel_lnk_width_s,
        pl_ltssm_state => pl_ltssm_state_s,
        pl_lane_reversal_mode => pl_lane_reversal_mode_s,
        pl_phy_lnk_up => pl_phy_lnk_up_s,
        pl_tx_pm_state => pl_tx_pm_state_s,
        pl_rx_pm_state => pl_rx_pm_state_s,
        pl_link_upcfg_cap => pl_link_upcfg_cap_s,
        pl_link_gen2_cap => pl_link_gen2_cap_s,
        pl_link_partner_gen2_supported => pl_link_partner_gen2_supported_s,
        pl_initial_link_width => pl_initial_link_width_s,
        pl_directed_change_done => pl_directed_change_done_s,
        pl_received_hot_rst => pl_received_hot_rst_s,
        pl_transmit_hot_rst => pl_transmit_hot_rst_s,
        pl_downstream_deemph_source => pl_downstream_deemph_source_s,
        sys_clk => pcie_clk_s,
        sys_rst_n => pcie_rst_n_s
  );

comp_pcie_ila: pcie_ila
    port map(
        clk => user_clk_s,
        probe0(0) => pl_sel_lnk_rate_s,
        probe1 => pl_sel_lnk_width_s,
        probe2 => pl_ltssm_state_s,
        probe3 => pl_lane_reversal_mode_s,
        probe4(0) => pl_phy_lnk_up_s,
        probe5 => pl_tx_pm_state_s,
        probe6 => pl_rx_pm_state_s,
        probe7(0) => pl_link_upcfg_cap_s,
        probe8(0) => pl_link_gen2_cap_s,
        probe9(0) => pl_link_partner_gen2_supported_s,
        probe10 => pl_initial_link_width_s,
        probe11(0) => pcie_rst_n_s,
        probe12(0) => user_reset_s,
        probe13(0) => user_lnk_up_s,
        probe14(0) => user_app_rdy_s,
        probe15(0) => pcie_perst_n_i,
        probe16(0) => sys_reset_i
    );

pcie_wake_n_o <= '1';
pcie_rst_n_s <= not (sys_reset_i or not pcie_perst_n_i);
pcie_usr_link_up_o <= user_lnk_up_s;

blink_debug_process: process(pcie_clk_s, pcie_clk_blink_64_s)
begin
    user_led_ld2 <= pcie_clk_blink_64_s(25);

    if (rising_edge(pcie_clk_s)) then
        pcie_clk_blink_64_s <= pcie_clk_blink_64_s + 1;
    end if;

end process blink_debug_process;

end architecture RTL;