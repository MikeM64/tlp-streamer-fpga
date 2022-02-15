--
-- TLP Streamer - FT601 Interface
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tlp_streamer_ft601 is
    port (
        sys_clk_i       : in    std_logic;
        sys_reset_i     : in    std_logic;
        ft601_clk_i     : in    std_logic;
        ft601_be_io     : inout std_logic_vector(3 downto 0);
        ft601_data_io   : inout std_logic_vector(31 downto 0);
        ft601_oe_n_o    : out   std_logic;
        ft601_rxf_n_i   : in    std_logic;
        ft601_rd_n_o    : out   std_logic;
        ft601_rst_n_o   : out   std_logic;
        ft601_txe_n_i   : in    std_logic;
        ft601_wr_n_o    : out   std_logic;
        ft601_siwu_n_o  : out   std_logic;
        ft601_rx_fifo_rd_en_i       : in std_logic;
        ft601_rx_fifo_rd_empty_o    : out std_logic;
        ft601_rx_fifo_rd_valid_o    : out std_logic;
        ft601_rx_fifo_rd_data_o     : out std_logic_vector(35 downto 0);
        ft601_tx_fifo_wr_en_i       : in std_logic;
        ft601_tx_fifo_wr_full_o     : out std_logic;
        ft601_tx_fifo_wr_data_i     : in std_logic_vector(35 downto 0));
end entity tlp_streamer_ft601;

architecture RTL of tlp_streamer_ft601 is

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

--component ila_0 IS
--    PORT (
--        clk : IN STD_LOGIC;
--        probe0 : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
--        probe1 : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
--        probe2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--        probe3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--        probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--        probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--        probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--        probe9 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--        probe10 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
--        probe11 : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
--        probe12 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--        probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
--);
--end component ila_0;

type ft601_bus_state is (BUS_IDLE,
                         RX_READY, RX_START, RX_WORD_1, RX_WORD_2, RX_COMPLETE,
                         TX_READY, TX_WORD, TX_COMPLETE);
signal current_bus_state, next_bus_state: ft601_bus_state;

signal ft601_be_rd_i: std_logic_vector(3 downto 0);
signal ft601_data_rd_i: std_logic_vector(31 downto 0);

signal ft601_be_wr_o: std_logic_vector(3 downto 0);
signal ft601_data_wr_o: std_logic_vector(31 downto 0);

attribute IOB : string;
attribute IOB of ft601_be_wr_o : signal is "TRUE";
attribute IOB of ft601_data_wr_o : signal is "TRUE";

signal ft601_oe_n_s: std_logic;
signal ft601_rd_n_s: std_logic;
signal ft601_wr_n_s_1: std_logic;
signal ft601_wr_n_s_2: std_logic;

signal fifo_rx_wr_data_s: std_logic_vector(35 downto 0);
signal fifo_rx_wr_en_s: std_logic;
signal fifo_rx_wr_full_s: std_logic;

signal fifo_tx_rd_data_s: std_logic_vector(35 downto 0);
signal fifo_tx_rd_en_s: std_logic;
signal fifo_tx_rd_empty_s: std_logic;
signal fifo_tx_rd_valid_s: std_logic;

signal ft601_rx_fifo_rd_valid_s: std_logic;

begin

ft601_rx_usb_fifo: fifo_36_36_prim
    port map (
        rst => sys_reset_i,
        wr_clk => ft601_clk_i,
        rd_clk => sys_clk_i,
        din => fifo_rx_wr_data_s,
        wr_en => fifo_rx_wr_en_s,
        rd_en => ft601_rx_fifo_rd_en_i,
        dout => ft601_rx_fifo_rd_data_o,
        full => fifo_rx_wr_full_s,
        empty => ft601_rx_fifo_rd_empty_o,
        valid => ft601_rx_fifo_rd_valid_s);

ft601_tx_usb_fifo: fifo_36_36_prim
    port map (
        rst => sys_reset_i,
        wr_clk => sys_clk_i,
        rd_clk => ft601_clk_i,
        din => ft601_tx_fifo_wr_data_i,
        wr_en => ft601_tx_fifo_wr_en_i,
        rd_en => fifo_tx_rd_en_s,
        dout => fifo_tx_rd_data_s,
        full => ft601_tx_fifo_wr_full_o,
        empty => fifo_tx_rd_empty_s,
        valid => fifo_tx_rd_valid_s);

--comp_pcie_cfg_ila: ila_0
--    PORT map (
--        clk => ft601_clk_i,
--        probe0 => (others => '0'),
--        probe1 => (others => '0'),
--        probe2 => fifo_tx_rd_data_s(31 downto 0),
--        probe3 => fifo_rx_wr_data_s(31 downto 0),
--        probe4(0) => fifo_tx_rd_en_s,
--        probe5(0) => fifo_rx_wr_en_s,
--        probe6(0) => ft601_txe_n_i,
--        probe7(0) => fifo_tx_rd_empty_s,
--        probe8 => (others => '0'),
--        probe9 => (others => '0'),
--        probe10 => (others => '0'),
--        probe11 => (others => '0'),
--        probe12 => (others => '0'),
--        probe13(0) => ft601_rxf_n_i
--);


bus_read_write: process(ft601_wr_n_s_2, ft601_be_wr_o, ft601_data_wr_o,
                   ft601_be_io, ft601_data_io)
begin

    if (ft601_wr_n_s_2 = '1') then
        ft601_be_io <= "ZZZZ";
        ft601_data_io <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
    else
        ft601_be_io <= ft601_be_wr_o;
        ft601_data_io <= ft601_data_wr_o;
    end if;
    ft601_be_rd_i <= ft601_be_io;
    ft601_data_rd_i <= ft601_data_io;

end process bus_read_write;

ft601_clock_process: process(ft601_clk_i, ft601_be_rd_i,
                             ft601_data_rd_i, next_bus_state,
                             ft601_oe_n_s, ft601_rx_fifo_rd_valid_s,
                             ft601_rd_n_s, fifo_tx_rd_data_s,
                             ft601_wr_n_s_1, ft601_wr_n_s_2)
begin

    -- SIWU_N is listed as reserved in the FT601 datasheet.
    -- It *is* listed in the following datasheet:
    -- https://www.ftdichip.com/Support/Documents/AppNotes/AN_165_Establishing_Synchronous_245_FIFO_Communications_using_a_Morph-IC-II.pdf
    -- SI/WU == Send Immediate / Wake Up, assert this signal to send any TX data
    -- to the USB host immediately or to wake the host up from suspend.
    ft601_siwu_n_o <= '0';
    ft601_rx_fifo_rd_valid_o <= ft601_rx_fifo_rd_valid_s;
    fifo_rx_wr_data_s <= ft601_be_rd_i & ft601_data_rd_i;

    if (rising_edge(ft601_clk_i)) then
        ft601_oe_n_o <= ft601_oe_n_s;
        ft601_wr_n_s_2 <= ft601_wr_n_s_1;
        ft601_rd_n_o <= ft601_rd_n_s;
        ft601_wr_n_o <= ft601_wr_n_s_1;
        ft601_be_wr_o <= fifo_tx_rd_data_s(35 downto 32);
        ft601_data_wr_o <= fifo_tx_rd_data_s(31 downto 0);
    end if;

end process ft601_clock_process;

ft601_fsm_state_process: process(ft601_clk_i, next_bus_state, sys_reset_i)
begin

    ft601_rst_n_o <= not sys_reset_i;

    if (sys_reset_i = '1') then
        current_bus_state <= BUS_IDLE;
    elsif (rising_edge(ft601_clk_i)) then
        current_bus_state <= next_bus_state;
    end if;

end process ft601_fsm_state_process;

ft601_fsm_data_output_process: process(current_bus_state, ft601_rxf_n_i,
                                       fifo_tx_rd_valid_s)
begin

    -- Assume the FPGA is not taking control of the FT601 bus
    ft601_oe_n_s <= '1';
    ft601_rd_n_s <= '1';
    ft601_wr_n_s_1 <= '1';
    fifo_rx_wr_en_s <= '0';
    fifo_tx_rd_en_s <= '0';

    case current_bus_state is
        when RX_START =>
            ft601_oe_n_s <= '0';
        when RX_WORD_1 =>
            -- Insert a delay state to ensure the RX FIFO only
            -- starts clocking valid data
            ft601_oe_n_s <= '0';
            ft601_rd_n_s <= '0';
        when RX_WORD_2 =>
            -- Insert a delay state to ensure the RX FIFO only
            -- starts clocking valid data
            ft601_oe_n_s <= '0';
            ft601_rd_n_s <= '0';
            fifo_rx_wr_en_s <= not ft601_rxf_n_i;
        when RX_COMPLETE =>
            ft601_oe_n_s <= '1';
            ft601_rd_n_s <= '1';
        when TX_WORD =>
            fifo_tx_rd_en_s <= '1';
            ft601_wr_n_s_1 <= not fifo_tx_rd_valid_s;
        when others =>
    end case;

end process ft601_fsm_data_output_process;

ft601_fsm_state_select_process: process(current_bus_state, ft601_txe_n_i, ft601_rxf_n_i,
                                        fifo_rx_wr_full_s, fifo_tx_rd_empty_s, fifo_tx_rd_data_s)

variable ft601_words_to_write_v: integer;

begin
    -- Assume the state does not change by default
    next_bus_state <= current_bus_state;
    ft601_words_to_write_v := 0;

    case current_bus_state is
        when BUS_IDLE =>
            if (ft601_txe_n_i = '0' and fifo_tx_rd_empty_s = '0') then
                next_bus_state <= TX_READY;
            elsif (ft601_rxf_n_i = '0' and fifo_rx_wr_full_s = '0') then
                next_bus_state <= RX_READY;
            end if;
        when RX_READY =>
            next_bus_state <= RX_START;
        when RX_START =>
            next_bus_state <= RX_WORD_1;
        when RX_WORD_1 =>
            next_bus_state <= RX_WORD_2;
        when RX_WORD_2 =>
            if (ft601_rxf_n_i = '1') then
                next_bus_state <= RX_COMPLETE;
            end if;
        when RX_COMPLETE =>
            next_bus_state <= BUS_IDLE;
        when TX_READY =>
            next_bus_state <= TX_WORD;
            ft601_words_to_write_v := to_integer(unsigned(fifo_tx_rd_data_s(23 downto 16) & fifo_tx_rd_data_s(31 downto 24)));
        when TX_WORD =>
            ft601_words_to_write_v := ft601_words_to_write_v - 1;
            if (ft601_txe_n_i = '1' or fifo_tx_rd_empty_s = '1' or ft601_words_to_write_v = 0) then
                next_bus_state <= TX_COMPLETE;
            end if;
        when TX_COMPLETE =>
            next_bus_state <= BUS_IDLE;
    end case;

end process ft601_fsm_state_select_process;


end architecture RTL;