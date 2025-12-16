library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

use work.HDC_PKG.all;

entity HDCU_clipping_unit is
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
    clk_i                   : in  std_logic;
    rst_ni                  : in  std_logic;

    halt_hdc_lat            : in  std_logic;
    clip_en                 : in  std_logic;
    clip_stage_1_en         : in  std_logic;
    recover_state_wires     : in  std_logic; -- kept for symmetry

    hdcu_in_clip_operand_0  : in  std_logic_vector(SIMD*DATA_WIDTH - 1 downto 0);
    hdcu_in_clip_operand_1  : in  std_logic_vector(Data_Width - 1 downto 0);
    hdcu_out_clip_results   : out std_logic_vector(SIMD*DATA_WIDTH - 1 downto 0);

    -- status used by pipeline controller
    clip_processed_bytes    : out integer
  );
end HDCU_clipping_unit;

architecture rtl_opt of HDCU_clipping_unit is
  -- One “block” per cycle: all lanes (SIMD) × all counters per lane
  constant BLOCK_W : natural := SIMD * COUNTERS_NUMBER;

  -- ceil(log2(n)) but at least 1
  function clog2(n : natural) return natural is
    variable v : natural ; -- (comment only) no ternary in VHDL
    variable w : natural ; -- comment
    variable x : natural := n;
    variable r : natural := 0;
  begin
    -- Defensive: treat n < 2 as 1 bit
    if x <= 1 then
      return 1;
    end if;
    v := x - 1;
    r := 0;
    while v > 0 loop
      v := v / 2;
      r := r + 1;
    end loop;
    if r = 0 then
      return 1;
    else
      return r;
    end if;
  end function;

  constant CNT_W : natural := clog2(COUNTER_BITS);

  signal cnt_r   : unsigned(CNT_W-1 downto 0) := (others => '0');
  signal out_r   : std_logic_vector(SIMD*DATA_WIDTH - 1 downto 0) := (others => '0');
  signal block_b : std_logic_vector(BLOCK_W - 1 downto 0);

  signal do_step : std_logic;
begin
  clip_processed_bytes   <= to_integer(cnt_r);
  hdcu_out_clip_results  <= out_r;

  do_step <= '1' when (halt_hdc_lat = '0' and clip_en = '1' and (clip_stage_1_en = '1' or recover_state_wires = '1'))
             else '0';

  ---------------------------------------------------------------------------
  -- Build the BLOCK_W comparison bits using constant part-selects
  ---------------------------------------------------------------------------
  build_block : process(hdcu_in_clip_operand_0, hdcu_in_clip_operand_1)
    variable thr  : unsigned(COUNTER_BITS-1 downto 0);
    variable blk  : std_logic_vector(BLOCK_W - 1 downto 0);
    variable base_i : integer;
    variable idx  : integer;
    variable cval : unsigned(COUNTER_BITS-1 downto 0);
  begin
    -- Original: compare to '0' & hdcu_in_clip_operand_1(31 downto 1)
    thr := resize(unsigned(hdcu_in_clip_operand_1(31 downto 1)), COUNTER_BITS);

    idx := 0;
    for i in 0 to SIMD-1 loop
      base_i := Data_Width * i;
      for k in 0 to COUNTERS_NUMBER-1 loop
        cval := unsigned(hdcu_in_clip_operand_0(base_i + COUNTER_BITS*(k+1) - 1 downto
                                                base_i + COUNTER_BITS*k));
        if (cval <= thr) then
          blk(idx) := '0';
        else
          blk(idx) := '1';
        end if;
        idx := idx + 1;
      end loop;
    end loop;

    block_b <= blk;
  end process;

  ---------------------------------------------------------------------------
  -- Shift/append the block into the output register & wrap counter
  ---------------------------------------------------------------------------
  seq : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      cnt_r <= (others => '0');
      out_r <= (others => '0');
    elsif rising_edge(clk_i) then
      if do_step = '1' then
        if BLOCK_W = SIMD*DATA_WIDTH then
          out_r <= block_b;
        else
          -- keep older bits on the left, append new block on the right
          out_r <= block_b & out_r(SIMD*DATA_WIDTH - 1 downto BLOCK_W);
        end if;

        if cnt_r = to_unsigned(COUNTER_BITS-1, CNT_W) then
          cnt_r <= (others => '0');
        else
          cnt_r <= cnt_r + 1;
        end if;
      else
        cnt_r <= (others => '0');
      end if;
    end if;
  end process;

end rtl_opt;
