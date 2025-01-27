-------------------------------------------------------------------------------
-- File       : tb_i2c_config.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Created    : 2023-04-16
-- Last update: 2023-05-06
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: test bench for a i2c master configuring the slave audio codec chip
-------------------------------------------------------------------------------
-- Copyright (c) 2023 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-04-16  1.0      Marko Jalonen   Created
-- 2023-04-23  1.1      Marko Jalonen   Completed
-- 2023-05-05  1.2      Marko Jalonen   Changed due to customer feedback
-- 2023-05-06  1.3      Marko Jalonen   Implemented Stop-Start
-- 2023-05-13  1.4      Marko Jalonen   Enabled and imporved bit error handling and random nack
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------
-- Empty entity
-------------------------------------------------------------------------------

entity tb_i2c_config is
end tb_i2c_config;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture testbench of tb_i2c_config is

  -- Number of parameters to expect
  constant n_params_c     : integer := 15;
  constant n_leds_c : integer := 4;
  constant i2c_freq_c     : integer := 20000;
  constant ref_freq_c     : integer := 50000000;
  constant clock_period_c : time    := 20 ns;

  -- Every transmission consists several bytes and every byte contains given
  -- amount of bits. 
  constant n_bytes_c       : integer := 3;
  constant bit_count_max_c : integer := 8;

  -- Signals fed to the DUV
  signal clk   : std_logic := '0';  -- Remember that default values supported
  signal rst_n : std_logic := '0';      -- only in synthesis

  -- The DUV prototype
  component i2c_config
    generic (
      ref_clk_freq_g : integer;
      i2c_freq_g     : integer;
      n_params_g     : integer;
	  n_leds_g : integer);
    port (
      clk              : in    std_logic;
      rst_n            : in    std_logic;
      sdat_inout       : inout std_logic;
      sclk_out         : out   std_logic;
      param_status_out : out   std_logic_vector(n_leds_g-1 downto 0);
      finished_out     : out   std_logic
      );
  end component;

  -- Signals coming from the DUV
  signal sdat         : std_logic := 'Z';
  signal sclk         : std_logic;
  signal param_status : std_logic_vector(n_leds_c-1 downto 0);
  signal finished     : std_logic;

  -- To hold the value that will be driven to sdat when sclk is high.
  signal sdat_r : std_logic;

  -- Counters for receiving bits and bytes
  signal bit_counter_r        : integer range 0 to bit_count_max_c-1;
  signal byte_counter_r       : integer range 0 to n_bytes_c-1;
  signal written_conf_param_r : integer range 0 to n_params_c;

  -- Transmission error status
  signal bit_error_r  : std_logic := '0';
  signal nack_given_r : std_logic := '0';
  signal early_finish_r : std_logic := '0';
  signal block_random_nack_error_report_r : std_logic := '0';

  -- Matrix to compare the received bytes
  type conf_param_t is array (0 to n_params_c - 1, 0 to 2) of std_logic_vector (7 downto 0);
  constant conf_param_c : conf_param_t := (
                                          ("00110100", "00011101", "10000000" ), -- cif_ctrl
                                          ("00110100", "00100111", "00000100" ), -- pll_ctrl
                                          ("00110100", "00100010", "00001011" ), -- sr
                                          ("00110100", "00101000", "00000000" ), -- dai_clk_mode
                                          ("00110100", "00101001", "10000001" ), -- dai_ctrl
                                          ("00110100", "01101001", "00001000" ), -- dac_l_ctrl
                                          ("00110100", "01101010", "00000000" ), -- dac_r_ctrl
                                          ("00110100", "01000111", "11100001" ), -- cp_ctrl
                                          ("00110100", "01101011", "00001001" ), -- hp_l_ctrl
                                          ("00110100", "01101100", "00001000" ), -- hp_r_ctrl
                                          ("00110100", "01001011", "00001000" ), -- mixout_l_select
                                          ("00110100", "01001100", "00001000" ), -- mixout_r_select
                                          ("00110100", "01101110", "10001000" ), -- mixout_l_ctrl
                                          ("00110100", "01101111", "10001000" ), -- mixout_r_ctrl
                                          ("00110100", "01010001", "11110001" )  -- system_modes_output
                                          );
  -- Matrix to store the received bytes
  signal conf_param_g : conf_param_t := (
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- cif_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- pll_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- sr
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- dai_clk_mode
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- dai_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- dac_l_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- dac_r_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- cp_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- hp_l_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- hp_r_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- mixout_l_select
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- mixout_r_select
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- mixout_l_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" ), -- mixout_r_ctrl
                                        ("XXXXXXXX", "XXXXXXXX", "XXXXXXXX" )  -- system_modes_output
                                        );

  -- States for the FSM
  type   states is (wait_start, read_byte, send_ack, wait_stop);
  signal curr_state_r : states;

  -- Previous values of the I2C signals for edge detection
  signal sdat_old_r : std_logic;
  signal sclk_old_r : std_logic;
  
begin  -- testbench

  clk   <= not clk after clock_period_c/2;
  rst_n <= '1'     after clock_period_c*4;

  -- Assign sdat_r when sclk is active, otherwise 'Z'.
  -- Note that sdat_r is usually 'Z'
  with sclk select
    sdat <=
    sdat_r when '1',
    'Z'    when others;


  -- Component instantiation
  i2c_config_1 : i2c_config
    generic map (
      ref_clk_freq_g => ref_freq_c,
      i2c_freq_g     => i2c_freq_c,
      n_params_g     => n_params_c,
	    n_leds_g => n_leds_c)
    port map (
      clk              => clk,
      rst_n            => rst_n,
      sdat_inout       => sdat,
      sclk_out         => sclk,
      param_status_out => param_status,
      finished_out     => finished);

  -----------------------------------------------------------------------------
  -- The main process that controls the behavior of the test bench
  fsm_proc : process (clk, rst_n)
  begin  -- process fsm_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)

      curr_state_r <= wait_start;

      sdat_old_r <= '0';
      sclk_old_r <= '0';

      byte_counter_r <= 0;
      bit_counter_r  <= 0;
      written_conf_param_r <= 0;

      sdat_r <= 'Z';

      nack_given_r <= '0';  
      bit_error_r <= '0';
      early_finish_r <= '0';
      
    elsif clk'event and clk = '1' then  -- rising clock edge

      -- The previous values are required for the edge detection
      sclk_old_r <= sclk;
      sdat_old_r <= sdat;


      -- Falling edge detection for acknowledge control
      -- Must be done on the falling edge in order to be stable during
      -- the high period of sclk
      if sclk = '0' and sclk_old_r = '1' then

        -- If we are supposed to send ack
        if curr_state_r = send_ack then

          -- Send ack (low = ACK, high = NACK)
          if bit_error_r = '1' then
            sdat_r <= '1';
          else 
            sdat_r <= '0';
          end if; -- bit_error_r
        else

          -- Otherwise, sdat is in high impedance state.
          sdat_r <= 'Z';
          
        end if;
        
      end if;

      -------------------------------------------------------------------------
      -------------------------------------------------------------------------
      -- FSM
      case curr_state_r is

        -----------------------------------------------------------------------
        -- Wait for the start condition
        when wait_start =>

          -- While clk stays high, the sdat falls
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '1' and sdat = '0' then

            curr_state_r <= read_byte;

          end if;

          assert not (sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '0' and sdat = '1')
            report "Received stop while waiting for start" severity error;

          -- End of simulation, but all parameters aren't received
          if finished = '1' then
            if written_conf_param_r /= 15 and rst_n /= '0' then
              early_finish_r <= '1';
            end if; -- written_conf_param_r
          end if; -- finished

          --------------------------------------------------------------------
          -- Wait for a byte to be read
        when read_byte =>

          -- Detect a rising edge
          if sclk = '1' and sclk_old_r = '0' then

            -- Store the bit
            conf_param_g(written_conf_param_r, byte_counter_r)(7 - bit_counter_r) <= sdat;

            -- Check for correct bit
            if sdat /= conf_param_c(written_conf_param_r, byte_counter_r)(7 - bit_counter_r) then
              bit_error_r <= '1';
            end if; -- sdat

            -- Give a NACK
            if nack_given_r = '0' then
              if written_conf_param_r = 4 and byte_counter_r = 1 and bit_counter_r = 3 then
                nack_given_r <= '1';
                bit_error_r <= '1';
              end if; -- written_conf_param_r
            end if; -- nack_given_r

            if bit_counter_r /= bit_count_max_c-1 then

              -- Normally just receive a bit
              bit_counter_r <= bit_counter_r + 1;

            else
              -- When terminal count is reached, let's send the ack
              
              curr_state_r  <= send_ack;
              bit_counter_r <= 0;
              
            end if;  -- Bit counter terminal count
            
          end if;  -- sclk rising clock edge

          --------------------------------------------------------------------
          -- Send acknowledge
        when send_ack =>

          -- Detect a rising edge
          if sclk = '1' and sclk_old_r = '0' then
            
            if byte_counter_r /= n_bytes_c-1 then

              -- Transmission continues
              if bit_error_r = '1' then
                curr_state_r   <= wait_stop;
                bit_error_r <= '0';
                byte_counter_r <= 0;
                if block_random_nack_error_report_r = '0' and nack_given_r = '1' then
                  block_random_nack_error_report_r <= '1';
                else
                  case byte_counter_r is
                    when 0 =>  
                      report "Incorrect device address received" severity error;
                    when 1 =>
                      report "Incorrect register address received" severity error;
                    when 2 =>
                      report "Incorrect register value received" severity error;
                    when others =>
                      null;
                  end case; -- byte counter
                end if; -- block_random_nack_error_report_r

              else
                byte_counter_r <= byte_counter_r + 1;
                curr_state_r   <= read_byte;
              end if; -- bit_error_r
              
            else

              -- Transmission is about to stop
              if bit_error_r = '1' then
                curr_state_r   <= wait_stop;
                bit_error_r <= '0';
                byte_counter_r <= 0;
                if block_random_nack_error_report_r = '0' and nack_given_r = '1' then
                  block_random_nack_error_report_r <= '1';
                else
                  case byte_counter_r is
                    when 0 =>  
                      report "Incorrect device address received" severity error;
                    when 1 =>
                      report "Incorrect register address received" severity error;
                    when 2 =>
                      report "Incorrect register value received" severity error;
                    when others =>
                      null;
                  end case; -- byte counter
                end if; -- block_random_nack_error_report_r

              else
                byte_counter_r <= 0;
                written_conf_param_r <= written_conf_param_r + 1;
                curr_state_r   <= wait_stop;
              end if; -- bit_error_r
              
            end if;

          end if;

          ---------------------------------------------------------------------
          -- Wait for the stop condition
        when wait_stop =>

          -- Stop condition detection: sdat rises while sclk stays high
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '0' and sdat = '1' then

            curr_state_r <= wait_start;

          end if;

          

      end case;

    end if;
  end process fsm_proc;

  -----------------------------------------------------------------------------
  -- Asserts for verification
  -----------------------------------------------------------------------------

  -- SDAT should never contain X:s.
  assert sdat /= 'X' report "Three state bus in state X" severity error;

  assert early_finish_r /= '1' report
    "End of simulation but all parameters aren't received"
  severity failure;

  -- End of simulation, but not during the reset
  assert finished = '0' or written_conf_param_r /= 15 or rst_n = '0' report
    "Simulation done" severity failure;


    
  -- Each bit is compared to pregiven data, incorrect bits are reported 
  -- and nack is send
  -- If waiting for start and stop is received it's reported
  -- If finished but not all parameters are received it's reported
  
end testbench;
