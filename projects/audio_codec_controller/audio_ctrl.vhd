-------------------------------------------------------------------------------
-- File       : audio_ctrl.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Created    : 2023-03-08
-- Last update: 2023-03-21
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generates serial data from two channels of data. This serial
-- communication protocol requires multiple specific clocks.
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
entity audio_ctrl is
    generic(
        data_width_g   : integer;  -- Specify output bitwidth
        ref_clk_freq_g : integer;  -- Current clock freguency
        sample_rate_g  : integer   -- Rate of snapshots from parallel source
    );
    port(
        rst_n : in std_logic;        -- Asynchronous reset signal
        clk   : in std_logic;        -- Clock signal

        aud_data_out  : out std_logic; -- Audio data to codec
        aud_bclk_out  : out std_logic; -- Data bitclock to codec
        aud_lrclk_out : out std_logic; -- Channel select to codec

        left_data_in   : in std_logic_vector(data_width_g - 1 downto 0); -- Parallel input left channel
        right_data_in : in std_logic_vector(data_width_g - 1 downto 0)  -- Parallel input right channel
    );
end entity audio_ctrl;

architecture rtl of audio_ctrl is

    -- Input buffer signals
    signal input_buffer_r   : std_logic_vector(data_width_g * 2 - 1 downto 0); -- Parallel inputs to serial output buffer

    -- Clock counters for bit clock and left right clock
    -- Calculated from given reference clock
    constant bclk_counter_c   : integer := ref_clk_freq_g / ( sample_rate_g * data_width_g * 2 ) / 2; 
    signal bclk_counter_r     : integer range 0 to bclk_counter_c - 1;
    signal bclk_old_r         : std_logic;

    constant lrclk_counter_c  : integer := 32; -- Flip output after 16 bitclock cycles
    signal lrclk_counter_r    : integer range 0 to lrclk_counter_c - 1;
    signal lrclk_old_r        : std_logic;

    signal write_flag_r    : std_logic;
    signal read_flag_r     : std_logic;

    begin -- architecture rtl

        -- Count bclk counter up to calculated number and flip the clock register
        sync_clocks : process (clk, rst_n)
            begin
            if rst_n = '0' then
                -- Reset bit and left right clock registers
                bclk_counter_r <= 0;
                aud_bclk_out <= '0';
                bclk_old_r <= '1';

                lrclk_counter_r <= 30;
                aud_lrclk_out <= '0';
                lrclk_old_r <= '1';

                -- Reset r/w registers
                input_buffer_r <= (others => '0');
                write_flag_r <= '0';
                read_flag_r <= '1'; -- Offset to not collide with write
                aud_data_out <= '0';

            else
                if clk'event and clk = '1' then
                    
                    -- Once before starting left right cycle if the bitclock counter is at 1: read inputs to buffer
                    if lrclk_counter_r = 31 then
                        if read_flag_r = '1' and bclk_counter_r = 1 then
                            input_buffer_r <= left_data_in & right_data_in;
                            read_flag_r <= '0';
                        elsif read_flag_r = '0' and bclk_counter_r = 1 then
                            read_flag_r <= '1';
                        end if;
                    end if;

                    -- Bclock counter is full reset it and flip output
                    if bclk_counter_r = bclk_counter_c - 1 then
                        -- Flip bitclock
                        aud_bclk_out <= bclk_old_r;
                        bclk_old_r <= not bclk_old_r;
                        bclk_counter_r <= 0;

                        -- Each time bitclock flips add one to lrclk counter (1/32) or reset and flip output
                        if lrclk_counter_r = lrclk_counter_c - 1 then
                            aud_lrclk_out <= lrclk_old_r;
                            lrclk_old_r <= not lrclk_old_r;
                            lrclk_counter_r <= 0;
                        else
                            lrclk_counter_r <= lrclk_counter_r + 1;
                        end if;

                        -- Each time bitclock flips add one to write counter (1/2) or reset and write output
                        if write_flag_r = '1' then

                            -- Output MSB and shift input buffer
                            aud_data_out <= input_buffer_r(input_buffer_r'left);
                            input_buffer_r <= input_buffer_r(input_buffer_r'left - 1 downto 0) & '0'; 

                            write_flag_r <= '0';
                        else
                            write_flag_r <= '1';
                        end if;

                    else 
                        bclk_counter_r <= bclk_counter_r + 1;
                    end if;
                end if;
            end if;
        end process sync_clocks;

end architecture rtl;