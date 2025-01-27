-------------------------------------------------------------------------------
-- File       : ripple_carry_adder.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Company    : 
-- Created    : 2023-01-20
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
-- 2023-01-20  1.0      Roope Akkanen   Created
-------------------------------------------------------------------------------

-- Include default library
library ieee;
use ieee.std_logic_1164.all;

-- Declare ripple carry adder inputs and outputs
entity ripple_carry_adder is
  port(
    a_in  : in  std_logic_vector(2 downto 0);
    b_in  : in  std_logic_vector(2 downto 0);
    s_out : out std_logic_vector(3 downto 0));
end ripple_carry_adder;


-------------------------------------------------------------------------------

architecture gate of ripple_carry_adder is

  -- Declare internal signals of the ripple carry adder
  signal carry_ha, carry_fa, c, d, e, f, g, h : std_logic;

begin

  -- Define half adder internal logic
  s_out(0) <= a_in(0) xor b_in(0);
  carry_ha <= a_in(0) and b_in(0);
  -- Define first full adder internal logic
  c        <= a_in(1) xor b_in(1);
  s_out(1) <= c xor carry_ha;
  d        <= c and carry_ha;
  e        <= a_in(1) and b_in(1);
  carry_fa <= d or e;
  -- Define second full adder internal logic
  f        <= a_in(2) xor b_in(2);
  s_out(2) <= f xor carry_fa;
  g        <= carry_fa and f;
  h        <= a_in(2) and b_in(2);
  s_out(3) <= g or h;

end gate;
