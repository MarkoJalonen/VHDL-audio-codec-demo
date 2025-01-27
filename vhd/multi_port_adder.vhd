-------------------------------------------------------------------------------
-- File       : multi_port_adder.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Company    : 
-- Created    : 2023-01-20
-- Last update: 2023-02-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: <cursor>
-------------------------------------------------------------------------------
-- Copyright (c) 2023 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-01-20  1.0      Roope Akkanen   Created
-------------------------------------------------------------------------------

-- Include default library
library ieee;
use ieee.std_logic_1164.all;

-- Declare multi port adder inputs and outputs
entity multi_port_adder is
  generic (
    operand_width_g   : integer; --:= 16;
    num_of_operands_g : integer); --:= 4);

  port(
    clk         : in  std_logic;
    rst_n       : in  std_logic;
    operands_in : in  std_logic_vector((operand_width_g*num_of_operands_g)-1 downto 0);
    sum_out     : out std_logic_vector(operand_width_g-1 downto 0));
end multi_port_adder;

-- Define architecture of multi port adder
architecture structural of multi_port_adder is

  component adder
    generic (
      operand_width_g : integer); --:= 16);

    port (
      clk, rst_n : in  std_logic;
      a_in, b_in : in  std_logic_vector(operand_width_g-1 downto 0);
      sum_out    : out std_logic_vector(operand_width_g downto 0));
  end component;

  type vector_array_type is array(0 to (num_of_operands_g/2)-1) of std_logic_vector(operand_width_g downto 0);

  signal subtotal_adder_adder : vector_array_type;
  signal total                : std_logic_vector(operand_width_g+1 downto 0);

begin
  i_add_0 : adder
    generic map (
      operand_width_g => operand_width_g)
    port map (clk     => clk,
              rst_n   => rst_n,
              a_in    => operands_in(operand_width_g-1 downto 0),
              b_in    => operands_in((2*operand_width_g)-1 downto operand_width_g),
              sum_out => subtotal_adder_adder(0));
  i_add_1 : adder
    generic map (
      operand_width_g => operand_width_g)
    port map (clk     => clk,
              rst_n   => rst_n,
              a_in    => operands_in((3*operand_width_g)-1 downto (2*operand_width_g)),
              b_in    => operands_in((4*operand_width_g)-1 downto (3*operand_width_g)),
              sum_out => subtotal_adder_adder(1));
  i_add_2 : adder
    generic map (
      operand_width_g => operand_width_g)
    port map (clk     => clk,
              rst_n   => rst_n,
              a_in    => subtotal_adder_adder(0)(operand_width_g-1 downto 0),
              b_in    => subtotal_adder_adder(1)(operand_width_g-1 downto 0),
              sum_out => total(operand_width_g downto 0));
  sum_out <= total(operand_width_g-1 downto 0);
  assert num_of_operands_g = 4
    report "Severity failure";
end structural;

