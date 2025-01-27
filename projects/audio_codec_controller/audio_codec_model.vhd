-------------------------------------------------------------------------------
-- File       : audio_codec_model.vhd
-- Author     : 7, Roope Akkanen  
-- Author     : 7, Marko Jalonen
-- Created    : 2023-03-08
-- Last update: 2023-03-21
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A state machine that reads the two channel serial input 
-- and outputs the channels in parrallel.
-------------------------------------------------------------------------------
-- Copyright (c) 2023 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-03-08  1.0      Marko Jalonen   Created
-- 2023-03-21  1.1      Marko Jalonen   Edited

-------------------------------------------------------------------------------

-- Include default library
library ieee;
use ieee.std_logic_1164.all;

-- Declare inputs and outputs
entity audio_codec_model is
    generic(
        data_width_g : integer  -- Specify output bitwidth
    );
    port(
        rst_n : in std_logic;        -- Asynchronous reset signal
        aud_data_in  : in std_logic; -- Audio data from audio_ctrl
        aud_bclk_in  : in std_logic; -- Data bitclock from audio_crtl
        aud_lrclk_in : in std_logic; -- Channel select from audio_crtl

        value_left_out  : out std_logic_vector(data_width_g - 1 downto 0); -- Parallel output left channel
        value_right_out : out std_logic_vector(data_width_g - 1 downto 0)  -- Parallel output right channel
    );
end entity audio_codec_model;

architecture rtl of audio_codec_model is
    type state_type_t is (wait_for_input, read_left, read_right); -- Enum states
    signal present_state_r : state_type_t;                        -- Register for present state
    signal next_state_r    : state_type_t;                        -- Register for next state
    signal left_buffer_r   : std_logic_vector(data_width_g - 1 downto 0); -- Serial input to parallel output buffer
    signal right_buffer_r  : std_logic_vector(data_width_g - 1 downto 0); -- Serial input to parallel output buffer
    
    begin
        -- Change present state to the next state
        -- Present state change is done on the high bitclock state
        comb_present_state : process (aud_bclk_in, rst_n, next_state_r)
            begin
                if rst_n = '0' then
                    present_state_r <= wait_for_input;
                elsif aud_bclk_in = '1' then
                    present_state_r <= next_state_r;
                end if;
        end process comb_present_state;

        -- Change the next state to a legal one according to lr and bitclock and present state
        -- Next state calculation is done on the low bitclock state 
        comb_next_state : process (aud_bclk_in, aud_lrclk_in, present_state_r, rst_n)
            begin
                if rst_n = '0' then
                    next_state_r <= wait_for_input;
                else
                    if aud_bclk_in = '0' then
                        if aud_lrclk_in = '1' then
                            next_state_r <= read_left;
                        elsif aud_lrclk_in = '0' and present_state_r = read_left then
                            next_state_r <= read_right;
                        end if;
                    end if;
                end if;
        end process comb_next_state;

        -- Due to using shift registers the compile warning of not being sensitive to the buffers
        -- is ignored as it would break the functionality; apparently...
        -- Data is read at high bitclock state and written in low state 
        comb_rw : process (aud_lrclk_in, aud_bclk_in, rst_n, present_state_r, aud_data_in)
            begin
                if rst_n = '0' then
                    left_buffer_r   <= (others => '0');
                    right_buffer_r  <= (others => '0');
                    value_left_out  <= (others => '0');
                    value_right_out <= (others => '0');

                elsif aud_bclk_in = '1' and present_state_r = read_left  and aud_lrclk_in = '1' then
                    left_buffer_r <= left_buffer_r(left_buffer_r'left - 1 downto 0) & aud_data_in;

                elsif aud_bclk_in = '1' and present_state_r = read_right and aud_lrclk_in = '0' then
                    right_buffer_r <= right_buffer_r(right_buffer_r'left - 1 downto 0) & aud_data_in;

                elsif aud_bclk_in = '0' and present_state_r = read_right and aud_lrclk_in = '1' then
                    value_left_out <= left_buffer_r;
                    value_right_out <= right_buffer_r;

                end if;
        end process comb_rw;

end architecture rtl;
