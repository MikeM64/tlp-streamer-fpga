set_property PACKAGE_PIN L18 [get_ports {ft601_be_io[0]}]
set_property PACKAGE_PIN M17 [get_ports {ft601_be_io[1]}]
set_property PACKAGE_PIN N18 [get_ports {ft601_be_io[2]}]
set_property PACKAGE_PIN N17 [get_ports {ft601_be_io[3]}]
set_property PACKAGE_PIN B9  [get_ports {ft601_data_io[0]}]
set_property PACKAGE_PIN A9  [get_ports {ft601_data_io[1]}]
set_property PACKAGE_PIN C9  [get_ports {ft601_data_io[2]}]
set_property PACKAGE_PIN A10 [get_ports {ft601_data_io[3]}]
set_property PACKAGE_PIN B10 [get_ports {ft601_data_io[4]}]
set_property PACKAGE_PIN B11 [get_ports {ft601_data_io[5]}]
set_property PACKAGE_PIN A12 [get_ports {ft601_data_io[6]}]
set_property PACKAGE_PIN B12 [get_ports {ft601_data_io[7]}]
set_property PACKAGE_PIN A13 [get_ports {ft601_data_io[8]}]
set_property PACKAGE_PIN A14 [get_ports {ft601_data_io[9]}]
set_property PACKAGE_PIN B14 [get_ports {ft601_data_io[10]}]
set_property PACKAGE_PIN A15 [get_ports {ft601_data_io[11]}]
set_property PACKAGE_PIN B15 [get_ports {ft601_data_io[12]}]
set_property PACKAGE_PIN B16 [get_ports {ft601_data_io[13]}]
set_property PACKAGE_PIN A17 [get_ports {ft601_data_io[14]}]
set_property PACKAGE_PIN B17 [get_ports {ft601_data_io[15]}]
set_property PACKAGE_PIN C17 [get_ports {ft601_data_io[16]}]
set_property PACKAGE_PIN C18 [get_ports {ft601_data_io[17]}]
set_property PACKAGE_PIN D18 [get_ports {ft601_data_io[18]}]
set_property PACKAGE_PIN E17 [get_ports {ft601_data_io[19]}]
set_property PACKAGE_PIN E18 [get_ports {ft601_data_io[20]}]
set_property PACKAGE_PIN E16 [get_ports {ft601_data_io[21]}]
set_property PACKAGE_PIN F18 [get_ports {ft601_data_io[22]}]
set_property PACKAGE_PIN F17 [get_ports {ft601_data_io[23]}]
set_property PACKAGE_PIN G17 [get_ports {ft601_data_io[24]}]
set_property PACKAGE_PIN H18 [get_ports {ft601_data_io[25]}]
set_property PACKAGE_PIN D13 [get_ports {ft601_data_io[26]}]
set_property PACKAGE_PIN C14 [get_ports {ft601_data_io[27]}]
set_property PACKAGE_PIN D14 [get_ports {ft601_data_io[28]}]
set_property PACKAGE_PIN D15 [get_ports {ft601_data_io[29]}]
set_property PACKAGE_PIN C16 [get_ports {ft601_data_io[30]}]
set_property PACKAGE_PIN D16 [get_ports {ft601_data_io[31]}]
set_property PACKAGE_PIN T15 [get_ports ft601_oe_n_o]
set_property PACKAGE_PIN R16 [get_ports ft601_rd_n_o]
set_property PACKAGE_PIN R18 [get_ports ft601_rxf_n_i]
set_property PACKAGE_PIN R17 [get_ports ft601_siwu_n_o]
set_property PACKAGE_PIN P18 [get_ports ft601_txe_n_i]
set_property PACKAGE_PIN T18 [get_ports ft601_wr_n_o]
set_property PACKAGE_PIN U15 [get_ports ft601_rst_n_o]
set_property IOSTANDARD LVCMOS33 [get_ports {ft601_rxf_n_i ft601_txe_n_i ft601_rst_n_o ft601_oe_n_o ft601_rd_n_o ft601_wr_n_o ft601_siwu_n_o}]
set_property IOSTANDARD LVCMOS33 [get_ports {{ft601_be_io[*]} {ft601_data_io[*]}}]
set_property SLEW FAST [get_ports {{ft601_be_io[*]} {ft601_data_io[*]}}]
set_property SLEW FAST [get_ports {ft601_siwu_n_o ft601_wr_n_o ft601_rd_n_o ft601_oe_n_o ft601_rst_n_o}]

# LEDs are active high
set_property PACKAGE_PIN V17 [get_ports user_led_ld1]
set_property PACKAGE_PIN U17 [get_ports user_led_ld2]
set_property IOSTANDARD LVCMOS33 [get_ports user_led_ld1]
set_property IOSTANDARD LVCMOS33 [get_ports user_led_ld2]

# SYSCLK
set_property PACKAGE_PIN R2 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -period 10.000 -name net_clk -waveform {0.000 5.000} [get_ports sys_clk]

# FT601 CLK
set_property IOSTANDARD LVCMOS33 [get_ports ft601_clk_i]
set_property PACKAGE_PIN E13 [get_ports ft601_clk_i]
create_clock -period 10.000 -name net_ft601_clk_i -waveform {0.000 5.000} [get_ports ft601_clk_i]

# Delay constraints are from FT601 Data sheet pg. 17
set_input_delay -clock [get_clocks net_ft601_clk_i] -min 3.000 [get_ports {{ft601_data_io[*]} {ft601_be_io[*]}}]
set_input_delay -clock [get_clocks net_ft601_clk_i] -max 3.500 [get_ports {{ft601_data_io[*]} {ft601_be_io[*]}}]
set_output_delay -clock [get_clocks net_ft601_clk_i] -min 4.800 [get_ports {{ft601_data_io[*]} {ft601_be_io[*]}}]
set_output_delay -clock [get_clocks net_ft601_clk_i] -max 1.000 [get_ports {{ft601_data_io[*]} {ft601_be_io[*]}}]

set_input_delay -clock [get_clocks net_ft601_clk_i] -min 3.000 [get_ports {ft601_rxf_n_i ft601_txe_n_i}]
set_input_delay -clock [get_clocks net_ft601_clk_i] -max 3.500 [get_ports {ft601_rxf_n_i ft601_txe_n_i}]

set_output_delay -clock [get_clocks net_ft601_clk_i] -min 4.800 [get_ports {ft601_wr_n_o ft601_rd_n_o ft601_oe_n_o ft601_rst_n_o ft601_siwu_n_o}]
set_output_delay -clock [get_clocks net_ft601_clk_i] -max 1.000 [get_ports {ft601_wr_n_o ft601_rd_n_o ft601_oe_n_o ft601_rst_n_o ft601_siwu_n_o}]

# Constrain the LEDs to clean up the timing report
set_output_delay -clock [get_clocks net_ft601_clk_i] -max 0.000 [get_ports {user_led_ld1 user_led_ld2}]
set_output_delay -clock [get_clocks net_ft601_clk_i] -min 10.000 [get_ports {user_led_ld1 user_led_ld2}]

# Exclude the reset hold counter from timing analysis as it only exists to
# generate a reset signal during initial power-on.
set_false_path -from [get_pins {reset_hold_count64_s_reg[*]/C}]
set_false_path -to [get_ports {user_led_ld1 user_led_ld2}]

# Force external signal registers to be in the IO Block for timing closure
# Forcing the following three to IOB makes the design come within 1 net of timing closure
set_property IOB TRUE [get_cells comp_tlp_streamer_ft601/ft601_rd_n_o_reg*]
set_property IOB TRUE [get_cells comp_tlp_streamer_ft601/ft601_oe_n_o_reg*]
set_property IOB TRUE [get_cells comp_tlp_streamer_ft601/ft601_wr_n_o_reg*]
set_multicycle_path 2 -from [get_pins comp_tlp_streamer_ft601/ft601_wr_n_s_2_reg*/C] -to [get_ports {{ft601_be_io[*]} {ft601_data_io[*]}}]

#set_multicycle_path 2 -from [get_pins i_pcileech_com/i_pcileech_ft601/oe_reg/C] -to [get_ports {{ft601_be_io[*]} {ft601_data_io[*]}}]
#set_multicycle_path 2 -from [get_clocks net_ft601_clk_i] -to [get_ports {{ft601_be_io[*]} {ft601_data_io[*]}}]
#set_multicycle_path 2 -from [get_clocks net_ft601_clk_i] -to [get_ports ft601_oe_n_o]
#set_multicycle_path 2 -from [get_clocks net_ft601_clk_i] -to [get_ports ft601_rd_n_o]
#set_false_path -from [get_pins {i_pcileech_fifo/_pcie_core_config_reg[*]/C}]
#set_false_path -from [get_pins i_pcileech_pcie_a7/i_pcie_7x_0/inst/inst/user_lnk_up_int_reg/C] -to [get_pins {i_pcileech_fifo/_cmd_tx_din_reg[16]/D}]
#set_false_path -from [get_pins i_pcileech_pcie_a7/i_pcie_7x_0/inst/inst/user_reset_out_reg/C]

#PCIe signals
#set_property PACKAGE_PIN K1 [get_ports pcie_present]
#set_property PACKAGE_PIN M1 [get_ports pcie_perst_n]
#set_property PACKAGE_PIN L2 [get_ports pcie_wake_n]
#set_property IOSTANDARD LVCMOS33 [get_ports pcie_present]
#set_property IOSTANDARD LVCMOS33 [get_ports pcie_perst_n]
#set_property IOSTANDARD LVCMOS33 [get_ports pcie_wake_n]

#set_property LOC GTPE2_CHANNEL_X0Y2 [get_cells {i_pcileech_pcie_a7/i_pcie_7x_0/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]
#set_property PACKAGE_PIN E3 [get_ports {pcie_rx_n[0]}]
#set_property PACKAGE_PIN E4 [get_ports {pcie_rx_p[0]}]
#set_property PACKAGE_PIN H1 [get_ports {pcie_tx_n[0]}]
#set_property PACKAGE_PIN H2 [get_ports {pcie_tx_p[0]}]

#set_property PACKAGE_PIN A3 [get_ports {pcie_rx_n[1]}]
#set_property PACKAGE_PIN A4 [get_ports {pcie_rx_p[1]}]
#set_property PACKAGE_PIN F1 [get_ports {pcie_tx_n[1]}]
#set_property PACKAGE_PIN F2 [get_ports {pcie_tx_p[1]}]

#set_property PACKAGE_PIN C3 [get_ports {pcie_rx_n[2]}]
#set_property PACKAGE_PIN C4 [get_ports {pcie_rx_p[2]}]
#set_property PACKAGE_PIN D1 [get_ports {pcie_tx_n[2]}]
#set_property PACKAGE_PIN D2 [get_ports {pcie_tx_p[2]}]

#set_property PACKAGE_PIN G3 [get_ports {pcie_rx_n[3]}]
#set_property PACKAGE_PIN G4 [get_ports {pcie_rx_p[3]}]
#set_property PACKAGE_PIN B1 [get_ports {pcie_tx_n[3]}]
#set_property PACKAGE_PIN B2 [get_ports {pcie_tx_p[3]}]

#set_property PACKAGE_PIN D5 [get_ports pcie_clk_n]
#set_property PACKAGE_PIN D6 [get_ports pcie_clk_p]

#create_clock -name pcie_sys_clk_p -period 10.0 [get_nets pcie_clk_p]

set_property CFGBVS Vcco [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]