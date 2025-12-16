library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

-- Pull constants like COUNTER_BITS, state encodings, bit positions, etc.
use work.HDC_PKG.all;

entity HDCU_pipeline_ctrl is
  generic (
    SPM_NUM             : natural := 4;  
    SIMD                : natural := 2;
    COUNTER_BITS        : natural;
    COUNTERS_NUMBER     : natural;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    SIMD_WIDTH          : natural := SIMD*DATA_WIDTH;
    SIMD_RD_BYTES       : integer := SIMD*DATA_WIDTH/8;
    ADDR_WIDTH : natural := 32  -- only used for the zero test width
  );
  port (
    ----------------------------------------------------------------
    -- Clocks / reset
    ----------------------------------------------------------------
    clk_i                 : in  std_logic;
    rst_ni                : in  std_logic;

    ----------------------------------------------------------------
    -- Inputs this block reads
    ----------------------------------------------------------------
    -- handshakes / status
    hdc_data_gnt_i        : in  std_logic;
    busy_hdc              : in  std_logic;
    busy_hdc_internal     : in  std_logic;
    nextstate_HDC         : in  std_logic_vector(1 downto 0);
    halt_hdc              : in  std_logic;

    -- datapath / counters used in the enables’ timing
    HVSIZE_READ_lat       : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    clip_processed_bytes  : in  integer;

    -- instruction/mirror used to arm functional units
    AXI_HDC_INSTR           : in  std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
    AXI_HDC_INSTR_replicate : in std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);

    ----------------------------------------------------------------
    -- Registered mirrors this block drives (latched status)
    ----------------------------------------------------------------
    hdc_data_gnt_i_lat    : out std_logic;
    state_HDC             : out std_logic_vector(1 downto 0);
    busy_hdc_internal_lat : out std_logic;
    busy_hdc_lat          : out std_logic;
    halt_hdc_lat          : out std_logic;

    ----------------------------------------------------------------
    -- Stage enable pulses (registered)
    ----------------------------------------------------------------
    bundle_stage_1_en     : out std_logic;
    bundle_stage_2_en     : out std_logic;

    bind_stage_1_en       : out std_logic;
    bind_stage_2_en       : out std_logic;

    sim_stage_1_en        : out std_logic;
    sim_stage_2_en        : out std_logic;

    clip_stage_1_en       : out std_logic;
    clip_stage_2_en       : out std_logic;

    perm_stage_1_en       : out std_logic;
    perm_stage_2_en       : out std_logic;

    as_stage_1_en         : out std_logic;
    as_stage_2_en         : out std_logic;
    as_stage_3_en         : out std_logic;

    ----------------------------------------------------------------
    -- FU enables (registered) and comb “wires” (outputs of comb proc)
    ----------------------------------------------------------------
    bundle_en             : out std_logic;
    bind_en               : out std_logic;
    sim_en                : out std_logic;
    clip_en               : out std_logic;
    perm_en               : out std_logic;
    as_en                 : out std_logic
  );
end entity;

architecture rtl of HDCU_pipeline_ctrl is
  -- internal wires driven by the comb “enabler” proc
  signal bundle_en_wire_s : std_logic := '0';
  signal bind_en_wire_s   : std_logic := '0';
  signal sim_en_wire_s    : std_logic := '0';
  signal clip_en_wire_s   : std_logic := '0';
  signal perm_en_wire_s   : std_logic := '0';
  signal as_en_wire_s     : std_logic := '0';

  -- registered enables that the rest of the design uses
  signal bundle_en_r : std_logic := '0';
  signal bind_en_r   : std_logic := '0';
  signal sim_en_r    : std_logic := '0';
  signal clip_en_r   : std_logic := '0';
  signal perm_en_r   : std_logic := '0';
  signal as_en_r     : std_logic := '0';

  -- registered mirrors
  signal hdc_data_gnt_i_lat_r    : std_logic := '0';
  signal state_HDC_r             : std_logic_vector(1 downto 0) := hdc_init;
  signal busy_hdc_internal_lat_r : std_logic := '0';
  signal busy_hdc_lat_r          : std_logic := '0';
  signal halt_hdc_lat_r          : std_logic := '0';

  -- stage regs
  signal bundle_stage_1_en_r : std_logic := '0';
  signal bundle_stage_2_en_r : std_logic := '0';

  signal bind_stage_1_en_r   : std_logic := '0';
  signal bind_stage_2_en_r   : std_logic := '0';

  signal sim_stage_1_en_r    : std_logic := '0';
  signal sim_stage_2_en_r    : std_logic := '0';

  signal clip_stage_1_en_r   : std_logic := '0';
  signal clip_stage_2_en_r   : std_logic := '0';

  signal perm_stage_1_en_r   : std_logic := '0';
  signal perm_stage_2_en_r   : std_logic := '0';

  signal as_stage_1_en_r     : std_logic := '0';
  signal as_stage_2_en_r     : std_logic := '0';
  signal as_stage_3_en_r     : std_logic := '0';
begin
  -----------------------------------------------------------------------------
  -- 1) fsm_HDC_pipeline_controller  (UNCHANGED BEHAVIOR)
  -----------------------------------------------------------------------------
  fsm_HDC_pipeline_controller : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      hdc_data_gnt_i_lat_r    <= '0';
      state_HDC_r             <= hdc_init;
      busy_hdc_lat_r          <= '0';

      bundle_stage_1_en_r     <= '0';
      bundle_stage_2_en_r     <= '0';

      bind_stage_1_en_r       <= '0';
      bind_stage_2_en_r       <= '0';

      sim_stage_1_en_r        <= '0';
      sim_stage_2_en_r        <= '0';

      clip_stage_1_en_r       <= '0';
      clip_stage_2_en_r       <= '0';

      perm_stage_1_en_r       <= '0';
      perm_stage_2_en_r       <= '0';

      as_stage_1_en_r         <= '0';
      as_stage_2_en_r         <= '0';
      as_stage_3_en_r         <= '0';

      busy_hdc_internal_lat_r <= '0';
      halt_hdc_lat_r          <= '0';

    elsif rising_edge(clk_i) then
      hdc_data_gnt_i_lat_r    <= hdc_data_gnt_i;

      bundle_stage_1_en_r     <= hdc_data_gnt_i_lat_r and bundle_en_r;
      bundle_stage_2_en_r     <= bundle_stage_1_en_r;

      bind_stage_1_en_r       <= hdc_data_gnt_i_lat_r and bind_en_r;
      bind_stage_2_en_r       <= bind_stage_1_en_r;

      sim_stage_1_en_r        <= hdc_data_gnt_i_lat_r and sim_en_r;

      if (HVSIZE_READ_lat = (0 to ADDR_WIDTH-1 => '0')) then
        sim_stage_2_en_r      <= sim_stage_1_en_r;
      else
        sim_stage_2_en_r      <= '0';
      end if;

      clip_stage_1_en_r       <= hdc_data_gnt_i_lat_r and clip_en_r;

      if (clip_processed_bytes = COUNTER_BITS-1) then
        clip_stage_2_en_r     <= clip_stage_1_en_r;
      else
        clip_stage_2_en_r     <= '0';
      end if;

      perm_stage_1_en_r       <= hdc_data_gnt_i_lat_r and perm_en_r;
      perm_stage_2_en_r       <= perm_stage_1_en_r;

      as_stage_1_en_r         <= hdc_data_gnt_i_lat_r and sim_en_r;
      as_stage_2_en_r         <= as_stage_1_en_r;

      if (HVSIZE_READ_lat = (0 to ADDR_WIDTH-1 => '0')) then
        as_stage_3_en_r       <= as_stage_2_en_r;
      else
        as_stage_3_en_r       <= '0';
      end if;

      halt_hdc_lat_r          <= halt_hdc;
      state_HDC_r             <= nextstate_HDC;
      busy_hdc_internal_lat_r <= busy_hdc_internal;
      busy_hdc_lat_r          <= busy_hdc;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- 2) HDC_FU_ENABLER_SYNC  (UNCHANGED BEHAVIOR)
  -----------------------------------------------------------------------------
  HDC_FU_ENABLER_SYNC : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      bundle_en_r         <= '0';
      bind_en_r           <= '0';
      sim_en_r            <= '0';
      clip_en_r           <= '0';
      perm_en_r           <= '0';
      as_en_r             <= '0';
    elsif rising_edge(clk_i) then
      bundle_en_r         <= bundle_en_wire_s;
      bind_en_r           <= bind_en_wire_s;
      sim_en_r            <= sim_en_wire_s;
      clip_en_r           <= clip_en_wire_s;
      perm_en_r           <= perm_en_wire_s;
      as_en_r             <= as_en_wire_s;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- 3) HDC_FU_ENABLER_comb  (UNCHANGED BEHAVIOR)
  -----------------------------------------------------------------------------
  HDC_FU_ENABLER_comb : process(all)
  begin
    bundle_en_wire_s <= bundle_en_r;
    bind_en_wire_s   <= bind_en_r;
    sim_en_wire_s    <= sim_en_r;
    clip_en_wire_s   <= clip_en_r;
    perm_en_wire_s   <= perm_en_r;
    as_en_wire_s     <= as_en_r;

    -- auto-clear enables when the unit is not busy
    if busy_hdc_internal = '0' then
      if bundle_en_r = '1' then bundle_en_wire_s <= '0'; end if;
      if bind_en_r   = '1' then bind_en_wire_s   <= '0'; end if;
      if sim_en_r    = '1' then sim_en_wire_s    <= '0'; end if;
      if clip_en_r   = '1' then clip_en_wire_s   <= '0'; end if;
      if perm_en_r   = '1' then perm_en_wire_s   <= '0'; end if;
      if as_en_r     = '1' then as_en_wire_s     <= '0'; end if;
    end if;

    if (unsigned(AXI_HDC_INSTR_replicate) /= 40 or
        unsigned(AXI_HDC_INSTR_replicate) /= 80 or
        busy_hdc_internal_lat_r = '1') then

      case state_HDC_r is
        when hdc_init =>
          -- arm the selected FU according to AXI_HDC_INSTR
          if AXI_HDC_INSTR(HVBUNDLE_bit_position) = '1' then
            bundle_en_wire_s <= '1';
          elsif AXI_HDC_INSTR(HVBIND_bit_position) = '1' then
            bind_en_wire_s   <= '1';
          elsif AXI_HDC_INSTR(HVSIM_bit_position) = '1' then
            sim_en_wire_s    <= '1';
          elsif AXI_HDC_INSTR(HVCLIP_bit_position) = '1' then
            clip_en_wire_s   <= '1';
          elsif AXI_HDC_INSTR(HVPERM_bit_position) = '1' then
            perm_en_wire_s   <= '1';
          elsif AXI_HDC_INSTR(HVSEARCH_bit_position) = '1' then
            as_en_wire_s     <= '1';
            sim_en_wire_s    <= '1';
          end if;

        when others =>
          null;
      end case;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Port outputs
  -----------------------------------------------------------------------------
  hdc_data_gnt_i_lat    <= hdc_data_gnt_i_lat_r;
  state_HDC             <= state_HDC_r;
  busy_hdc_internal_lat <= busy_hdc_internal_lat_r;
  busy_hdc_lat          <= busy_hdc_lat_r;
  halt_hdc_lat          <= halt_hdc_lat_r;

  bundle_stage_1_en     <= bundle_stage_1_en_r;
  bundle_stage_2_en     <= bundle_stage_2_en_r;

  bind_stage_1_en       <= bind_stage_1_en_r;
  bind_stage_2_en       <= bind_stage_2_en_r;

  sim_stage_1_en        <= sim_stage_1_en_r;
  sim_stage_2_en        <= sim_stage_2_en_r;

  clip_stage_1_en       <= clip_stage_1_en_r;
  clip_stage_2_en       <= clip_stage_2_en_r;

  perm_stage_1_en       <= perm_stage_1_en_r;
  perm_stage_2_en       <= perm_stage_2_en_r;

  as_stage_1_en         <= as_stage_1_en_r;
  as_stage_2_en         <= as_stage_2_en_r;
  as_stage_3_en         <= as_stage_3_en_r;

  bundle_en             <= bundle_en_r;
  bind_en               <= bind_en_r;
  sim_en                <= sim_en_r;
  clip_en               <= clip_en_r;
  perm_en               <= perm_en_r;
  as_en                 <= as_en_r;
end architecture;
