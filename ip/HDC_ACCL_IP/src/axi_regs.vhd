library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

-- If you already have HDC_PKG in your project it’s fine to keep this.
-- (Not strictly required by this module, but harmless.)
use work.HDC_PKG.all;

entity HDCU_axi_regs is
  generic (
    ADDR_WIDTH          : natural; 
	SPM_NUM             : natural := 4;  
    SIMD                : natural := 2;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    SIMD_WIDTH          : natural := SIMD*DATA_WIDTH;
    C_S_AXI_DATA_WIDTH  : integer := 32;
    C_S_AXI_ADDR_WIDTH  : integer := 7
  );
  port (
    ----------------------------------------------------------------
    -- AXI4-Lite Slave Interface
    ----------------------------------------------------------------
    S_AXI_ACLK    : in  std_logic;
    S_AXI_ARESETN : in  std_logic;

    S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
    S_AXI_AWVALID : in  std_logic;
    S_AXI_AWREADY : out std_logic;

    S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    S_AXI_WVALID  : in  std_logic;
    S_AXI_WREADY  : out std_logic;

    S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_BVALID  : out std_logic;
    S_AXI_BREADY  : in  std_logic;

    S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
    S_AXI_ARVALID : in  std_logic;
    S_AXI_ARREADY : out std_logic;

    S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_RVALID  : out std_logic;
    S_AXI_RREADY  : in  std_logic;

    ------------------------------------------------------------
    -- AXI register file (outputs to the rest of the design)
    ------------------------------------------------------------
    AXI_HVSIZE                  : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_HVTYPE                  : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RS1                     : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RS2                     : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RD                      : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_HDC_INSTR               : out std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
    AXI_HDC_INSTR_replicate     : out std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
    AXI_HVCLASS                 : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_HDC_REQ                 : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RSIZE                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_WSIZE                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_INTERRUPT               : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_SIMD_VALUE              : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_SPM_NUM_VALUE           : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg13                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg14                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg15                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg16                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg17                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg18                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg19                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg20                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg21                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg22                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg23                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg24                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg25                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg26                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg27                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg28                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg29                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    slv_reg30                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_TEST                   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    axi_test_written           : out std_logic;  -- Pulse when AXI_TEST is written

    ----------------------------------------------------------------
    -- PERFORMANCE COUNTER INPUTS (from functional units)
    ----------------------------------------------------------------
    perf_bundle_count_i        : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    perf_bind_count_i          : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    perf_sim_count_i           : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    perf_clip_count_i          : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    perf_perm_count_i          : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    perf_as_count_i            : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0)
  );
end HDCU_axi_regs;

architecture rtl of HDCU_axi_regs is
  ----------------------------------------------------------------
  -- AXI interface internals
  ----------------------------------------------------------------
  signal axi_awaddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
  signal axi_awready : std_logic;
  signal axi_wready  : std_logic;
  signal axi_bresp   : std_logic_vector(1 downto 0);
  signal axi_bvalid  : std_logic;
  signal axi_araddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
  signal axi_arready : std_logic;
  signal axi_rdata   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal axi_rresp   : std_logic_vector(1 downto 0);
  signal axi_rvalid  : std_logic;

  constant ADDR_LSB          : integer := (C_S_AXI_DATA_WIDTH/32) + 1;
  constant OPT_MEM_ADDR_BITS : integer := 4;

  signal slv_reg_rden : std_logic;
  signal slv_reg_wren : std_logic;
  signal reg_data_out : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal aw_en        : std_logic;
  signal byte_index   : integer;

  ----------------------------------------------------------------
  -- Internal mirrors of AXI registers (read/write internally)
  ----------------------------------------------------------------
  signal r_AXI_HVSIZE              : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_HVTYPE              : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_RS1                 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_RS2                 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_RD                  : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_HDC_INSTR           : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_HDC_INSTR_replicate : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_HVCLASS             : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_HDC_REQ             : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_RSIZE               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_WSIZE               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_INTERRUPT           : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_SIMD_VALUE          : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_SPM_NUM_VALUE       : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg13               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg14               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg15               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg16               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg17               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg18               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg19               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

  ----------------------------------------------------------------
  -- PERFORMANCE COUNTER INTERNAL SIGNALS
  ----------------------------------------------------------------
  -- These registers will be updated from the performance counter inputs
  -- slv_reg13-18 are now used for performance counters (read-only from AXI perspective)
  ----------------------------------------------------------------
  signal r_slv_reg20               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg21               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg22               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg23               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg24               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg25               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg26               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg27               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg28               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg29               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_slv_reg30               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal r_AXI_TEST               : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  
  -- Signal to detect AXI_TEST write
  signal axi_test_write_detected   : std_logic;

begin


  -- read only register
  r_AXI_SIMD_VALUE      <= std_logic_vector(to_unsigned(SIMD, C_S_AXI_DATA_WIDTH));
  r_AXI_SPM_NUM_VALUE   <= std_logic_vector(to_unsigned(SPM_NUM, C_S_AXI_DATA_WIDTH));

  ----------------------------------------------------------------
  -- External AXI signals
  ----------------------------------------------------------------
  S_AXI_AWREADY <= axi_awready;
  S_AXI_WREADY  <= axi_wready;
  S_AXI_BRESP   <= axi_bresp;
  S_AXI_BVALID  <= axi_bvalid;
  S_AXI_ARREADY <= axi_arready;
  S_AXI_RDATA   <= axi_rdata;
  S_AXI_RRESP   <= axi_rresp;
  S_AXI_RVALID  <= axi_rvalid;

  ----------------------------------------------------------------
  -- Write address handshake
  ----------------------------------------------------------------
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_awready <= '0';
        aw_en       <= '1';
      else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
          axi_awready <= '1';
          aw_en       <= '0';
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
          axi_awready <= '0';
          aw_en       <= '1';
        else
          axi_awready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Latch AWADDR
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_awaddr <= (others => '0');
      else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
          axi_awaddr <= S_AXI_AWADDR;
        end if;
      end if;
    end if;
  end process;

  -- WREADY
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_wready <= '0';
      else
        if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
          axi_wready <= '1';
        else
          axi_wready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Write enable
  slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID;

  -- Register writes
  process (S_AXI_ACLK)
    variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
  begin
    if rising_edge(S_AXI_ACLK) then
      -- one-shot bus write strobe mirror
      r_AXI_HDC_INSTR <= (others => '0');

      -- Set the write detection signal
      axi_test_write_detected <=  (or r_AXI_HVSIZE)     or 
                                  (or r_AXI_RS1)        or 
                                  (or r_AXI_RS2)        or 
                                  (or r_AXI_RD)         or 
                                  (or r_AXI_HDC_INSTR)  or 
                                  (or r_AXI_RSIZE)      or 
                                  (or r_AXI_WSIZE)      or 
                                  (or r_AXI_SIMD_VALUE)  or 
                                  (or r_AXI_TEST);

      if S_AXI_ARESETN = '0' then
        r_AXI_HVSIZE  <= (others => '0');
        r_AXI_HVTYPE  <= (others => '0');
        r_AXI_RS1     <= (others => '0');
        r_AXI_RS2     <= (others => '0');
        r_AXI_RD      <= (others => '0');
        r_AXI_HDC_INSTR_replicate <= (others => '0');
        r_AXI_HVCLASS <= (others => '0');
        r_AXI_HDC_REQ <= (others => '0');
        r_AXI_RSIZE   <= (others => '0');
        r_AXI_WSIZE   <= (others => '0');
        r_AXI_INTERRUPT   <= (others => '0');
        -- r_slv_reg13-18 are managed by performance counter process
        r_slv_reg19   <= (others => '0');
        r_slv_reg20   <= (others => '0');
        r_slv_reg21   <= (others => '0');
        r_slv_reg22   <= (others => '0');
        r_slv_reg23   <= (others => '0');
        r_slv_reg24   <= (others => '0');
        r_slv_reg25   <= (others => '0');
        r_slv_reg26   <= (others => '0');
        r_slv_reg27   <= (others => '0');
        r_slv_reg28   <= (others => '0');
        r_slv_reg29   <= (others => '0');
        r_slv_reg30   <= (others => '0');
        r_AXI_TEST   <= (others => '0');
        axi_test_write_detected <= '0';
      else
        
        loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        if (slv_reg_wren = '1') then
          case loc_addr is
            when b"00000" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_HVSIZE(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"00001" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_HVTYPE(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"00010" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_RS1(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"00011" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_RS2(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"00100" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_RD(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"00101" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_HDC_INSTR(byte_index*8+7 downto byte_index*8)           <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                  r_AXI_HDC_INSTR_replicate(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"00110" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_HVCLASS(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"00111" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_HDC_REQ(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"01000" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_RSIZE(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"01001" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_WSIZE(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"01010" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_INTERRUPT(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"01011" =>
              -- for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
              --   if (S_AXI_WSTRB(byte_index) = '1') then
              --     r_AXI_SPM_NUM_VALUE(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
              --   end if;
              -- end loop;
            when b"01100" =>
              --for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
              --  if (S_AXI_WSTRB(byte_index) = '1') then
              --    r_slv_reg12(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
              --  end if;
              --end loop;
            when b"01101" =>
              -- Performance counter register (read-only, updated from perf_bundle_count_i)
              -- No write operation allowed
              null;
            when b"01110" =>
              -- Performance counter register (read-only, updated from perf_bind_count_i)
              -- No write operation allowed
              null;
            when b"01111" =>
              -- Performance counter register (read-only, updated from perf_sim_count_i)
              -- No write operation allowed
              null;
            when b"10000" =>
              -- Performance counter register (read-only, updated from perf_clip_count_i)
              -- No write operation allowed
              null;
            when b"10001" =>
              -- Performance counter register (read-only, updated from perf_perm_count_i)
              -- No write operation allowed
              null;
            when b"10010" =>
              -- Performance counter register (read-only, updated from perf_as_count_i)
              -- No write operation allowed
              null;
            when b"10011" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg19(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"10100" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg20(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"10101" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg21(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"10110" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg22(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"10111" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg23(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"11000" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg24(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"11001" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg25(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"11010" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg26(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"11011" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg27(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"11100" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg28(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"11101" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg29(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"11110" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_slv_reg30(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"11111" =>
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if (S_AXI_WSTRB(byte_index) = '1') then
                  r_AXI_TEST(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
              
            when others =>
              -- keep values (no action needed)
              null;
          end case;
        end if;
      end if;
    end if;
  end process;

  -- Write response
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_bvalid <= '0';
        axi_bresp  <= "00";
      else
        if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0') then
          axi_bvalid <= '1';
          axi_bresp  <= "00";
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
          axi_bvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  -- ARREADY + ARADDR
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_arready <= '0';
        axi_araddr  <= (others => '1');
      else
        if (axi_arready = '0' and S_AXI_ARVALID = '1') then
          axi_arready <= '1';
          axi_araddr  <= S_AXI_ARADDR;
        else
          axi_arready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- RVALID / RRESP
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_rvalid <= '0';
        axi_rresp  <= "00";
      else
        if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
          axi_rvalid <= '1';
          axi_rresp  <= "00";
        elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
          axi_rvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Read mux (uses internal mirrors)
  process ( all)
    variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
  begin
    loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
    case loc_addr is
      when b"00000" => reg_data_out <= r_AXI_HVSIZE;
      when b"00001" => reg_data_out <= r_AXI_HVTYPE;
      when b"00010" => reg_data_out <= r_AXI_RS1;
      when b"00011" => reg_data_out <= r_AXI_RS2;
      when b"00100" => reg_data_out <= r_AXI_RD;
      when b"00101" => reg_data_out <= r_AXI_HDC_INSTR;
      when b"00110" => reg_data_out <= r_AXI_HVCLASS;
      when b"00111" => reg_data_out <= r_AXI_HDC_REQ;
      when b"01000" => reg_data_out <= r_AXI_RSIZE;
      when b"01001" => reg_data_out <= r_AXI_WSIZE;
      when b"01010" => reg_data_out <= r_AXI_INTERRUPT;
      when b"01011" => reg_data_out <= r_AXI_SIMD_VALUE;
      when b"01100" => reg_data_out <= r_AXI_SPM_NUM_VALUE;
      when b"01101" => reg_data_out <= r_slv_reg13;
      when b"01110" => reg_data_out <= r_slv_reg14;
      when b"01111" => reg_data_out <= r_slv_reg15;
      when b"10000" => reg_data_out <= r_slv_reg16;
      when b"10001" => reg_data_out <= r_slv_reg17;
      when b"10010" => reg_data_out <= r_slv_reg18;
      when b"10011" => reg_data_out <= r_slv_reg19;
      when b"10100" => reg_data_out <= r_slv_reg20;
      when b"10101" => reg_data_out <= r_slv_reg21;
      when b"10110" => reg_data_out <= r_slv_reg22;
      when b"10111" => reg_data_out <= r_slv_reg23;
      when b"11000" => reg_data_out <= r_slv_reg24;
      when b"11001" => reg_data_out <= r_slv_reg25;
      when b"11010" => reg_data_out <= r_slv_reg26;
      when b"11011" => reg_data_out <= r_slv_reg27;
      when b"11100" => reg_data_out <= r_slv_reg28;
      when b"11101" => reg_data_out <= r_slv_reg29;
      when b"11110" => reg_data_out <= r_slv_reg30;
      when b"11111" => reg_data_out <= r_AXI_TEST;
      when others  => reg_data_out <= (others => '0');
    end case;
  end process;

  -- Output register read
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_rdata <= (others => '0');
      else
        if (slv_reg_rden = '1') then
          axi_rdata <= reg_data_out;
        end if;
      end if;
    end if;
  end process;

  -- Read enable
  slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid);

  ----------------------------------------------------------------
  -- PERFORMANCE COUNTER UPDATE PROCESS
  -- Updates slv_reg13-18 with performance counter values
  ----------------------------------------------------------------
  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        r_slv_reg13 <= (others => '0');
        r_slv_reg14 <= (others => '0');
        r_slv_reg15 <= (others => '0');
        r_slv_reg16 <= (others => '0');
        r_slv_reg17 <= (others => '0');
        r_slv_reg18 <= (others => '0');
      else
        -- Copy performance counter values to AXI registers
        r_slv_reg13 <= perf_bundle_count_i;
        r_slv_reg14 <= perf_bind_count_i;
        r_slv_reg15 <= perf_sim_count_i;
        r_slv_reg16 <= perf_clip_count_i;
        r_slv_reg17 <= perf_perm_count_i;
        r_slv_reg18 <= perf_as_count_i;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------
  -- Drive top-level outputs from internal mirrors
  ----------------------------------------------------------------
  AXI_HVSIZE              <= r_AXI_HVSIZE;
  AXI_HVTYPE              <= r_AXI_HVTYPE;
  AXI_RS1                 <= r_AXI_RS1;
  AXI_RS2                 <= r_AXI_RS2;
  AXI_RD                  <= r_AXI_RD;
  AXI_HDC_INSTR           <= r_AXI_HDC_INSTR(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
  AXI_HDC_INSTR_replicate <= r_AXI_HDC_INSTR_replicate(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
  AXI_HVCLASS             <= r_AXI_HVCLASS;
  AXI_HDC_REQ             <= r_AXI_HDC_REQ;
  AXI_RSIZE               <= r_AXI_RSIZE;
  AXI_WSIZE               <= r_AXI_WSIZE;
  AXI_INTERRUPT           <= r_AXI_INTERRUPT;
  AXI_SIMD_VALUE          <= r_AXI_SIMD_VALUE;
  AXI_SPM_NUM_VALUE       <= r_AXI_SPM_NUM_VALUE;
  slv_reg13               <= r_slv_reg13;
  slv_reg14               <= r_slv_reg14;
  slv_reg15               <= r_slv_reg15;
  slv_reg16               <= r_slv_reg16;
  slv_reg17               <= r_slv_reg17;
  slv_reg18               <= r_slv_reg18;
  slv_reg19               <= r_slv_reg19;
  slv_reg20               <= r_slv_reg20;
  slv_reg21               <= r_slv_reg21;
  slv_reg22               <= r_slv_reg22;
  slv_reg23               <= r_slv_reg23;
  slv_reg24               <= r_slv_reg24;
  slv_reg25               <= r_slv_reg25;
  slv_reg26               <= r_slv_reg26;
  slv_reg27               <= r_slv_reg27;
  slv_reg28               <= r_slv_reg28;
  slv_reg29               <= r_slv_reg29;
  slv_reg30               <= r_slv_reg30;
  AXI_TEST                <= r_AXI_TEST;
  axi_test_written        <= axi_test_write_detected;

end rtl;
