-------------------------------------------------------------------------------
-- File       : wave_gen.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Company    : 
-- Created    : 2023-02-13
-- Last update: 2023-03-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A triangle wave generator block 
-------------------------------------------------------------------------------
-- Copyright (c) 2023 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-02-13  1.0      Roope Akkanen   Created
-------------------------------------------------------------------------------

-- Include default library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- purpose: Generate triangle wave
entity wave_gen is
  generic (
    width_g : integer;                  -- Specify counter_rbit-width
    step_g  : integer);                 -- Specify step size
  port (
    clk             : in  std_logic;    -- Clock signal
    rst_n           : in  std_logic;    -- Asynchronous reset signal
    sync_clear_n_in : in  std_logic;    -- Syncronous reset
    value_out       : out std_logic_vector(width_g-1 downto 0));  -- Output vector
end entity wave_gen;

architecture rtl of wave_gen is
  type state_type_t is (up, down); -- wave direction type
  signal state_r : state_type_t; -- wave direction

  -- floored counter max & min from width and step 
  constant counter_max_c : integer := (2**(width_g-1)-1)/step_g*step_g;
  constant counter_min_c : integer := -counter_max_c;
  -- wave amplitude counter
  signal counter_r : integer;
  
begin -- Output calculation and sync reset
  -- Assign output outside of synchronous process
  value_out <= std_logic_vector(to_signed(counter_r, width_g));

  output_calc : process(clk, rst_n) is
  begin
      -- asynchronous reset
      if rst_n = '0' then
        state_r<= up;
        counter_r<= 0;
      -- synchronous reset
      elsif clk'event and clk = '1' then
        if sync_clear_n_in = '0' then
          state_r<= up;
          counter_r<= 0;
        else
          -- increment counter_raccording to the direction state
          if state_r= up then
            -- reverse a step ahead to address one cycle latency on signals 
            counter_r<= counter_r+ step_g;
            if counter_r= counter_max_c - step_g then
              state_r<= down;
            end if;
          else
            -- reverse a step ahead to address one cycle latency on signals
            counter_r<= counter_r- step_g;
            if counter_r= counter_min_c + step_g then
              state_r<= up;
            end if; 
          end if;
        end if;
      end if;
    end process output_calc;

end architecture rtl;

