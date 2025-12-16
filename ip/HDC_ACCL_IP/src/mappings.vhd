library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

use work.HDC_PKG.all;

entity HDCU_mapping is
  generic (
    C_S_AXI_DATA_WIDTH : integer := 32;
    ADDR_WIDTH          : natural; 
    SPM_NUM             : natural := 4;
    COUNTER_BITS        : natural;
    COUNTERS_NUMBER     : natural;
    SIMD                : natural := 2;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    SIMD_WIDTH          : natural := SIMD*DATA_WIDTH;
    SIMD_RD_BYTES       : integer := SIMD*DATA_WIDTH/8
  );
  port (
    ----------------------------------------------------------------
    -- Control / state
    ----------------------------------------------------------------
    wb_ready                  : in  std_logic;
    busy_hdc_internal_lat     : in  std_logic;
    state_HDC                 : in  std_logic_vector(1 downto 0);

    ----------------------------------------------------------------
    -- Instruction mirrors
    ----------------------------------------------------------------
    AXI_HDC_INSTR_replicate     : in std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
    AXI_HDC_INSTR_replicate_lat : in std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);

    ----------------------------------------------------------------
    -- Data inputs from SPM + regs used by mapping_in
    ----------------------------------------------------------------
    hdc_sc_data_read          : in  array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
    AXI_HVSIZE                : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RS2                   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    ----------------------------------------------------------------
    -- FU results used by mapping_out
    ----------------------------------------------------------------
    hdcu_out_bundle_results   : in  std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    hdcu_out_bind_results     : in  std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    hdcu_out_sim_results      : in  std_logic_vector(SIMILARITY_BITS-1 downto 0);
    hdcu_out_clip_results     : in  std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    hdcu_out_perm_results     : in  std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);

    -- search helper
    temp_best_class_index     : in  integer;

    ----------------------------------------------------------------
    -- halt handoff (mapping_out)
    ----------------------------------------------------------------
    halt_hdc                  : in  std_logic;
    halt_hdc_lat              : in  std_logic;
    hdc_sc_data_write_int     : in  std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);

    ----------------------------------------------------------------
    -- Outputs from mapping_out
    ----------------------------------------------------------------
    hdc_sc_data_write_wire_int : out std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    hdc_sc_data_write_wire     : out std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);

    ----------------------------------------------------------------
    -- Outputs from mapping_in (FU operands)
    ----------------------------------------------------------------
    hdcu_in_bundle_operands   : out array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
    hdcu_in_bind_operands     : out array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
    hdcu_in_sim_operands      : out array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
    hdcu_in_clip_operand_0    : out std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    hdcu_in_clip_operand_1    : out std_logic_vector(Data_Width-1 downto 0);
    hdcu_in_perm_operand_0    : out std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    hdcu_in_perm_operand_1    : out std_logic_vector(Data_Width-1 downto 0)
  );
end entity;

architecture rtl of HDCU_mapping is
begin

  -----------------------------------------------------------------------------
  -- MAPPING_OUT_UNIT_comb  (unchanged logic)
  -----------------------------------------------------------------------------
  MAPPING_OUT_UNIT_comb : process(all)
    variable v_hdc_sc_data_write_int : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    variable v_hdc_sc_data_write     : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
  begin
    -- defaults
    v_hdc_sc_data_write_int := (others => '0');
    v_hdc_sc_data_write     := v_hdc_sc_data_write_int;

    if wb_ready = '1' or busy_hdc_internal_lat = '1' then
      case state_HDC is
        when hdc_init =>
          null;

        when hdc_exec =>
          -- BUNDLING
          if AXI_HDC_INSTR_replicate_lat(HVBUNDLE_bit_position) = '1' then
            v_hdc_sc_data_write_int := hdcu_out_bundle_results;

          -- BINDING
          elsif AXI_HDC_INSTR_replicate_lat(HVBIND_bit_position) = '1' then
            v_hdc_sc_data_write_int := hdcu_out_bind_results;

          -- SIMILARITY
          elsif AXI_HDC_INSTR_replicate_lat(HVSIM_bit_position) = '1' then
            v_hdc_sc_data_write_int(SIMILARITY_BITS-1 downto 0) := hdcu_out_sim_results;

          -- CLIPPING
          elsif AXI_HDC_INSTR_replicate_lat(HVCLIP_bit_position) = '1' then
            for i in 0 to SIMD-1 loop
              v_hdc_sc_data_write_int((Data_Width-1)+Data_Width*i downto Data_Width*i) :=
                hdcu_out_clip_results((Data_Width-1)+Data_Width*i downto Data_Width*i);
            end loop;

          -- PERMUTATION (note: checks RAW replicate signal)
          elsif AXI_HDC_INSTR_replicate(HVPERM_bit_position) = '1' then
              v_hdc_sc_data_write_int := hdcu_in_perm_operand_0;

          -- SEARCH
          elsif AXI_HDC_INSTR_replicate_lat(HVSEARCH_bit_position) = '1' then
            v_hdc_sc_data_write_int(Data_Width-1 downto 0) :=
              std_logic_vector(to_unsigned(temp_best_class_index, Data_Width));
          end if;

        when others =>
          null;
      end case;

      -- writeback handoff
      if halt_hdc = '0' and halt_hdc_lat = '1' then
        v_hdc_sc_data_write := hdc_sc_data_write_int;
      else
        v_hdc_sc_data_write := v_hdc_sc_data_write_int;
      end if;
    else
      v_hdc_sc_data_write := v_hdc_sc_data_write_int;
    end if;

    hdc_sc_data_write_wire_int <= v_hdc_sc_data_write_int;
    hdc_sc_data_write_wire     <= v_hdc_sc_data_write;
  end process;


  -----------------------------------------------------------------------------
  -- DSP_MAPPING_IN_UNIT_comb 
  -----------------------------------------------------------------------------
  DSP_MAPPING_IN_UNIT_comb : process(all)
    variable v_in_bundle : array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
    variable v_in_bind   : array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
    variable v_in_sim    : array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
    variable v_clip0     : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    variable v_clip1     : std_logic_vector(Data_Width-1 downto 0);
    variable v_perm0     : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
    variable v_perm1     : std_logic_vector(Data_Width-1 downto 0);
  begin
    -- Clear all FU inputs
    v_in_bundle := (others => (others => '0'));
    v_in_bind   := (others => (others => '0'));
    v_in_sim    := (others => (others => '0'));
    v_clip0     := (others => '0');
    v_clip1     := (others => '0');
    v_perm0     := (others => '0');
    v_perm1     := (others => '0');

    if unsigned(AXI_HDC_INSTR_replicate) /= 0 or busy_hdc_internal_lat = '1' then
      case state_HDC is
        when hdc_init =>
          null;

        when hdc_exec =>
          -- BUNDLING
          if AXI_HDC_INSTR_replicate_lat(HVBUNDLE_bit_position) = '1' then 
            v_in_bundle(0) := hdc_sc_data_read(0);
            for i in 0 to SIMD - 1 loop
              for k in 0 to COUNTER_BITS - 1 loop
                v_in_bundle(1)(Data_Width*i + COUNTERS_NUMBER*(k+1) - 1 downto Data_Width*i + COUNTERS_NUMBER*k) :=
                  hdc_sc_data_read(1)(Data_Width*(i+1) - 1 - COUNTERS_NUMBER*k downto Data_Width*(i+1) - COUNTERS_NUMBER*(k+1));
              end loop;
            end loop;
          end if;

          -- BINDING
          if AXI_HDC_INSTR_replicate_lat(HVBIND_bit_position) = '1' then
            v_in_bind(0) := hdc_sc_data_read(0);
            v_in_bind(1) := hdc_sc_data_read(1);             
          end if;

          -- SIMILARITY & SEARCH
          if AXI_HDC_INSTR_replicate_lat(HVSIM_bit_position) = '1' or
             AXI_HDC_INSTR_replicate_lat(HVSEARCH_bit_position) = '1' then
            v_in_sim(0) := hdc_sc_data_read(0);
            if AXI_HDC_INSTR_replicate_lat(HVSEARCH_bit_position) = '1' and
               to_integer(unsigned(AXI_HVSIZE)) < SIMD_RD_BYTES then
              v_in_sim(1)(to_integer(unsigned(AXI_HVSIZE))*8 - 1 downto 0) :=hdc_sc_data_read(1)(to_integer(unsigned(AXI_HVSIZE))*8 - 1 downto 0); 
              v_in_sim(1)(SIMD*DATA_WIDTH-1 downto to_integer(unsigned(AXI_HVSIZE))*8) := (others => '0');
            else
              v_in_sim(1) := hdc_sc_data_read(1);
            end if;
          end if;

          -- CLIPPING
          if AXI_HDC_INSTR_replicate_lat(HVCLIP_bit_position) = '1' then
            v_clip0 := hdc_sc_data_read(0);
            v_clip1 := AXI_RS2;
          end if;

          -- PERMUTATION (checks RAW replicate)
          if AXI_HDC_INSTR_replicate(HVPERM_bit_position) = '1' then
            for i in 0 to SIMD - 1 loop
              v_perm0(Data_Width*(i+1) - 1 downto Data_Width*i) :=
                hdc_sc_data_read(0)(Data_Width*(i+1) - 1 downto Data_Width*i);
            end loop;
            v_perm1 := AXI_RS2;
          end if;

        when others =>
          null;
      end case;
    end if;

    -- Drive outs
    hdcu_in_bundle_operands <= v_in_bundle;
    hdcu_in_bind_operands   <= v_in_bind;
    hdcu_in_sim_operands    <= v_in_sim;
    hdcu_in_clip_operand_0  <= v_clip0;
    hdcu_in_clip_operand_1  <= v_clip1;
    hdcu_in_perm_operand_0  <= v_perm0;
    hdcu_in_perm_operand_1  <= v_perm1;

  end process;


end architecture;
