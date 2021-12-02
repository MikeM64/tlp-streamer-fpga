--
-- TLP Streamer - Top Module
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tlp_streamer is
    port (
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
        user_led_ld1    : out   std_logic;
        user_led_ld2    : out   std_logic;
        sys_clk         : in    std_logic);
end entity tlp_streamer;

architecture RTL of tlp_streamer is

type ft601_bus_state is (BUS_IDLE, RX_READY, RX_START, RX_WORD_1,
                         RX_WORD_2, RX_COMPLETE, TX_READY,
                         TX_START, TX_WORD, TX_COMPLETE);
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
signal fifo_rx_tx_loopback_data_s: std_logic_vector(35 downto 0);
signal fifo_rx_rd_en_s: std_logic;
signal fifo_rx_wr_en_s, fifo_rx_wr_en_s_reg: std_logic;
signal fifo_rx_wr_full_s: std_logic;
signal fifo_rx_rd_empty_s: std_logic;
signal fifo_rx_rd_valid_s: std_logic;

signal fifo_tx_rd_data_s: std_logic_vector(35 downto 0);
signal fifo_tx_wr_en_s: std_logic;
signal fifo_tx_rd_en_s: std_logic;
signal fifo_tx_wr_full_s: std_logic;
signal fifo_tx_rd_empty_s: std_logic;
signal fifo_tx_rd_valid_s: std_logic;

signal fifo_loopback_rd_wr_en_s: std_logic;
signal reset_hold_count64_s: unsigned(63 downto 0) := (others => '0');
signal tlp_streamer_reset_s: std_logic;

signal ila_trigger_in_s: std_logic;
signal ila_trigger_in_ack: std_logic;

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

component ila_0 IS
    PORT (
        clk : IN STD_LOGIC;
        trig_in : IN STD_LOGIC;
        trig_in_ack : OUT STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        probe1 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0));
END component ila_0;

begin

rx_usb_fifo: fifo_36_36_prim
    port map (
        rst => tlp_streamer_reset_s,
        wr_clk => ft601_clk_i,
        rd_clk => sys_clk,
        din => fifo_rx_wr_data_s,
        wr_en => fifo_rx_wr_en_s,
        rd_en => fifo_rx_rd_en_s,
        dout => fifo_rx_tx_loopback_data_s,
        full => fifo_rx_wr_full_s,
        empty => fifo_rx_rd_empty_s,
        valid => fifo_rx_rd_valid_s);

tx_usb_fifo: fifo_36_36_prim
    port map (
        rst => tlp_streamer_reset_s,
        wr_clk => sys_clk,
        rd_clk => ft601_clk_i,
        din => fifo_rx_tx_loopback_data_s,
        wr_en => fifo_tx_wr_en_s,
        rd_en => fifo_tx_rd_en_s,
        dout => fifo_tx_rd_data_s,
        full => fifo_tx_wr_full_s,
        empty => fifo_tx_rd_empty_s,
        valid => fifo_tx_rd_valid_s);

ft601_bus_ila: ila_0
    port map (
        clk => ft601_clk_i,
        trig_in => ila_trigger_in_s,
        trig_in_ack => ila_trigger_in_ack,
        probe0 => ft601_data_io,
        probe1 => ft601_be_io,
        probe2(0) => ft601_rxf_n_i,
        probe3(0) => ft601_txe_n_i,
        probe4(0) => ft601_oe_n_s,
        probe5(0) => ft601_rd_n_s,
        probe6(0) => ft601_wr_n_s_2,
        probe7(0) => fifo_rx_wr_en_s,
        probe8(0) => fifo_tx_wr_en_s);

reset_process: process(sys_clk, reset_hold_count64_s, tlp_streamer_reset_s)
begin

    ft601_rst_n_o <= not tlp_streamer_reset_s;
    user_led_ld1 <= not tlp_streamer_reset_s;

    -- Hold reset for 50ms
    if (reset_hold_count64_s < to_unsigned(64, 64)) then
        tlp_streamer_reset_s <= '1';
    else
        tlp_streamer_reset_s <= '0';
    end if;

    if (rising_edge(sys_clk)) then
        reset_hold_count64_s <= reset_hold_count64_s + 1;
    end if;

end process reset_process;

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

fifo_loopback_ctrl: process(fifo_rx_rd_empty_s, fifo_tx_wr_full_s,
                            fifo_rx_rd_valid_s)
begin

    fifo_loopback_rd_wr_en_s <= '0';

    if (fifo_tx_wr_full_s = '0') then
        if (fifo_rx_rd_empty_s = '0' or fifo_rx_rd_valid_s = '1') then
            fifo_loopback_rd_wr_en_s <= '1';
        end if;
    end if;

end process fifo_loopback_ctrl;

ft601_clock_process: process(ft601_clk_i, ft601_be_rd_i,
                             ft601_data_rd_i, next_bus_state,
                             fifo_loopback_rd_wr_en_s, ft601_oe_n_s,
                             ft601_rd_n_s, fifo_tx_rd_data_s,
                             fifo_rx_rd_valid_s,
                             ft601_wr_n_s_1, ft601_wr_n_s_2, fifo_rx_wr_en_s_reg)
begin

    ft601_siwu_n_o <= '1';

    if (rising_edge(ft601_clk_i)) then
        -- From the datasheet, it looks like signals are expected
        -- to change on the falling edge of the clock and reads
        -- are expected to occur on the rising edge.
        fifo_rx_wr_data_s <= ft601_be_rd_i & ft601_data_rd_i;
        fifo_rx_wr_en_s <= fifo_rx_wr_en_s_reg;

        ft601_oe_n_o <= ft601_oe_n_s;
        ft601_wr_n_s_2 <= ft601_wr_n_s_1;
        ft601_rd_n_o <= ft601_rd_n_s;
        ft601_wr_n_o <= ft601_wr_n_s_1;
        ft601_be_wr_o <= fifo_tx_rd_data_s(35 downto 32);
        ft601_data_wr_o <= fifo_tx_rd_data_s(31 downto 0);
    end if;

end process ft601_clock_process;

sys_clk_process: process(sys_clk, tlp_streamer_reset_s, fifo_loopback_rd_wr_en_s,
                         fifo_rx_rd_valid_s)
begin

    -- Only write data to the TX FIFO if the output data from the
    -- RX FIFO is valid
    fifo_tx_wr_en_s <= fifo_loopback_rd_wr_en_s and fifo_rx_rd_valid_s;

    if (tlp_streamer_reset_s = '1') then
        fifo_rx_rd_en_s <= '0';
        fifo_tx_wr_en_s <= '0';
    elsif (rising_edge(sys_clk)) then
        -- An additional buffer is needed for the FIFO wr_en signal
        -- so that it is in sync with the data. Without the extra register
        -- the wr_en signal would be asserted before the data was ready.
        fifo_rx_rd_en_s <= fifo_loopback_rd_wr_en_s;
    end if;

end process sys_clk_process;

fsm_state_process: process(ft601_clk_i, next_bus_state, tlp_streamer_reset_s)
begin

    if (tlp_streamer_reset_s = '1') then
        current_bus_state <= BUS_IDLE;
    elsif (rising_edge(ft601_clk_i)) then
        current_bus_state <= next_bus_state;
    end if;

end process fsm_state_process;

fsm_data_output_process: process(current_bus_state, ft601_rxf_n_i,
                                 fifo_tx_rd_valid_s)
begin

    -- Assume the FPGA is not taking control of the FT601 bus
    ft601_oe_n_s <= '1';
    ft601_rd_n_s <= '1';
    ft601_wr_n_s_1 <= '1';
    fifo_rx_wr_en_s_reg <= '0';
    fifo_tx_rd_en_s <= '0';
    ila_trigger_in_s <= not ft601_rxf_n_i;

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
            fifo_rx_wr_en_s_reg <= not ft601_rxf_n_i;
        when RX_COMPLETE =>
            ft601_oe_n_s <= '1';
            ft601_rd_n_s <= '1';
        when TX_START =>
            fifo_tx_rd_en_s <= '1';
            ft601_wr_n_s_1 <= not fifo_tx_rd_valid_s;
        when TX_WORD =>
            ft601_wr_n_s_1 <= not fifo_tx_rd_valid_s;
            fifo_tx_rd_en_s <= '1';
        when others =>
    end case;

end process fsm_data_output_process;

fsm_state_select_process: process(current_bus_state, ft601_txe_n_i, ft601_rxf_n_i,
                                  fifo_rx_wr_full_s, fifo_tx_rd_empty_s)
begin
    -- Assume the state does not change by default
    next_bus_state <= current_bus_state;

    case current_bus_state is
        when BUS_IDLE =>
            if (ft601_txe_n_i = '0') then
                next_bus_state <= TX_READY;
            elsif (ft601_rxf_n_i = '0') then
                next_bus_state <= RX_READY;
            end if;
        when RX_READY =>
            if (fifo_rx_wr_full_s = '0') then
                next_bus_state <= RX_START;
            end if;
        when RX_START =>
            next_bus_state <= RX_WORD_1;
        when RX_WORD_1 =>
            next_bus_state <= RX_WORD_1;
        when RX_WORD_2 =>
            if (ft601_rxf_n_i = '1') then
                next_bus_state <= RX_COMPLETE;
            end if;
        when RX_COMPLETE =>
            next_bus_state <= BUS_IDLE;
        when TX_READY =>
            if (fifo_tx_rd_empty_s = '0') then
                next_bus_state <= TX_START;
            end if;
        when TX_START =>
            next_bus_state <= TX_WORD;
        when TX_WORD =>
            if (ft601_txe_n_i = '1' or fifo_tx_rd_empty_s = '1') then
                next_bus_state <= TX_COMPLETE;
            end if;
        when TX_COMPLETE =>
            next_bus_state <= BUS_IDLE;
    end case;

end process fsm_state_select_process;

end architecture RTL;
