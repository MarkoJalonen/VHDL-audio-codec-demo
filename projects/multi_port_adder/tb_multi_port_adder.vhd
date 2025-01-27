-------------------------------------------------------------------------------
-- File       : tb_multi_port_adder.vhd
-- Author     : 7, Roope Akkanen
-- Author     : 7, Marko Jalonen
-- Company    : 
-- Created    : 2023-02-06
-- Last update: 2023-02-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: <cursor>
-------------------------------------------------------------------------------
-- Copyright (c) 2023 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-02-06  1.0      Roope Akkanen   Created
-------------------------------------------------------------------------------

-- Include default library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Define multi port adder testbench entity
entity tb_multi_port_adder is

  generic (
    operand_width_g : integer := 3);    -- Declare generic value 3

end entity tb_multi_port_adder;

architecture testbench of tb_multi_port_adder is

  constant period_c          : time    := 10 ns;  -- Define clock cycle length
  constant num_of_operands_c : integer := 4;      -- Define number of operands
  constant duv_delay_c       : integer := 2;      -- Define cycle delay for DUV

  signal clk, rst_n     : std_logic := '0';  -- Define clock and reset signals
  signal operands_r     : std_logic_vector(operand_width_g*num_of_operands_c-1 downto 0);  -- Define DUV input signal
  signal sum            : std_logic_vector(operand_width_g-1 downto 0);  -- Define DUV output signal
  signal output_valid_r : std_logic_vector(duv_delay_c+1-1 downto 0);  -- Define delay compensation register

  file input_f       : text open read_mode is "input.txt";  -- Define input.txt
  file ref_results_f : text open read_mode is "ref_results.txt";  -- Define ref_results.txt
  file output_f      : text open write_mode is "output.txt";  -- Define output file

begin  -- architecture testbench

  generate_clock : process (clk)
  begin  --process
    clk <= not clk after period_c/2;    -- Assign clock signal
  end process;

  rst_n <= '0', '1' after 4*period_c;   -- Assign reset signal

  -- instance "multi_port_adder_1"
  multi_port_adder_1 : entity work.multi_port_adder(structural)
    generic map(
      operand_width_g   => operand_width_g,
      num_of_operands_g => num_of_operands_c)
    port map(
      clk         => clk,
      rst_n       => rst_n,
      operands_in => operands_r,
      sum_out     => sum);

  input_reader_sync : process (clk, rst_n)  -- Create a synchronous input
                                            -- reader process
    variable line_v             : line;
    type int_array is array(3 downto 0) of integer;
    variable integer_variable_v : int_array;

  begin  -- process
    if rst_n = '0' then
      operands_r     <= (others => '0');
      output_valid_r <= (others => '0');
    elsif clk'event and clk = '1' then  -- On rising clock edge
      -- Set ouput_valid_r LSB to 1 and shift left
      output_valid_r <= output_valid_r(output_valid_r'left-1 downto 0) & '1';
      if not (endfile(input_f)) then
        readline(input_f, line_v);
        -- assert line_v'length /= 0
          -- report "Empty line!"
          -- severity note;
        -- Read lines into integer variable
        for i in integer_variable_v'range loop
          read(line_v, integer_variable_v(i));
        end loop;
        -- Forward integer variable values to multiport adder operands
        for j in integer_variable_v'range loop
          operands_r((j+1) * operand_width_g -1 downto j*operand_width_g) <= std_logic_vector(to_signed(integer_variable_v(j), operand_width_g));
        end loop;
      end if;
    end if;
  end process input_reader_sync;

  checker_sync : process (clk, rst_n) -- Create synchronous process for
                                      -- comparing reference values with sum
    variable line_out  : line;
    variable line_ref  : line;
    variable value_ref : integer;

  begin  -- process
    if clk'event and clk = '1' then
      if output_valid_r(duv_delay_c) = '1' then
        if not (endfile(ref_results_f)) then
          readline(ref_results_f, line_ref);
          read(line_ref, value_ref);
          assert value_ref = to_integer(signed(sum))
            report "Reference and sum are not equal!"
            severity note;
        -- assert not (value_ref = to_integer(signed(sum)))
        -- report "Reference and sum are equal!"
        -- severity note;
        else
          assert false
            report "Simulation success!"
            severity failure;
        end if;
        -- Write sum to output file
        write(line_out, to_integer(signed(sum)));
        writeline(output_f, line_out);
      end if;
    end if;
  end process checker_sync;
end architecture testbench;

