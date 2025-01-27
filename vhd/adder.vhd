-------------------------------------------------------------------------------
-- File       : adder.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Company    : 
-- Created    : 2023-01-24
-- Last update: 2023-01-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: <cursor>
-------------------------------------------------------------------------------
-- Copyright (c) 2023 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-01-24  1.0      Roope Akkanen   Created
-------------------------------------------------------------------------------

-- Include default library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Declare adder generic parameters, inputs and outputs
entity adder is
  generic (
    operand_width_g : integer);

  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    a_in    : in  std_logic_vector(operand_width_g-1 downto 0);
    b_in    : in  std_logic_vector(operand_width_g-1 downto 0);
    sum_out : out std_logic_vector(operand_width_g downto 0));
end adder;

-- Define architecture of adder
architecture rtl of adder is

  -- Define register signal and its size
  signal result_r : signed(operand_width_g downto 0);

begin
  -- Connect register signal to output
  sum_out <= std_logic_vector(result_r);
  summation_sync : process (clk, rst_n)
  begin
    if rst_n = '0' then
      -- Reset register signal values asynchronously
      result_r <= (others => '0');
    elsif clk'event and clk = '1' then
      -- Resize operand bit vectors and sum them together synchronously
      result_r <=  resize(signed(a_in), operand_width_g+1)+resize(signed(b_in), operand_width_g+1);
    end if;
  end process summation_sync;
end rtl;
