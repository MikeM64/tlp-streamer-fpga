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
         dispatch_o_arr : out dispatch_producer_r_array(NUM_OUTPUT_QUEUES-1 downto 0);
         dispatch_i_arr  : in dispatch_consumer_r_array(NUM_OUTPUT_QUEUES-1 downto 0));

end entity tlp_streamer_rx_dispatch;

architecture RTL of tlp_streamer_rx_dispatch is

--component ila_0 IS
--PORT (
--clk : IN STD_LOGIC;
--probe0 : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
--    probe1 : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
--    probe2 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--    probe3 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--    probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--    probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--    probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--    probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--    probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--    probe9 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe10 : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
--    probe11 : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
--    probe12 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--    probe13 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
--);
--END component ila_0;

type dispatch_state is (DISPATCH_IDLE, DISPATCH_AWAIT_HEADER, DISPATCH_READ_HEADER,
                        DISPATCH_WRITE_HEADER, DISPATCH_WRITE_PACKET, DISPATCH_COMPLETE);

signal current_dispatch_state_s, next_dispatch_state_s: dispatch_state;
signal dispatch_words_to_write, next_dispatch_words_to_write: integer range 0 to 65535;
signal dispatch_output_queue, next_dispatch_output_queue: integer range 0 to 255;

-- A two-cycle delay for output data is required in order to first parse the
-- packet header (which denotes the appropriate output queue) and then
-- to continue writing the data to the output queue after it has been clocked
signal dispatch_rd_en_s, dispatch_rd_empty_s, dispatch_rd_valid_s_1, dispatch_rd_valid_s_2, dispatch_wr_en_s: std_logic;
signal dispatch_data_s_1, dispatch_data_s_2: std_logic_vector(35 downto 0);

--signal ila_dispatch_state: std_logic_vector(5 downto 0);
--signal ila_words_to_write: std_logic_vector(15 downto 0);
--signal ila_dispatch_output_queue: std_logic_vector(7 downto 0);

begin

--comp_rx_dispatch_ila: ila_0
--port map (
--    clk => sys_clk_i,
--    probe0(12 downto 6) => (others => '0'),
--    probe0(5 downto 0) => ila_dispatch_state,
--    probe1 => (others => '0'),
--    probe2(31 downto 16) => (others => '0'),
--    probe2(15 downto 0) => ila_words_to_write,
--    probe3 => fifo_rd_data_i(31 downto 0),
--    probe4(0) => dispatch_wr_en_s,
--    probe5(0) => dispatch_rd_valid_s_2,
--    probe6(0) => fifo_rd_valid_i,
--    probe7(0) => '0',
--    probe8(0) => '0',
--    probe9 => (others => '0'),
--    probe10 => (others => '0'),
--    probe11(9 downto 8) => (others => '0'),
--    probe11(7 downto 0) => ila_dispatch_output_queue,
--    probe12 => dispatch_data_s_2(31 downto 0),
--    probe13(0) => '0');

dispatch_fsm_state_process: process(sys_clk_i, next_dispatch_state_s, sys_reset_i, dispatch_data_s_1,
                                    dispatch_rd_valid_s_1, dispatch_rd_empty_s, dispatch_wr_en_s,
                                    dispatch_data_s_2)
begin
    if (sys_reset_i = '1') then
        current_dispatch_state_s <= DISPATCH_IDLE;
        for i in 0 to NUM_OUTPUT_QUEUES-1 loop
            dispatch_o_arr(i).dispatch_wr_data <= (others => '0');
            dispatch_o_arr(i).dispatch_valid <= '0';
            dispatch_o_arr(i).dispatch_empty <= '1';
            dispatch_o_arr(i).dispatch_wr_en <= '0';
        end loop;
    elsif (rising_edge(sys_clk_i)) then
        current_dispatch_state_s <= next_dispatch_state_s;

--        ila_dispatch_state <= std_logic_vector(to_unsigned(dispatch_state'POS(next_dispatch_state_s), 6));
--        ila_dispatch_output_queue <= std_logic_vector(to_unsigned(next_dispatch_output_queue, 8));
--        ila_words_to_write <= std_logic_vector(to_unsigned(next_dispatch_words_to_write, 16));

        dispatch_output_queue <= next_dispatch_output_queue;
        dispatch_words_to_write <= next_dispatch_words_to_write;

        dispatch_rd_empty_s <= fifo_rd_empty_i;
        dispatch_rd_valid_s_1 <= fifo_rd_valid_i;
        dispatch_data_s_1 <= fifo_rd_data_i;

        dispatch_data_s_2 <= dispatch_data_s_1;
        dispatch_rd_valid_s_2 <= dispatch_rd_valid_s_1;

        fifo_rd_en_o <= dispatch_rd_en_s;

        for i in 0 to NUM_OUTPUT_QUEUES-1 loop
            if (i = next_dispatch_output_queue) then
                dispatch_o_arr(i).dispatch_wr_data <= dispatch_data_s_2;
                dispatch_o_arr(i).dispatch_valid <= dispatch_rd_valid_s_2;
                dispatch_o_arr(i).dispatch_empty <= dispatch_rd_empty_s;
                dispatch_o_arr(i).dispatch_wr_en <= dispatch_wr_en_s;
            else
                -- Only the selected output will receive valid data.
                -- All other outputs will receive placeholder data.
                dispatch_o_arr(i).dispatch_wr_data <= (others => '0');
                dispatch_o_arr(i).dispatch_valid <= '0';
                dispatch_o_arr(i).dispatch_empty <= '1';
                dispatch_o_arr(i).dispatch_wr_en <= '0';
            end if;
        end loop;
    end if;

end process dispatch_fsm_state_process;

dispatch_fsm_data_output_process: process(current_dispatch_state_s, dispatch_output_queue, dispatch_rd_valid_s_2,
                                          dispatch_data_s_2, dispatch_words_to_write)
begin
    dispatch_rd_en_s <= '0';
    dispatch_wr_en_s <= '0';
    next_dispatch_output_queue <= dispatch_output_queue;
    next_dispatch_words_to_write <= dispatch_words_to_write;

    case current_dispatch_state_s is
        when DISPATCH_IDLE =>
            next_dispatch_output_queue <= 0;
            next_dispatch_words_to_write <= 0;
        when DISPATCH_AWAIT_HEADER =>
            dispatch_rd_en_s <= '1';
            next_dispatch_words_to_write <= 0;
        when DISPATCH_READ_HEADER =>
            dispatch_rd_en_s <= '1';
            -- Write signal started one cycle before the header write to align
            -- when the data is available on the output queue
            dispatch_wr_en_s <= '1';
            -- tsh_msg_type
            next_dispatch_output_queue <= to_integer(unsigned(dispatch_data_s_2(7 downto 0)));
            -- tsh_msg_len - Stored in network order
            next_dispatch_words_to_write <= to_integer(unsigned(dispatch_data_s_2(23 downto 16) & dispatch_data_s_2(31 downto 24)));
        when DISPATCH_WRITE_HEADER =>
            -- Now that the header is available, it can be written-through to the
            -- output component
            dispatch_rd_en_s <= '1';
            dispatch_wr_en_s <= '1';
            next_dispatch_words_to_write <= dispatch_words_to_write - 1;
        when DISPATCH_WRITE_PACKET =>
            dispatch_rd_en_s <= '1';
            dispatch_wr_en_s <= dispatch_rd_valid_s_2;
            next_dispatch_words_to_write <= dispatch_words_to_write - 1;
        when DISPATCH_COMPLETE =>
            next_dispatch_words_to_write <= 0;
    end case;

end process dispatch_fsm_data_output_process;

dispatch_fsm_state_select_process: process(current_dispatch_state_s, dispatch_rd_empty_s, dispatch_words_to_write,
                                           dispatch_rd_valid_s_1)
begin

    -- Current state does not change by default
    next_dispatch_state_s <= current_dispatch_state_s;

    case current_dispatch_state_s is
        when DISPATCH_IDLE =>
            if (dispatch_rd_empty_s = '0') then
                next_dispatch_state_s <= DISPATCH_AWAIT_HEADER;
            end if;
        when DISPATCH_AWAIT_HEADER =>
            -- Wait for valid data to appear before continuing
            if (dispatch_rd_valid_s_1 = '1') then
                next_dispatch_state_s <= DISPATCH_READ_HEADER;
            end if;
        when DISPATCH_READ_HEADER =>
            next_dispatch_state_s <= DISPATCH_WRITE_HEADER;
        when DISPATCH_WRITE_HEADER =>
            next_dispatch_state_s <= DISPATCH_WRITE_PACKET;
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
