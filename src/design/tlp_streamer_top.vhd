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
        ft601_txe_n_i   : in    std_logic;
        ft601_wr_n_o    : out    std_logic;
        usr_rst_n_i     : in    std_logic);
end entity tlp_streamer;

architecture RTL of tlp_streamer is

signal ctrl_rx_enable, ctrl_tx_enable: std_logic;
signal ctrl_rx_in_progress, ctrl_tx_in_progress: std_logic;

type rx_usb_state is (RX_IDLE, RX_READY, RX_START, RX_WORD);
signal current_rx_state, next_rx_state: rx_usb_state;

signal ft601_be_rd_i: std_logic_vector(3 downto 0);
signal ft601_data_rd_i: std_logic_vector(31 downto 0);

signal ft601_be_wr_o: std_logic_vector(3 downto 0);
signal ft601_data_wr_o: std_logic_vector(31 downto 0);

signal ft601_bus_wr_s: std_logic;
signal ft601_oe_n_s: std_logic;
signal ft601_rd_n_s: std_logic;
signal ft601_wr_n_s: std_logic;

signal usr_rst_s: std_logic;
signal fifo_rx_wr_data_s: std_logic_vector(35 downto 0);
signal fifo_rx_tx_loopback_data_s: std_logic_vector(35 downto 0);
signal fifo_rx_rd_en_s: std_logic;
signal fifo_rx_wr_en_s: std_logic;
signal fifo_rx_wr_en_reg_s: std_logic;
signal fifo_rx_wr_full_s: std_logic;
signal fifo_rx_rd_empty_s: std_logic;
signal fifo_rx_rd_valid_s: std_logic;

type tx_usb_state is (TX_IDLE, TX_START, TX_WORD);
signal current_tx_state, next_tx_state: tx_usb_state;

signal fifo_tx_rd_data_s: std_logic_vector(35 downto 0);
signal fifo_tx_wr_en_s: std_logic;
signal fifo_tx_rd_en_s: std_logic;
signal fifo_tx_rd_en_reg_s: std_logic;
signal fifo_tx_wr_full_s: std_logic;
signal fifo_tx_rd_empty_s: std_logic;
signal fifo_tx_rd_valid_s: std_logic;

signal fifo_loopback_rd_wr_en_s: std_logic;

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

begin

rx_usb_fifo: fifo_36_36_prim
    port map (
        rst => usr_rst_s,
        wr_clk => ft601_clk_i,
        rd_clk => ft601_clk_i,
        din => fifo_rx_wr_data_s,
        wr_en => fifo_rx_wr_en_s,
        rd_en => fifo_rx_rd_en_s,
        dout => fifo_rx_tx_loopback_data_s,
        full => fifo_rx_wr_full_s,
        empty => fifo_rx_rd_empty_s,
        valid => fifo_rx_rd_valid_s);

tx_usb_fifo: fifo_36_36_prim
    port map (
        rst => usr_rst_s,
        wr_clk => ft601_clk_i,
        rd_clk => ft601_clk_i,
        din => fifo_rx_tx_loopback_data_s,
        wr_en => fifo_tx_wr_en_s,
        rd_en => fifo_tx_rd_en_s,
        dout => fifo_tx_rd_data_s,
        full => fifo_tx_wr_full_s,
        empty => fifo_tx_rd_empty_s,
        valid => fifo_tx_rd_valid_s);

clock_process: process(ft601_clk_i, usr_rst_n_i, ft601_be_rd_i,
                       ft601_data_rd_i, next_rx_state, next_tx_state,
                       fifo_rx_wr_en_reg_s, fifo_tx_rd_en_reg_s,
                       fifo_loopback_rd_wr_en_s, ft601_oe_n_s,
                       ft601_rd_n_s, ft601_wr_n_s, fifo_tx_rd_data_s,
                       fifo_rx_rd_valid_s)
begin

    usr_rst_s <= '0';
    -- Only write data to the TX FIFO if the output data from the
    -- RX FIFO is valid
    fifo_tx_wr_en_s <= fifo_loopback_rd_wr_en_s and fifo_rx_rd_valid_s;

    ft601_rst_n_o <= usr_rst_n_i;
    if (usr_rst_n_i = '0') then
        current_rx_state <= RX_IDLE;
        usr_rst_s <= '1';
        fifo_rx_wr_en_s <= '0';
        fifo_rx_rd_en_s <= '0';
        fifo_tx_wr_en_s <= '0';
        fifo_tx_rd_en_s <= '0';
    elsif (ft601_clk_i'EVENT and ft601_clk_i = '1') then
        -- From the datasheet, it looks like signals are expected
        -- to change on the falling edge of the clock and reads
        -- are expected to occur on the rising edge.
        current_rx_state <= next_rx_state;
        current_tx_state <= next_tx_state;
        fifo_rx_wr_data_s <= ft601_be_rd_i & ft601_data_rd_i;
        -- An additional buffer is needed for the FIFO wr_en signal
        -- so that it is in sync with the data. Without the extra register
        -- the wr_en signal would be asserted before the data was ready.
        fifo_rx_wr_en_s <= fifo_rx_wr_en_reg_s;
        fifo_rx_rd_en_s <= fifo_loopback_rd_wr_en_s;
        fifo_tx_rd_en_s <= fifo_tx_rd_en_reg_s;
    end if;

    if (ft601_clk_i'EVENT and ft601_clk_i = '0') then
        ft601_oe_n_o <= ft601_oe_n_s;
        ft601_rd_n_o <= ft601_rd_n_s;
        ft601_wr_n_o <= ft601_wr_n_s;
        ft601_be_wr_o <= fifo_tx_rd_data_s(35 downto 32);
        ft601_data_wr_o <= fifo_tx_rd_data_s(31 downto 0);
    end if;

end process clock_process;

bus_read_write: process(ft601_wr_n_s, ft601_be_io, ft601_data_io,
                        ft601_be_wr_o, ft601_data_wr_o)
begin

    if (ft601_wr_n_s = '1') then
        ft601_be_io <= "ZZZZ";
        ft601_data_io <= "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";
    else
        ft601_be_io <= ft601_be_wr_o;
        ft601_data_io <= ft601_data_wr_o;
    end if;
    ft601_be_rd_i <= ft601_be_io;
    ft601_data_rd_i <= ft601_data_io;

end process bus_read_write;

tx_rx_ctrl: process(ft601_rxf_n_i, ft601_txe_n_i, fifo_rx_wr_full_s,
                    fifo_tx_rd_empty_s, ctrl_rx_in_progress,
                    ctrl_tx_in_progress)
begin

    -- Let in-flight transactions finish before starting a new one
    ctrl_rx_enable <= ctrl_rx_in_progress;
    ctrl_tx_enable <= ctrl_tx_in_progress;

    -- Always attempt to drain the TX buffer before receiving more data
    if (ctrl_rx_in_progress = '0' and ft601_txe_n_i = '0' and fifo_tx_rd_empty_s = '0') then
        ctrl_tx_enable <= '1';
    elsif (ctrl_tx_in_progress = '0' and ft601_rxf_n_i = '0' and fifo_rx_wr_full_s = '0') then
        ctrl_rx_enable <= '1';
    end if;

end process tx_rx_ctrl;

fifo_loopback_ctrl: process(ft601_clk_i, fifo_rx_rd_empty_s, fifo_tx_wr_full_s,
                            fifo_rx_rd_valid_s)
begin

    fifo_loopback_rd_wr_en_s <= '0';

    if (fifo_tx_wr_full_s = '0') then
        if (fifo_rx_rd_empty_s = '0' or fifo_rx_rd_valid_s = '1') then
            fifo_loopback_rd_wr_en_s <= '1';
        end if;
    end if;

end process fifo_loopback_ctrl;

rx_process: process(ft601_rxf_n_i, fifo_rx_wr_full_s, ft601_be_rd_i,
                    current_rx_state, ft601_rd_n_s, ctrl_rx_enable)
begin

    -- Assume the state does not change by default
    next_rx_state <= current_rx_state;

    -- Assume the FPGA is not taking control of the FT601 bus
    ft601_oe_n_s <= '1';
    ft601_rd_n_s <= '1';
    fifo_rx_wr_en_reg_s <= '0';
    ft601_bus_wr_s <= '0';
    ctrl_rx_in_progress <= '0';

    if (ctrl_rx_enable = '1') then
        case current_rx_state is
            when RX_IDLE =>
                if (ft601_rxf_n_i = '0') then
                    next_rx_state <= RX_READY;
                end if;
            when RX_READY =>
                ctrl_rx_in_progress <= '1';
                if (fifo_rx_wr_full_s = '0') then
                    next_rx_state <= RX_START;
                end if;
            when RX_START =>
                ctrl_rx_in_progress <= '1';
                ft601_oe_n_s <= '0';
                next_rx_state <= RX_WORD;
            when RX_WORD =>
                ctrl_rx_in_progress <= '1';
                ft601_oe_n_s <= '0';
                ft601_rd_n_s <= '0';
                -- FIFO wr_en is tied to rxf_n as otherwise it will
                -- still be asserted after the data is no longer valid
                -- if the FPGA waits for the FSM state change
                fifo_rx_wr_en_reg_s <= not ft601_rxf_n_i;

                if (ft601_be_rd_i < "1111" or ft601_rxf_n_i = '1' or fifo_rx_wr_full_s = '1') then
                    next_rx_state <= RX_IDLE;
                end if;
        end case;
    end if;

end process rx_process;

tx_process: process(ft601_txe_n_i, fifo_tx_rd_empty_s, current_tx_state,
                    ctrl_tx_enable, fifo_tx_rd_valid_s)
begin

    -- Assume the state does not change by default
    next_tx_state <= current_tx_state;

    ctrl_tx_in_progress <= '0';
    ft601_wr_n_s <= '1';
    fifo_tx_rd_en_reg_s <= '0';

    if (ctrl_tx_enable = '1') then
        case current_tx_state is
            when TX_IDLE =>
                if (ft601_txe_n_i = '0' and fifo_tx_rd_empty_s = '0') then
                    next_tx_state <= TX_START;
                end if;
            when TX_START =>
                ctrl_tx_in_progress <= '1';
                next_tx_state <= TX_WORD;
            when TX_WORD =>
                ctrl_tx_in_progress <= '1';
                -- Only transmit valid words to the FT601
                ft601_wr_n_s <= not fifo_tx_rd_valid_s;
                fifo_tx_rd_en_reg_s <= '1';
                if (ft601_txe_n_i = '1' or fifo_tx_rd_empty_s = '1') then
                    next_tx_state <= TX_IDLE;
                end if;
        end case;
    end if;

end process tx_process;

end architecture RTL;
