library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

-- local packages
use work.HDC_PKG.all;

entity HDCU_binding_unit is
  generic(
    ADDR_WIDTH          : natural; 
    SPM_NUM             : natural := 4;  
    SIMD                : natural := 2;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    SIMD_WIDTH          : natural := SIMD*DATA_WIDTH
  );
  port (
    -- Clock & reset
    clk_i                 : in  std_logic;
    rst_ni                : in  std_logic;

    -- Control
    halt_hdc_lat          : in  std_logic;
    bind_en               : in  std_logic;
    bind_stage_1_en       : in  std_logic;
    recover_state_wires   : in  std_logic;

    -- Data
    hdcu_in_bind_operands : in  array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
    hdcu_out_bind_results : out std_logic_vector(SIMD*DATA_WIDTH-1 downto 0)
  );
end HDCU_binding_unit;

architecture rtl of HDCU_binding_unit is
begin
  
  binding_comb : process(clk_i, rst_ni)
    variable bind_result : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    variable i : integer;
  begin
    if rst_ni = '0' then
      hdcu_out_bind_results <= (others => '0');
    elsif rising_edge(clk_i) then
      if halt_hdc_lat = '0' then
        if bind_en = '1' and (bind_stage_1_en = '1' or recover_state_wires = '1') then
          for i in 0 to SIMD-1 loop
            bind_result((Data_Width-1)+Data_Width*i downto Data_Width*i) :=
              std_logic_vector(unsigned(hdcu_in_bind_operands(0)((Data_Width-1)+Data_Width*i downto Data_Width*i)) xor
                               unsigned(hdcu_in_bind_operands(1)((Data_Width-1)+Data_Width*i downto Data_Width*i)));
          end loop;
          hdcu_out_bind_results <= bind_result;
        end if;
      end if;
    end if;
  end process;
end rtl;
