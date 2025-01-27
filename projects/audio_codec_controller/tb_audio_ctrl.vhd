-------------------------------------------------------------------------------
-- File       : tb_audio_ctrl.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Created    : 2023-03-08
-- Last update: 2023-03-21
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Connects two wave_gen to an audio_ctrl which is connected to
-- a audio_codec_model.
-- The testbench sets parameters, generates clocks and reset signals.
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

entity tb_audio_ctrl is 
    generic (
        -- Reference clock and sample frequency for audio controller 
        ref_clk_freq_g : integer := 12288000;
        sample_rate_g  : integer := 48000;

        -- Parrallel signal width
        data_width_g   : integer := 16;

        -- Wave generator 'resolution' parameters
        step_left_g    : integer := 2;
        step_right_g   : integer := 10
    );
end entity tb_audio_ctrl;

architecture structural of tb_audio_ctrl is

    component wave_gen
        generic (
            width_g : integer;                  -- Specify counter bit-width
            step_g  : integer                   -- Specify step size
            );                 
        port (
            clk             : in  std_logic;    -- Clock signal
            rst_n           : in  std_logic;    -- Asynchronous reset signal
            sync_clear_n_in : in  std_logic;    -- Syncronous reset
            value_out       : out std_logic_vector(data_width_g-1 downto 0) -- Output vector
            ); 
    end component;

    component audio_ctrl
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

            left_data_in  : in std_logic_vector(data_width_g - 1 downto 0); -- Parallel input left channel
            right_data_in : in std_logic_vector(data_width_g - 1 downto 0)  -- Parallel input right channel
        );
    end component;

    component audio_codec_model
        generic(
            data_width_g : integer  -- Specify output bitwidth
        );
        port(
            rst_n : in std_logic;        -- Asynchronous reset signal
            aud_data_in  : in std_logic; -- Audio data from audio_ctrl
            aud_bclk_in  : in std_logic; -- Data bitclock from audio_ctrl
            aud_lrclk_in : in std_logic; -- Channel select from audio_ctrl

            value_left_out  : out std_logic_vector(data_width_g - 1 downto 0); -- Parrallel output left channel
            value_right_out : out std_logic_vector(data_width_g - 1 downto 0)  -- Parrallel output right channel
        );
    end component;

    -- Internal signals
    signal rst_n, clk, sync_clear_n : std_logic := '0';
    signal bclk_actrl_codec, lrclk_actrl_codec, data_actrl_codec : std_logic;
    signal l_data_wg_actrl, r_data_wg_actrl : std_logic_vector(data_width_g - 1 downto 0);
    signal l_data_codec_tb, r_data_codec_tb : std_logic_vector(data_width_g - 1 downto 0);

        -- Set the clock period and total simulation length
    constant period_c         : time    := 50 ns;  -- 50 ns = 20 MHz
    constant sim_duration_c   : time    := 10 ms;

    -- Set the time when wave generators are cleared synchronously
    constant clear_delay_c    : integer := 74000;
    constant clear_duration_c : integer := 6000;

    signal endsim : std_logic := '0';          -- Signal for ending the simulation

begin

    clk   <= not clk after period_c/2;
    rst_n <= '1'     after period_c*4;

    -- Create synchronous clear signal
    sync_clear_n <= '1',
                  '0' after period_c*clear_delay_c,
                  '1' after period_c*(clear_delay_c+clear_duration_c);

    -- Stop the simulation
    endsim <= '1' after sim_duration_c;
    assert endsim = '0' report "Simulation done" severity failure;

    -- Left channel wave generator
    i_wav_0 : wave_gen
        generic map (
            width_g => data_width_g,
            step_g => step_left_g
        )
        port map (
            rst_n => rst_n,
            clk => clk,
            sync_clear_n_in => sync_clear_n,
            value_out => l_data_wg_actrl
        );

    -- Right channel wave generator    
    i_wav_1 : wave_gen
        generic map (
            width_g => data_width_g,
            step_g => step_right_g
        )
        port map (
            rst_n => rst_n,
            clk => clk,
            sync_clear_n_in => sync_clear_n,
            value_out => r_data_wg_actrl
        );

    -- Audio controller
    i_aud_2 : audio_ctrl
        generic map (
            data_width_g   => data_width_g,
            ref_clk_freq_g => ref_clk_freq_g,
            sample_rate_g  => sample_rate_g
        )
        port map (
            rst_n => rst_n,
            clk => clk,
            aud_data_out  => data_actrl_codec,
            aud_bclk_out  => bclk_actrl_codec,
            aud_lrclk_out => lrclk_actrl_codec,
            left_data_in  => l_data_wg_actrl,
            right_data_in => r_data_wg_actrl
        );
    
    -- Audio codec model
    i_aud_3 : audio_codec_model
        generic map (
            data_width_g => data_width_g
        )
        port map (
            rst_n => rst_n,
            aud_data_in  => data_actrl_codec,
            aud_bclk_in  => bclk_actrl_codec,
            aud_lrclk_in => lrclk_actrl_codec,
            value_left_out  => l_data_codec_tb,
            value_right_out => r_data_codec_tb
        );

end architecture structural;