--
-- TLP Streamer - Host Packet RX Dispatch Module
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.tlp_streamer_records.all;

entity tlp_streamer_rx_dispatch is
    generic (NUM_OUTPUT_QUEUES : integer);
    port(
         sys_clk_i          : in std_logic;
         sys_reset_i        : in std_logic;
         -- Input FIFO to dispatch
         fifo_rd_en_o       : out std_logic;
         fifo_rd_empty_i    : in std_logic;
         fifo_rd_valid_i    : in std_logic;
         fifo_rd_data_i     : in std_logic_vector(35 downto 0);
         -- Output FIFOs to dispatch to
         rx_dispatch_queue_out : out dispatch_producer_r_array(NUM_OUTPUT_QUEUES-1 downto 0);
         rx_dispatch_queue_in  : in dispatch_consumer_r_array(NUM_OUTPUT_QUEUES-1 downto 0));

end entity tlp_streamer_rx_dispatch;

architecture RTL of tlp_streamer_rx_dispatch is

type dispatch_state is (DISPATCH_IDLE, DISPATCH_PARSE_HEADER_1, DISPATCH_PARSE_HEADER_2,
                        DISPATCH_WRITE_PACKET, DISPATCH_COMPLETE);

signal current_dispatch_state_s, next_dispatch_state_s: dispatch_state;
signal dispatch_words_to_write: integer range 0 to 65535;
signal dispatch_output_queue: integer range 0 to 255;

signal dispatch_rd_en_s, dispatch_rd_empty_s, dispatch_rd_valid_s, dispatch_wr_en_s: std_logic;
signal dispatch_data_s: std_logic_vector(35 downto 0);

begin

dispatch_fsm_state_process: process(sys_clk_i, next_dispatch_state_s, sys_reset_i, dispatch_data_s,
                                    dispatch_rd_valid_s, dispatch_rd_empty_s, dispatch_wr_en_s)
begin
    if (sys_reset_i = '1') then
        current_dispatch_state_s <= DISPATCH_IDLE;
        for i in 0 to NUM_OUTPUT_QUEUES-1 loop
            rx_dispatch_queue_out(i).dispatch_wr_data <= (others => '0');
            rx_dispatch_queue_out(i).dispatch_valid <= '0';
            rx_dispatch_queue_out(i).dispatch_empty <= '1';
            rx_dispatch_queue_out(i).dispatch_wr_en <= '0';
        end loop;
    elsif (rising_edge(sys_clk_i)) then
        current_dispatch_state_s <= next_dispatch_state_s;
        fifo_rd_en_o <= dispatch_rd_en_s;
        dispatch_rd_empty_s <= fifo_rd_empty_i;
        dispatch_rd_valid_s <= fifo_rd_valid_i;
        dispatch_data_s <= fifo_rd_data_i;

        rx_dispatch_queue_out(dispatch_output_queue).dispatch_wr_data <= dispatch_data_s;
        rx_dispatch_queue_out(dispatch_output_queue).dispatch_valid <= dispatch_rd_valid_s;
        rx_dispatch_queue_out(dispatch_output_queue).dispatch_empty <= dispatch_rd_empty_s;
        rx_dispatch_queue_out(dispatch_output_queue).dispatch_wr_en <= dispatch_wr_en_s;

        case next_dispatch_state_s is
            when DISPATCH_IDLE =>
                dispatch_output_queue <= 0;
            when DISPATCH_PARSE_HEADER_1 =>
                dispatch_output_queue <= 0;
            when DISPATCH_PARSE_HEADER_2 =>
                if (dispatch_rd_valid_s = '1') then
                    -- tsh_msg_type
                    dispatch_output_queue <= to_integer(unsigned(dispatch_data_s(7 downto 0)));
                    -- tsh_msg_len
                    -- -1 as this first dword is already being written to the destination.
                    dispatch_words_to_write <= to_integer(unsigned(dispatch_data_s(31 downto 16))) - 1;
                end if;
            when DISPATCH_WRITE_PACKET =>
                dispatch_output_queue <= dispatch_output_queue;
                dispatch_words_to_write <= dispatch_words_to_write - 1;
            when DISPATCH_COMPLETE =>
                dispatch_output_queue <= 0;
        end case;
    end if;

end process dispatch_fsm_state_process;

dispatch_fsm_data_output_process: process(current_dispatch_state_s, dispatch_output_queue, dispatch_rd_valid_s)
begin
    dispatch_rd_en_s <= '0';
    dispatch_wr_en_s <= '0';

    case current_dispatch_state_s is
        when DISPATCH_IDLE =>
        when DISPATCH_PARSE_HEADER_1 =>
            -- Assert rd_en so the first word of the header
            -- is available for parsing in the next cycle
            dispatch_rd_en_s <= '1';
        when DISPATCH_PARSE_HEADER_2 =>
            -- Now that the header is available, it can be written-through to the
            -- output component
            dispatch_rd_en_s <= '1';
            dispatch_wr_en_s <= dispatch_rd_valid_s;
        when DISPATCH_WRITE_PACKET =>
            dispatch_rd_en_s <= '1';
            dispatch_wr_en_s <= dispatch_rd_valid_s;
        when DISPATCH_COMPLETE =>
    end case;

end process dispatch_fsm_data_output_process;

dispatch_fsm_state_select_process: process(current_dispatch_state_s, dispatch_rd_empty_s, dispatch_words_to_write,
                                           dispatch_rd_valid_s)
begin

    -- Current state does not change by default
    next_dispatch_state_s <= current_dispatch_state_s;

    case current_dispatch_state_s is
        when DISPATCH_IDLE =>
            if (dispatch_rd_empty_s = '0') then
                next_dispatch_state_s <= DISPATCH_PARSE_HEADER_1;
            end if;
        when DISPATCH_PARSE_HEADER_1 =>
            next_dispatch_state_s <= DISPATCH_PARSE_HEADER_2;
        when DISPATCH_PARSE_HEADER_2 =>
            -- Wait for valid data to appear before continuing
            if (dispatch_rd_valid_s = '1') then
                next_dispatch_state_s <= DISPATCH_WRITE_PACKET;
            end if;
        when DISPATCH_WRITE_PACKET =>
            -- Its possible that a received packet straddles two USB packets
            -- Trust the count in the packet for how many words to transfer
            if (dispatch_words_to_write = 0) then
                next_dispatch_state_s <= DISPATCH_COMPLETE;
            end if;
        when DISPATCH_COMPLETE =>
            next_dispatch_state_s <= DISPATCH_IDLE;
    end case;

end process dispatch_fsm_state_select_process;

end architecture RTL;
