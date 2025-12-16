library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

use work.HDC_PKG.all;

entity HDCU_search_unit is
  generic (
    ADDR_WIDTH          : natural; 
    SPM_NUM             : natural := 4;  
    SIMD                : natural := 2;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    SIMD_WIDTH          : natural := SIMD*DATA_WIDTH;
    C_S_AXI_DATA_WIDTH : integer := 32
  );
  port (
    -- clock/reset
    clk_i                       : in  std_logic;
    rst_ni                      : in  std_logic;

    -- control
    halt_hdc_lat                : in  std_logic;
    as_en                       : in  std_logic;
    as_stage_1_en               : in  std_logic;
    recover_state_wires         : in  std_logic;

    -- inputs from SIM unit / top
    AMSIZE_READ_lat             : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    hamming_distance_wire       : in  std_logic_vector(SIMILARITY_BITS - 1 downto 0);
    class_index                 : in  integer;

    -- outputs used by the top
    temp_best_class_index       : out integer
  );
end HDCU_search_unit;

architecture rtl of HDCU_search_unit is
  signal temp_best_class_sim_r   : integer := 8192; -- original init (worst case)
  signal temp_best_class_index_r : integer := 0;
begin
  temp_best_class_index <= temp_best_class_index_r;

  -- === original associative-search FSM (unchanged behavior) ===
  fsm_HDCU_as : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      -- Initialize with worst case scenario
      temp_best_class_sim_r   <= 8192;
      temp_best_class_index_r <= 0;
    elsif rising_edge(clk_i) then
      -- Only update when associative search is active and not halted
      if halt_hdc_lat = '0' and as_en = '1' and (as_stage_1_en = '1' or recover_state_wires = '1') then
        -- Check if we've reached the end of a class comparison (similarity calculation complete)
        if to_integer(unsigned(AMSIZE_READ_lat)) = 0 then
          -- Update if we found a better similarity
          if temp_best_class_sim_r > to_integer(unsigned(hamming_distance_wire)) then
            temp_best_class_sim_r   <= to_integer(unsigned(hamming_distance_wire));
            temp_best_class_index_r <= class_index;
          end if;
        end if;
      end if;
    end if;
  end process;
end rtl;