library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;
use work.HDC_PKG.all;

entity HDCU_similarity_unit is
  generic (
    ADDR_WIDTH          : natural; 
    SPM_NUM             : natural := 4;  
    SIMD                : natural := 2;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    SIMD_WIDTH          : natural := SIMD*DATA_WIDTH;
    C_S_AXI_DATA_WIDTH : integer := 32
  );
  port (
    clk_i                       : in  std_logic;
    rst_ni                      : in  std_logic;

    halt_hdc_lat                : in  std_logic;
    sim_en                      : in  std_logic;
    sim_stage_1_en              : in  std_logic;

    AXI_HDC_INSTR_replicate_lat : in  std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
    AMSIZE_READ_lat             : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    recover_state_wires         : in  std_logic;

    hdcu_in_sim_operands        : in  array_2d(1 downto 0)(SIMD*DATA_WIDTH - 1 downto 0);
    hdcu_out_sim_results        : out std_logic_vector(SIMILARITY_BITS - 1 downto 0);
    hamming_distance_wire       : out std_logic_vector(SIMILARITY_BITS - 1 downto 0)
  );
end HDCU_similarity_unit;

architecture rtl of HDCU_similarity_unit is

  signal sim_measure          : std_logic_vector(SIMILARITY_BITS*SIMD - 1 downto 0) := (others => '0');
  signal sim_measure_wire     : std_logic_vector(SIMILARITY_BITS*SIMD - 1 downto 0) := (others => '0');
  signal hamming_distance_w   : std_logic_vector(SIMILARITY_BITS - 1 downto 0) := (others => '0');

  signal sim_active           : boolean;

  signal sim_temp_reg   : std_logic_vector(SIMILARITY_BITS*SIMD - 1 downto 0);

  -- funzione per calcolare la somma totale delle lane
  function accumulate_sim(
    x : std_logic_vector
  ) return std_logic_vector is
    variable acc : unsigned(SIMILARITY_BITS - 1 downto 0) := (others => '0');
  begin
    for i in 0 to SIMD-1 loop
      acc := acc + unsigned(x((SIMILARITY_BITS*(i+1)-1) downto SIMILARITY_BITS*i));
    end loop;
    return std_logic_vector(acc);
  end function;

begin
  --hamming_distance_wire <= hamming_distance_w;    -- MP
  hamming_distance_wire <= hamming_distance_w;    -- MP

  sim_active <= (halt_hdc_lat = '0') and (sim_en = '1') and (sim_stage_1_en = '1' or recover_state_wires = '1');

  -- === Synchronous process ===
  HDCU_sim_sync : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then    
      hdcu_out_sim_results <= (others => '0');
      sim_measure          <= (others => '0');

      sim_temp_reg  <= (others => '0'); -- MP
    elsif rising_edge(clk_i) then
      if sim_active then
        sim_measure <= sim_measure_wire;

        sim_temp_reg    <= sim_measure_wire;

        -- blocco SEARCH
        if AXI_HDC_INSTR_replicate_lat(HVSEARCH_bit_position) = '1' and
           to_integer(unsigned(AMSIZE_READ_lat)) = 0 then
          sim_measure <= (others => '0');
        end if;

      else
   --     hdcu_out_sim_results <= (others => '0');
        sim_measure          <= (others => '0');
      end if;

        hdcu_out_sim_results <= hamming_distance_w; 

    end if;
  end process;

  -- === Combinational process ===
  HDCU_sim_comb : process(all)
    variable xor_lane   : std_logic_vector(Data_Width - 1 downto 0);
    variable pop        : unsigned(SIMILARITY_BITS - 1 downto 0);
    variable sim_tmp    : std_logic_vector(SIMILARITY_BITS*SIMD - 1 downto 0);
  begin
    sim_measure_wire   <= (others => '0');
    --hamming_distance_w <= (others => '0');

    if sim_active then
      for i in 0 to SIMD-1 loop
        xor_lane := hdcu_in_sim_operands(0)((Data_Width-1) + Data_Width*i downto Data_Width*i)
                  xor hdcu_in_sim_operands(1)((Data_Width-1) + Data_Width*i downto Data_Width*i);
        pop := to_unsigned(popcount(xor_lane), SIMILARITY_BITS);

        sim_tmp((SIMILARITY_BITS-1)+SIMILARITY_BITS*i downto SIMILARITY_BITS*i) :=
          std_logic_vector(unsigned(sim_measure((SIMILARITY_BITS-1)+SIMILARITY_BITS*i downto SIMILARITY_BITS*i)) + pop);
      end loop;

      sim_measure_wire <= sim_tmp;

      -- blocco SEARCH
    --  if AXI_HDC_INSTR_replicate_lat(HVSEARCH_bit_position) = '1' then
    --    if to_integer(unsigned(AMSIZE_READ_lat)) = 0 then
    --      hamming_distance_w <= accumulate_sim(sim_tmp);
    --      hamming_distance_w <= accumulate_sim(sim_temp_reg);
    --    end if;
    --  else
    --    hamming_distance_w <= accumulate_sim(sim_tmp);
    --    hamming_distance_w <= accumulate_sim(sim_temp_reg);
    --  end if;


    end if;
    hamming_distance_w <= accumulate_sim(sim_temp_reg);

  end process;

end rtl;
