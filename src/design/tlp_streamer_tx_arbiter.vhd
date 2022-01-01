--
-- TLP Streamer - FPGA Packet TX Arbiter
--
-- (c) MikeM64 - 2021
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.tlp_streamer_records.all;

entity tlp_streamer_tx_arbiter is
    generic (NUM_INPUT_QUEUES : integer);
    port (
        sys_clk_i   : in std_logic;
        sys_reset_i : in std_logic;
        -- Input FIFOs to arbitrate
        arbiter_o_arr : out arbiter_producer_r_array(NUM_INPUT_QUEUES-1 downto 0);
        arbiter_i_arr : in arbiter_consumer_r_array(NUM_INPUT_QUEUES-1 downto 0);
        -- Output FIFO to feed
        arbiter_output_wr_en_o : out std_logic;
        arbiter_output_wr_full_i : in std_logic;
        arbiter_output_wr_data_o : out std_logic_vector(35 downto 0));
end entity tlp_streamer_tx_arbiter;

architecture RTL of tlp_streamer_tx_arbiter is

type arbiter_state is (ARBITER_IDLE, ARBITER_AWAIT_HEADER, ARBITER_READ_HEADER,
                       ARBITER_WRITE_PACKET, ARBITER_COMPLETE_1, ARBITER_COMPLETE_2);

signal current_arbiter_state_s, next_arbiter_state_s: arbiter_state;
signal arbiter_words_to_write, next_arbiter_words_to_write: integer range 0 to 65535;
signal arbiter_input_queue, next_arbiter_input_queue: integer range 0 to NUM_INPUT_QUEUES;

signal arbiter_rd_en_s, arbiter_rd_valid_s_1, arbiter_rd_valid_s_2, arbiter_rd_empty_s,
        arbiter_wr_en_s : std_logic;
signal arbiter_rd_data_s_1, arbiter_rd_data_s_2, arbiter_rd_data_s_3 : std_logic_vector(35 downto 0);

begin

arbiter_fsm_state_process: process(sys_clk_i, sys_reset_i, next_arbiter_state_s,
                                   arbiter_rd_en_s, arbiter_output_wr_full_i,
                                   arbiter_wr_en_s, arbiter_rd_data_s_1,
                                   arbiter_i_arr, arbiter_rd_data_s_2,
                                   arbiter_words_to_write, arbiter_rd_valid_s_1,
                                   arbiter_rd_valid_s_2, next_arbiter_input_queue)
begin

    if (sys_reset_i = '1') then
        current_arbiter_state_s <= ARBITER_IDLE;
        arbiter_output_wr_en_o <= '0';
        arbiter_rd_data_s_1 <= (others => '0');
        arbiter_rd_data_s_2 <= (others => '0');
        arbiter_rd_valid_s_1 <= '0';
        arbiter_rd_valid_s_2 <= '0';
        arbiter_rd_empty_s <= '1';
        arbiter_input_queue <= NUM_INPUT_QUEUES;
        for i in 0 to NUM_INPUT_QUEUES-1 loop
            arbiter_o_arr(i).arbiter_rd_en <= '0';
            arbiter_o_arr(i).arbiter_wr_full <= '0';
        end loop;
    elsif (rising_edge(sys_clk_i)) then
        current_arbiter_state_s <= next_arbiter_state_s;

        for i in 0 to NUM_INPUT_QUEUES-1 loop
            if (i = next_arbiter_input_queue) then
                arbiter_rd_data_s_1 <= arbiter_i_arr(i).arbiter_rd_data;
                arbiter_rd_valid_s_1 <= arbiter_i_arr(i).arbiter_rd_valid;
                arbiter_rd_empty_s <= arbiter_i_arr(i).arbiter_rd_empty;
                arbiter_o_arr(i).arbiter_rd_en <= arbiter_rd_en_s;
                arbiter_o_arr(i).arbiter_wr_full <= arbiter_output_wr_full_i;
            -- There used to be an else statement here in order to set the
            -- signals for the unselected inputs to a known default but
            -- that seemed to optimize out some of the signals from the
            -- selected inputs.
            end if;
        end loop;

        arbiter_rd_data_s_2 <= arbiter_rd_data_s_1;
        arbiter_rd_valid_s_2 <= arbiter_rd_valid_s_1;

        arbiter_output_wr_data_o <= arbiter_rd_data_s_2;
        arbiter_rd_data_s_3 <= arbiter_rd_data_s_2;
        arbiter_output_wr_en_o <= arbiter_wr_en_s;

        arbiter_input_queue <= next_arbiter_input_queue;
        arbiter_words_to_write <= next_arbiter_words_to_write;
    end if;

end process arbiter_fsm_state_process;

arbiter_fsm_data_output_process: process(current_arbiter_state_s, arbiter_i_arr, arbiter_input_queue,
                                         arbiter_words_to_write, arbiter_rd_valid_s_2, arbiter_rd_data_s_3)
begin

    arbiter_rd_en_s <= '0';
    arbiter_wr_en_s <= '0';
    next_arbiter_input_queue <= arbiter_input_queue;
    next_arbiter_words_to_write <= arbiter_words_to_write;

    case current_arbiter_state_s is
        when ARBITER_IDLE =>
            for i in 0 to NUM_INPUT_QUEUES-1 loop
                if (arbiter_i_arr(i).arbiter_rd_empty = '0') then
                    next_arbiter_input_queue <= i;
                end if;
                exit when arbiter_i_arr(i).arbiter_rd_empty = '0';
            end loop;
            next_arbiter_words_to_write <= 0;
        when ARBITER_AWAIT_HEADER =>
            arbiter_rd_en_s <= '1';
            arbiter_wr_en_s <= arbiter_rd_valid_s_2;
            next_arbiter_words_to_write <= 0;
        when ARBITER_READ_HEADER =>
            arbiter_rd_en_s <= '1';
            arbiter_wr_en_s <= arbiter_rd_valid_s_2;
            next_arbiter_words_to_write <= to_integer(unsigned(arbiter_rd_data_s_3(31 downto 16))) - 1;
        when ARBITER_WRITE_PACKET =>
            if (arbiter_words_to_write > 3) then
                arbiter_rd_en_s <= '1';
            else
                arbiter_rd_en_s <= '0';
            end if;
            arbiter_wr_en_s <= arbiter_rd_valid_s_2;
            next_arbiter_words_to_write <= arbiter_words_to_write - 1;
        when ARBITER_COMPLETE_1 =>
            next_arbiter_words_to_write <= 0;
        when ARBITER_COMPLETE_2 =>
            -- A second complete state is used to allow for the rd_en
            -- signal to be de-asserted for the selected input before
            -- resetting the input queue for the next TX packet
            next_arbiter_input_queue <= NUM_INPUT_QUEUES;
            next_arbiter_words_to_write <= 0;
    end case;

end process arbiter_fsm_data_output_process;

arbiter_fsm_state_select_process: process(current_arbiter_state_s, arbiter_i_arr,
                                          arbiter_words_to_write, arbiter_rd_valid_s_2,
                                          arbiter_input_queue)
begin

    -- Current state does not change by default
    next_arbiter_state_s <= current_arbiter_state_s;

    case current_arbiter_state_s is
        when ARBITER_IDLE =>
            -- Once an input queue is available and there is space in the output queue
            -- move to ARBITER_INPUT_SELECTED
            if (arbiter_input_queue < NUM_INPUT_QUEUES) then
                next_arbiter_state_s <= ARBITER_AWAIT_HEADER;
            end if;
        when ARBITER_AWAIT_HEADER =>
            if (arbiter_rd_valid_s_2 = '1') then
                next_arbiter_state_s <= ARBITER_READ_HEADER;
            end if;
        when ARBITER_READ_HEADER =>
            next_arbiter_state_s <= ARBITER_WRITE_PACKET;
        when ARBITER_WRITE_PACKET =>
            if (arbiter_words_to_write = 0) then
                next_arbiter_state_s <= ARBITER_COMPLETE_1;
            end if;
        when ARBITER_COMPLETE_1 =>
            next_arbiter_state_s <= ARBITER_COMPLETE_2;
        when ARBITER_COMPLETE_2 =>
            next_arbiter_state_s <= ARBITER_IDLE;
    end case;

end process arbiter_fsm_state_select_process;

end architecture RTL;
