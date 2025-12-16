library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

-- local packages
use work.HDC_PKG.all;

entity HDCU_bundling_unit is
  generic(
    ADDR_WIDTH          : natural; 
    SPM_NUM             : natural := 4;  
    SIMD                : natural := 2;
    COUNTER_BITS        : natural;
    COUNTERS_NUMBER     : natural;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    SIMD_WIDTH          : natural := SIMD*DATA_WIDTH
  );
  port (
    -- Clock & reset
    clk_i                  : in  std_logic;
    rst_ni                 : in  std_logic;

    -- Control
    halt_hdc_lat           : in  std_logic;
    bundle_en              : in  std_logic;
    bundle_stage_1_en      : in  std_logic;
    recover_state_wires    : in  std_logic;

    -- Data
    hdcu_in_bundle_operands: in  array_2d(1 downto 0)(SIMD*DATA_WIDTH - 1 downto 0);
    hdcu_out_bundle_results: out std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);

    -- Status needed by the top
    bundle_processed_bytes : out integer
  );
end HDCU_bundling_unit;

architecture rtl of HDCU_bundling_unit is
  -- Flattened counter arrays to avoid 3D-RAM synthesis issues
  signal counters_flat      : std_logic_vector(SIMD*COUNTERS_NUMBER*COUNTER_BITS-1 downto 0) := (others => '0');
  signal counters_wire_flat : std_logic_vector(SIMD*COUNTERS_NUMBER*COUNTER_BITS-1 downto 0) := (others => '0');

  -- Helper function to calculate flat array index
  -- For counters_flat(i)(k) the index is: i*COUNTERS_NUMBER*COUNTER_BITS + k*COUNTER_BITS + bit_index
  -- Range for counter (i,k) is: (i*COUNTERS_NUMBER + k + 1)*COUNTER_BITS - 1 downto (i*COUNTERS_NUMBER + k)*COUNTER_BITS
  signal bundle_offset      : array_2d_int(SIMD-1 downto 0);
  signal bundle_processed_bytes_r : integer := 0;
begin
  -- expose internal counter
  bundle_processed_bytes <= bundle_processed_bytes_r;

  -- === original sync: copy counters to output HV ===
  HDCU_bundling_sync : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      counters_flat <= (others => '0');
    elsif rising_edge(clk_i) then
      if bundle_en = '1' and halt_hdc_lat = '0' and (bundle_stage_1_en = '1' or recover_state_wires = '1') then
        -- Copy from wire to register
        counters_flat <= counters_wire_flat;

        -- Update output bundle results
        for i in 0 to SIMD - 1 loop
          for k in 0 to COUNTERS_NUMBER - 1 loop
            -- Extract counter(i,k) from flat array and assign to output
            hdcu_out_bundle_results(Data_Width*i + COUNTER_BITS*(k+1) - 1 downto Data_Width*i + COUNTER_BITS*k) <= 
              counters_wire_flat((i*COUNTERS_NUMBER + k + 1)*COUNTER_BITS - 1 downto (i*COUNTERS_NUMBER + k)*COUNTER_BITS);
          end loop;
        end loop;
      end if;
    end if;
  end process;

  -- === original sync: offsets & byte counter ===
  HDCU_bundling_offset_sync : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      bundle_processed_bytes_r <= 0;
      for i in 0 to SIMD - 1 loop
        bundle_offset(i) <= COUNTERS_NUMBER*i;
      end loop;
    elsif rising_edge(clk_i) then
      if bundle_en = '1' and halt_hdc_lat = '0' and (bundle_stage_1_en = '1' or recover_state_wires = '1') then
        -- Increment offsets and process counter
        for i in 0 to SIMD - 1 loop
          bundle_offset(i) <= bundle_offset(i) + COUNTERS_NUMBER*SIMD;
        end loop;
        bundle_processed_bytes_r <= bundle_processed_bytes_r + 1;

        -- Reset when we complete a 32-bit word
        if (bundle_processed_bytes_r = Data_Width/COUNTERS_NUMBER - 1) then
          bundle_processed_bytes_r <= 0;
          for i in 0 to SIMD - 1 loop
            bundle_offset(i) <= COUNTERS_NUMBER*i;
          end loop;
        end if;
      end if;
    end if;
  end process;

  -- === original comb: update counters ===
  comb_HDCU_bundling: process(all)
  begin
    counters_wire_flat <= counters_flat;  -- Default: maintain current counter values

    if bundle_en = '1' and halt_hdc_lat = '0' and (bundle_stage_1_en = '1' or recover_state_wires = '1') then
      for i in 0 to SIMD - 1 loop
        for k in 0 to COUNTERS_NUMBER - 1 loop
          -- Copy counter from input operand
          counters_wire_flat((i*COUNTERS_NUMBER + k + 1)*COUNTER_BITS - 1 downto (i*COUNTERS_NUMBER + k)*COUNTER_BITS) <= 
            hdcu_in_bundle_operands(0)(Data_Width*i + COUNTER_BITS*(k+1) - 1 downto Data_Width*i + COUNTER_BITS*k);

          -- Increment counter if the corresponding bit is '1'
          if hdcu_in_bundle_operands(1)(bundle_offset(i) + k) = '1' then
            counters_wire_flat((i*COUNTERS_NUMBER + k + 1)*COUNTER_BITS - 1 downto (i*COUNTERS_NUMBER + k)*COUNTER_BITS) <= 
              std_logic_vector(unsigned(hdcu_in_bundle_operands(0)(Data_Width*i + COUNTER_BITS*(k+1) - 1 downto Data_Width*i + COUNTER_BITS*k)) + 1);
          end if;
        end loop;
      end loop;
    end if;
  end process;
end rtl;
