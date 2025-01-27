-------------------------------------------------------------------------------
-- File       : i2c_config.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Created    : 2023-04-16
-- Last update: 2023-05-06
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: i2c master for configuring the slave audio codec chip
-------------------------------------------------------------------------------
-- Copyright (c) 2023 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-04-16  1.0      Marko Jalonen   Created
-- 2023-04-23  1.1      Marko Jalonen   Completed
-- 2023-05-05  1.2      Marko Jalonen   Changed due to customer feedback
-- 2023-05-06  1.3      Marko Jalonen   Implemented Stop-Start
-------------------------------------------------------------------------------

-- Include default library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- Declare inputs and outputs
entity i2c_config is
    generic(
        ref_clk_freq_g      : integer; -- Global clock freq
        i2c_freq_g          : integer; -- Clock for i2c freq
        n_params_g          : integer; -- Number of parameters to write
        n_leds_g            : integer  -- Number of leds to display the written parameters
    );
    port(
        clk                 : in    std_logic; -- Global clock
        rst_n               : in    std_logic; -- Async reset

        -- Binary representation of written param
        param_status_out    : out   std_logic_vector (n_leds_g-1 downto 0); 
        sclk_out            : out   std_logic;        -- i2c clock output
        finished_out        : out   std_logic;        -- Configuration done flag

        sdat_inout          : inout std_logic         -- i2c data output
    );
end entity i2c_config;

architecture rtl of i2c_config is
    

    -- Counter and treshdold for i2c clock divider
    constant    scl_max_c           : integer := 4;
    signal      scl_counter_r       : integer range 0 to scl_max_c;
    signal      scl_old_r           : std_logic;

    -- Counter and treshdold for internal logic clock divider
    constant    quart_max_c         : integer := ref_clk_freq_g / ( i2c_freq_g * 4) / 2;
    constant    scl_quart_max_c     : integer := 2 * ( ref_clk_freq_g / ( i2c_freq_g * 4) / 2 );
    signal      quart_counter_r     : integer range 0 to quart_max_c;
    signal      quart_clk           : std_logic;
    signal      scl_quart_counter_r : integer range 0 to scl_quart_max_c;
 
    -- Counter and treshdold for written data bit counter
    constant    bit_max_c           : integer := 8;
    signal      bit_counter_r       : integer range 0 to bit_max_c; 

    -- State machine status type and register
    type state_type_t is (start, write, ack, stop, stop_start, finish);
    signal current_state_r : state_type_t;

    -- State logic counter
    signal state_counter_r : integer range 0 to 20;

    -- Data output byte selection and counter for written parameters
    type byte_type_t is (device_byte, register_byte, value_byte);
    signal      current_byte_r          : byte_type_t;
    signal      written_conf_param_r    : integer range 0 to n_params_g;
    
    -- Constant slave device address
    constant    dev_byte_c : std_logic_vector := "00110100";

    -- Configuration parameters and addresses in a 2D matrix 
    type conf_param_t is array (0 to n_params_g - 1, 0 to 1) of std_logic_vector (7 downto 0);
    constant conf_param_c : conf_param_t :=   (
                                            ( "00011101", "10000000" ), -- cif_ctrl
                                            ( "00100111", "00000100" ), -- pll_ctrl
                                            ( "00100010", "00001011" ), -- sr
                                            ( "00101000", "00000000" ), -- dai_clk_mode
                                            ( "00101001", "10000001" ), -- dai_ctrl
                                            ( "01101001", "00001000" ), -- dac_l_ctrl
                                            ( "01101010", "00000000" ), -- dac_r_ctrl
                                            ( "01000111", "11100001" ), -- cp_ctrl
                                            ( "01101011", "00001001" ), -- hp_l_ctrl
                                            ( "01101100", "00001000" ), -- hp_r_ctrl
                                            ( "01001011", "00001000" ), -- mixout_l_select
                                            ( "01001100", "00001000" ), -- mixout_r_select
                                            ( "01101110", "10001000" ), -- mixout_l_ctrl
                                            ( "01101111", "10001000" ), -- mixout_r_ctrl
                                            ( "01010001", "11110001" )  -- system_modes_output
                                            );

    begin

    sync_scl : process (rst_n, clk)
    begin
        if rst_n = '0' then
            scl_counter_r <= 0;
            sclk_out <= '1';
            scl_old_r <= '0';
            scl_quart_counter_r <= 0;
        else
            if clk'event and clk = '1' then
                if scl_quart_counter_r = scl_quart_max_c - 1 then
                    scl_quart_counter_r <= 0;
                    if current_state_r = stop_start and state_counter_r = 3 then
                        scl_counter_r <= 0;
                        scl_quart_counter_r <= 0;
                    else
                        if scl_counter_r = scl_max_c - 1 then
                            scl_counter_r <= 0;
                            sclk_out <= scl_old_r;
                            scl_old_r <= not scl_old_r;
                        elsif scl_counter_r = scl_max_c / 2 - 1 then
                            sclk_out <= scl_old_r;
                            scl_old_r <= not scl_old_r;
                            scl_counter_r <= scl_counter_r + 1;
                        else
                            scl_counter_r <= scl_counter_r + 1;
                        end if; -- if scl_counter_r
                    end if; -- stop_start
                else --
                    scl_quart_counter_r <= scl_quart_counter_r + 1;
                end if; -- if scl_quart_counter_r
            end if; -- if clk'event and clk = '1'

        end if; -- if rst_n = '0'
    end process sync_scl;

    sync_quart : process (rst_n, clk)
    begin
        if rst_n = '0' then
            quart_counter_r <= 0;   
            quart_clk <= '0';
        else
            if clk'event and clk = '1' then
                if quart_counter_r = quart_max_c - 1 then
                    quart_counter_r <= 0;
                    quart_clk <= not quart_clk;
                else
                    quart_counter_r <= quart_counter_r + 1;
                end if; -- scl_counter
            end if; -- if clk'event and clk = '1'

        end if; -- if rst_n = '0'
    end process sync_quart;

    sync_logic : process (rst_n, clk)
    begin
        if rst_n = '0' then
            param_status_out <= (others => '0');
            finished_out <= '0';
            sdat_inout <= '1';
            bit_counter_r <= 0;
            written_conf_param_r <= 0;
            current_state_r <= start;
            current_byte_r <= device_byte;
            state_counter_r <= 0;
            
        else
            if clk'event and clk = '1' then
                if scl_quart_counter_r  = scl_quart_max_c - 1 then

                    case current_state_r is
                    -------------------------------------
                    when start =>
                        if scl_counter_r = 0 then
                            sdat_inout <= '0';
                            current_state_r <= write;
                        end if; -- scl_counter_r
                    
                    -------------------------------------

                    -------------------------------------
                    when write =>
                        if scl_old_r = '1' and scl_counter_r = 2 then
                            if bit_counter_r = bit_max_c then 
                                if current_byte_r = device_byte then
                                    bit_counter_r <= 0;
                                    current_byte_r <= register_byte;
                                    -- after each byte listen for change state to ack
                                    current_state_r <= ack;
                                    sdat_inout <= 'Z';
                                    
                                elsif current_byte_r = register_byte then
                                    bit_counter_r <= 0;
                                    current_byte_r <= value_byte;
                                    -- after each byte listen for change state to ack
                                    current_state_r <= ack;
                                    sdat_inout <= 'Z';

                                else
                                    bit_counter_r <= 0;
                                    current_byte_r <= device_byte;
                                    -- after each byte listen for change state to ack
                                    current_state_r <= ack;
                                    sdat_inout <= 'Z';

                                    -- increment the amount of written parameters
                                    written_conf_param_r <= written_conf_param_r + 1;
                                end if; -- current_byte_r

                            else
                                if current_byte_r = device_byte then
                                    -- write device byte
                                    sdat_inout <= dev_byte_c(bit_counter_r);  
                                elsif current_byte_r = register_byte then
                                    -- write register byte
                                    sdat_inout <= conf_param_c(written_conf_param_r, 0)(7 - bit_counter_r);
                                elsif current_byte_r = value_byte then
                                    -- write value byte
                                    sdat_inout <= conf_param_c(written_conf_param_r, 1)(7 - bit_counter_r);
                                end if; -- current byte

                                -- increment bit counter
                                bit_counter_r <= bit_counter_r + 1;

                            end if; -- bit_counter
                        end if; -- scl_old_r
                        
                    -------------------------------------

                    -------------------------------------
                    when ack =>
                            if scl_counter_r = 1 and sdat_inout = '0' then
                                if current_byte_r = device_byte and bit_counter_r = 0 then
                                    current_state_r <= stop;
                                    
                                else
                                    current_state_r <= write;
                                end if; -- current_byte_r
                            -- if responce is NACK
                            elsif scl_counter_r = 1 and sdat_inout = '1' then
                                if written_conf_param_r /= 0 and current_byte_r = device_byte then
                                    written_conf_param_r <= written_conf_param_r - 1;
                                end if; -- written_conf_param_r
                                current_state_r <= stop_start;
                               
                                current_byte_r <= device_byte;
                            end if; -- scl_counter_r     

                            -- Update leds
                            param_status_out <= std_logic_vector(
                                        to_unsigned(written_conf_param_r, n_leds_g));      

                    -------------------------------------

                    -------------------------------------
                    when stop =>
                        state_counter_r <= state_counter_r + 1;

                        if state_counter_r = 0 then
                            sdat_inout <= '0';
                        elsif state_counter_r = 2 then
                            sdat_inout <= '1';
                        elsif state_counter_r = 5 then
                            -- if all parameters are written goto finish state
                            if written_conf_param_r = n_params_g then
                                current_state_r <= finish;
                                state_counter_r <= 0;
                            -- if parameters aren't all written but all bytes of a single write are done
                            elsif current_byte_r = device_byte and bit_counter_r = 0 then
                                current_state_r <= start;
                                state_counter_r <= 0;
                            end if; -- written_conf_param_r
                        elsif state_counter_r = 0 then
                            sdat_inout <= '0';
                        end if; -- state_counter_r

                    -------------------------------------

                    -------------------------------------
                    when stop_start =>
                        state_counter_r <= state_counter_r + 1;

                        if state_counter_r = 0 then
                            sdat_inout <= '0';
                        elsif state_counter_r = 2 then
                            sdat_inout <= '1';
                        elsif state_counter_r = 4 then
                            sdat_inout <= '0';
                            current_state_r <= write;
                            state_counter_r <= 0;
                        end if; -- state_counter_r

                    -------------------------------------

                    -------------------------------------
                    when finish =>
                        finished_out <= '1';

                    -------------------------------------

                    end case;
                end if;
            end if;

        end if; -- if rst_n = '0'
    end process sync_logic;

end architecture rtl;