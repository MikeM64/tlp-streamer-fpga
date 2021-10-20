--
-- TLP Streamer - Top Module
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;

entity tlp_streamer is
    port (
        ft601_clk_i     : in    std_logic;
        ft601_be_io     : inout std_logic_vector(3 downto 0);
        ft601_data_io   : inout std_logic_vector(31 downto 0);
        ft601_oe_n_o    : out   std_logic;
        ft601_rxf_n_i   : in    std_logic;
        ft601_rd_n_o    : out   std_logic;
        ft601_rst_n_o   : out   std_logic;
        usr_rst_n_i     : in    std_logic);
end entity tlp_streamer;

architecture RTL of tlp_streamer is

type rx_usb_state is (RX_IDLE, RX_READY, RX_START, RX_WORD, RX_END);
signal current_rx_state, next_rx_state: rx_usb_state;
signal ft601_rxf_n_s: std_logic;

begin
rx_process: process(ft601_clk_i, ft601_rxf_n_s, ft601_rxf_n_i,
                    usr_rst_n_i, current_rx_state, ft601_be_io)
begin
    if (usr_rst_n_i = '0') then
        current_rx_state <= RX_IDLE;
        next_rx_state <= RX_IDLE;
        ft601_rst_n_o <= '0';
    elsif (ft601_clk_i'EVENT and ft601_clk_i = '0') then
        current_rx_state <= next_rx_state;
        ft601_rst_n_o <= '1';
        ft601_rxf_n_s <= ft601_rxf_n_i;
    end if;

    case current_rx_state is
        when RX_IDLE => -- NOP, until the FT601 informs the FPGA there's data
            if (ft601_rxf_n_s = '0') then
                next_rx_state <= RX_READY;
            else
                next_rx_state <= RX_IDLE;
            end if;
            ft601_oe_n_o <= '1';
            ft601_rd_n_o <= '1';
        when RX_READY => -- Can't progress until the FIFO is empty (TBD)
            next_rx_state <= RX_START;
            ft601_oe_n_o <= '1';
            ft601_rd_n_o <= '1';
        when RX_START =>
            -- Assert OE to inform the FT601 to start transferring data
            ft601_oe_n_o <= '0';
            ft601_rd_n_o <= '1';
            next_rx_state <= RX_WORD;
        when RX_WORD =>
            -- ft601_rd_n must be asserted for each word being read
            ft601_oe_n_o <= '0';
            ft601_rd_n_o <= '0';
            -- Combine both the data and the BE information
            -- and store together in the FIFO
            if (ft601_be_io < "1111" or ft601_rxf_n_s = '1') then
                next_rx_state <= RX_END;
            else
                next_rx_state <= RX_WORD;
            end if;
        when RX_END =>
            ft601_oe_n_o <= '1';
            ft601_rd_n_o <= '1';
            next_rx_state <= RX_IDLE;
    end case;
end process rx_process;
end architecture RTL;
