-------------------------------------------------------------------------------
-- File       : synthesizer.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Created    : 2023-03-22
-- Last update: 2023-03-22
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A top level structural description of the synthesizer 
-- by connecting the sub-blocks together. The device is guided with four
-- push-buttons. Every button refers to a sound with a specific frequency.
-------------------------------------------------------------------------------
-- Copyright (c) 2023 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-03-22  1.0      Marko Jalonen   Created
-- 2023-03-22  1.1	Marko Jalonen	Complete
-------------------------------------------------------------------------------

-- Include default library
library ieee;
use ieee.std_logic_1164.all;

entity synthesizer is 
    generic (
        clk_freq_g     : integer := 12288000; -- Reference clock frequency
        sample_rate_g  : integer := 48000;    -- Sample frequency
        n_keys_g       : integer := 4;        -- Number of keys to control the system
        data_width_g   : integer := 16        -- Parrallel signal width
    );
    port (
        clk   : in std_logic;        -- Global clock signal
        rst_n : in std_logic;        -- Asynchronous reset signal
        keys_in : in std_logic_vector(n_keys_g - 1 downto 0); -- Key status
        aud_data_out  : out std_logic; -- Audio data from audio_ctrl
        aud_bclk_out  : out std_logic; -- Data bitclock from audio_crtl
        aud_lrclk_out : out std_logic  -- Channel select from audio_crtl
    );
end entity synthesizer;

architecture rtl of synthesizer is

component wave_gen 
    generic (
        width_g : integer;                  -- Specify counter_rbit-width
        step_g  : integer                   -- Specify step size
    );
    port (
        clk             : in  std_logic;    -- Clock signal
        rst_n           : in  std_logic;    -- Asynchronous reset signal
        sync_clear_n_in : in  std_logic;    -- Syncronous reset
        value_out       : out std_logic_vector(width_g-1 downto 0)  -- Output vector
    );
end component wave_gen;

component multi_port_adder 
    generic (
        operand_width_g   : integer;
        num_of_operands_g : integer
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        operands_in : in  std_logic_vector((operand_width_g*num_of_operands_g)-1 downto 0);
        sum_out     : out std_logic_vector(operand_width_g-1 downto 0)
    );
end component multi_port_adder;

component audio_ctrl 
    generic (
        data_width_g   : integer;  -- Specify output bitwidth
        ref_clk_freq_g : integer;  -- Current clock freguency
        sample_rate_g  : integer   -- Rate of snapshots from parallel source
    );
    port (
        rst_n : in std_logic;        -- Asynchronous reset signal
        clk   : in std_logic;        -- Clock signal
        aud_data_out  : out std_logic; -- Audio data to codec
        aud_bclk_out  : out std_logic; -- Data bitclock to codec
        aud_lrclk_out : out std_logic; -- Channel select to codec
        left_data_in  : in std_logic_vector(data_width_g - 1 downto 0); -- Parallel input left channel
        right_data_in : in std_logic_vector(data_width_g - 1 downto 0)  -- Parallel input right channel
    );
end component audio_ctrl;

    -- Signals from wave gen(s) to multi port adder in a array
    type vector_array_type is array(0 to n_keys_g - 1) of std_logic_vector(data_width_g - 1 downto 0);
    signal data_wg_mpa : vector_array_type;
    signal array_to_vector : std_logic_vector(data_width_g * n_keys_g - 1 downto 0);

    -- Signal from multiport to audio controller
    signal data_mpa_actrl : std_logic_vector(data_width_g - 1 downto 0);

begin -- rtl

    -- Convert whole array to std_logic_vector as direct mapping did not work
    array_to_vector <= data_wg_mpa(0) & data_wg_mpa(1) & data_wg_mpa(2) & data_wg_mpa(3);

    -- Generate through all wave generator instances according to given number of buttons
    -- Set the step value as two's power in increasing order
    g_wav_gen : for n in 0 to n_keys_g - 1 generate
        i_wav_n : wave_gen
            generic map (
                width_g => data_width_g,
                step_g  => 2 ** n
            )
            port map (
                clk => clk,
                rst_n => rst_n,
                sync_clear_n_in => keys_in(n),
                value_out => data_wg_mpa(n)
            );
    end generate g_wav_gen;

    -- In this test case number of component instances preceeding this one is assumed to be 4
    i_mul_4 : multi_port_adder
        generic map (
            operand_width_g => data_width_g,
            num_of_operands_g => n_keys_g
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            operands_in => array_to_vector, -- why not data_wg_mpa(n_keys_g - 1 downto 0)?,
            sum_out => data_mpa_actrl
        );

    i_aud_5 : audio_ctrl
        generic map (
            data_width_g   => data_width_g,
            ref_clk_freq_g => clk_freq_g,
            sample_rate_g  => sample_rate_g
        )
        port map (
            rst_n => rst_n,
            clk => clk,
            aud_data_out  => aud_data_out,
            aud_bclk_out  => aud_bclk_out,
            aud_lrclk_out => aud_lrclk_out,
            left_data_in  => data_mpa_actrl,
            right_data_in => data_mpa_actrl
        );

end architecture rtl;
