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

signal ft601_be_rd_i: std_logic_vector(3 downto 0);
signal ft601_data_rd_i: std_logic_vector(31 downto 0);

signal ft601_be_wr_o: std_logic_vector(3 downto 0);
signal ft601_data_wr_o: std_logic_vector(31 downto 0);

signal ft601_bus_wr_s: std_logic;

signal usr_rst_s: std_logic;
signal fifo_rx_wr_data_s: std_logic_vector(35 downto 0);
signal fifo_rx_rd_data_s: std_logic_vector(35 downto 0);
signal fifo_rx_rd_en_s: std_logic;
signal fifo_rx_wr_en_s: std_logic;
signal fifo_rx_wr_full_s: std_logic;
signal fifo_rx_rd_empty_s: std_logic;

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
    empty : OUT STD_LOGIC
  );
END component fifo_36_36_prim;

begin

rx_usb_fifo: fifo_36_36_prim
    port map (
        rst => usr_rst_s,
        wr_clk => ft601_clk_i,
        rd_clk => ft601_clk_i,
        din => fifo_rx_wr_data_s,
        wr_en => fifo_rx_wr_en_s,
        rd_en => fifo_rx_rd_en_s,
        dout => fifo_rx_rd_data_s,
        full => fifo_rx_wr_full_s,
        empty => fifo_rx_rd_empty_s);

clock_process: process(ft601_clk_i, usr_rst_n_i)
begin

    usr_rst_s <= '0';

    ft601_rst_n_o <= usr_rst_n_i;
    if (usr_rst_n_i = '0') then
        current_rx_state <= RX_IDLE;
        usr_rst_s <= '1';
    elsif (ft601_clk_i'EVENT and ft601_clk_i = '1') then
        -- From the datasheet, it looks like signals are expected
        -- to change on the falling edge of the clock and reads
        -- are expected to occur on the rising edge.
        current_rx_state <= next_rx_state;
    end if;

end process clock_process;

bus_read_write: process(ft601_bus_wr_s, ft601_be_io, ft601_data_io,
                        ft601_be_wr_o, ft601_data_wr_o)
begin

    if (ft601_bus_wr_s = '0') then
        ft601_be_io <= "ZZZZ";
        ft601_data_io <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
    else
        ft601_be_io <= ft601_be_wr_o;
        ft601_data_io <= ft601_data_wr_o;
    end if;
    ft601_be_rd_i <= ft601_be_io;
    ft601_data_rd_i <= ft601_data_io;

end process bus_read_write;

rx_process: process(ft601_rxf_n_i, fifo_rx_wr_full_s, ft601_be_rd_i,
                    current_rx_state)
begin

    -- Assume the state does not change by default
    next_rx_state <= current_rx_state;

    -- Assume the FPGA is not taking control of the FT601 bus
    ft601_oe_n_o <= '1';
    ft601_rd_n_o <= '1';
    fifo_rx_wr_en_s <= '0';
    ft601_bus_wr_s <= '0';

    case current_rx_state is
        when RX_IDLE =>
            if (ft601_rxf_n_i = '0') then
                next_rx_state <= RX_READY;
            end if;
        when RX_READY =>
            if (fifo_rx_wr_full_s = '0') then
                next_rx_state <= RX_START;
            end if;
        when RX_START =>
            ft601_oe_n_o <= '0';
            next_rx_state <= RX_WORD;
        when RX_WORD =>
            ft601_oe_n_o <= '0';
            ft601_rd_n_o <= '0';
            fifo_rx_wr_en_s <= '1';

            if (ft601_be_rd_i < "1111" or ft601_rxf_n_i = '1' or fifo_rx_wr_full_s = '1') then
                next_rx_state <= RX_END;
            end if;
        when RX_END =>
            ft601_oe_n_o <= '0';
            ft601_rd_n_o <= '0';
            next_rx_state <= RX_IDLE;
    end case;

end process rx_process;
end architecture RTL;
