library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

use work.HDC_PKG.all;

entity HDCU_exec_unit is
  generic (
    ADDR_WIDTH          : natural := 16;
    SPM_NUM             : natural := 4;  
    SIMD                : natural := 2;
    COUNTER_BITS        : natural;
    COUNTERS_NUMBER     : natural;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    SIMD_WIDTH          : natural := SIMD*DATA_WIDTH;
    SIMD_RD_BYTES       : integer := SIMD*DATA_WIDTH/8;
    C_S_AXI_DATA_WIDTH  : integer := 32
  );
  port (
    -- Clk/Reset
    clk_i, rst_ni : in std_logic;

    -- State / control
    state_HDC               : in  std_logic_vector(1 downto 0);
    busy_hdc_internal_lat   : in  std_logic;
    wb_ready                : in  std_logic;
    hdc_data_gnt_i          : in  std_logic;
    halt_hdc                : in  std_logic;
    halt_hdc_lat            : in  std_logic;
    bundle_processed_bytes  : in  integer;
    as_stage_3_en           : in  std_logic;
    recover_state_wires     : in  std_logic;

    -- AXI mirrors (inputs)
    AXI_HVSIZE              : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_HVCLASS             : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RS1                 : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RS2                 : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RD                  : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_HDC_INSTR           : in  std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
    AXI_HDC_INSTR_replicate : in  std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);

    -- SPM select maps (inputs)
    rs1_to_sc               : in  std_logic_vector(SPM_NUM-1 downto 0);
    rs2_to_sc               : in  std_logic_vector(SPM_NUM-1 downto 0);
    rd_to_sc                : in  std_logic_vector(SPM_NUM-1 downto 0);

    -- Writeback datapath (input)
    hdc_sc_data_write_wire_int 	: in  std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);


    -- Outputs (latched working copies and control)
    recover_state              : out std_logic;
    hdc_rs1_to_sc              : out std_logic_vector(SPM_NUM-1 downto 0);
    hdc_rs2_to_sc              : out std_logic_vector(SPM_NUM-1 downto 0);
    hdc_rd_to_sc               : out std_logic_vector(SPM_NUM-1 downto 0);

    AXI_HDC_INSTR_replicate_lat : out std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);

    AXI_RS1_lat                : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RS2_lat                : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RD_lat                 : out std_logic_vector(ADDR_WIDTH-1 downto 0);

    HVSIZE_READ                : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    HVSIZE_READ_lat            : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    HVSIZE_WRITE               : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    AMSIZE_READ                : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AMSIZE_READ_lat            : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    head_ptr_encoded_hv        : out std_logic_vector(31 downto 0);
    class_index                : out integer;

    first_perm_source_addr     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    first_perm_dest_addr       : out std_logic_vector(ADDR_WIDTH-1 downto 0);

    hdc_sc_data_write_int      : out std_logic_vector(SIMD*DATA_WIDTH-1 downto 0)
  );
end entity;

architecture rtl of HDCU_exec_unit is
  -- local registers
  signal AXI_RS1_lat_r, AXI_RS2_lat_r     : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
  signal AXI_RD_lat_r                     : std_logic_vector(ADDR_WIDTH-1 downto 0)        := (others => '0');

  signal HVSIZE_READ_r, HVSIZE_READ_lat_r : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
  signal HVSIZE_WRITE_r                   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

  signal AMSIZE_READ_r, AMSIZE_READ_lat_r : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

  signal AXI_HDC_INSTR_replicate_lat_r    : std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0) := (others => '0');

  signal head_ptr_encoded_hv_r            : std_logic_vector(31 downto 0) := (others => '0');
  signal class_index_r                    : integer := 0;

  signal first_perm_source_addr_r         : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
  signal first_perm_dest_addr_r           : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');

  signal recover_state_r                  : std_logic := '0';
  signal hdc_sc_data_write_int_r          : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0) := (others => '0');

  signal hdc_rs1_to_sc_r, hdc_rs2_to_sc_r, hdc_rd_to_sc_r
                                          : std_logic_vector(SPM_NUM-1 downto 0) := (others => '0');
begin
  -- Drive outputs
  AXI_RS1_lat            <= AXI_RS1_lat_r;
  AXI_RS2_lat            <= AXI_RS2_lat_r;
  AXI_RD_lat             <= AXI_RD_lat_r;

  HVSIZE_READ            <= HVSIZE_READ_r;
  HVSIZE_READ_lat        <= HVSIZE_READ_lat_r;
  HVSIZE_WRITE           <= HVSIZE_WRITE_r;

  AMSIZE_READ            <= AMSIZE_READ_r;
  AMSIZE_READ_lat        <= AMSIZE_READ_lat_r;

  AXI_HDC_INSTR_replicate_lat <= AXI_HDC_INSTR_replicate_lat_r;

  head_ptr_encoded_hv    <= head_ptr_encoded_hv_r;
  class_index            <= class_index_r;

--  first_perm_source_addr <= first_perm_source_addr_r;
  first_perm_source_addr <= (others => '0');
--  first_perm_dest_addr   <= first_perm_dest_addr_r;
  first_perm_dest_addr   <= (others => '0');

  recover_state          <= recover_state_r;
  hdc_sc_data_write_int  <= hdc_sc_data_write_int_r;

  hdc_rs1_to_sc          <= hdc_rs1_to_sc_r;
  hdc_rs2_to_sc          <= hdc_rs2_to_sc_r;
  hdc_rd_to_sc           <= hdc_rd_to_sc_r;

  -- The original exec process, unchanged (just using the *_r regs / ports)
  HDC_Exec_Unit : process(clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      recover_state_r <= '0';
      hdc_rs1_to_sc_r <= (others => '0');
      hdc_rs2_to_sc_r <= (others => '0');
      hdc_rd_to_sc_r  <= (others => '0');

      AXI_RS1_lat_r   <= (others => '0');
      AXI_RS2_lat_r   <= (others => '0');
      AXI_RD_lat_r    <= (others => '0');

      HVSIZE_READ_r      <= (others => '0');
      HVSIZE_READ_lat_r  <= (others => '0');

      HVSIZE_WRITE_r     <= (others => '0');

      AMSIZE_READ_r      <= (others => '0');
      AMSIZE_READ_lat_r  <= (others => '0');

      AXI_HDC_INSTR_replicate_lat_r <= (others => '0');
      head_ptr_encoded_hv_r         <= (others => '0');
      class_index_r                 <= 0;

      first_perm_source_addr_r      <= (others => '0');
      first_perm_dest_addr_r        <= (others => '0');

      hdc_sc_data_write_int_r       <= (others => '0');

    elsif rising_edge(clk_i) then
      HVSIZE_READ_lat_r <= HVSIZE_READ_r;


      if unsigned(AXI_HDC_INSTR_replicate) /= 0 or
         (AXI_HDC_INSTR_replicate(HVMEMLD_bit_position) /= '1' and
          AXI_HDC_INSTR_replicate(HVMEMSTR_bit_position) /= '1') or
         busy_hdc_internal_lat = '1' then

        case state_HDC is
          when hdc_init =>
            AXI_HDC_INSTR_replicate_lat_r <= AXI_HDC_INSTR_replicate(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);

            -- if AXI_HDC_INSTR_replicate(HVPERM_bit_position) = '1' then
            --   AXI_RD_lat_r <= std_logic_vector(unsigned(AXI_RD(ADDR_WIDTH-1 downto 0)) + to_unsigned(SIMD_RD_BYTES, ADDR_WIDTH));
            -- else
            --   AXI_RD_lat_r <= AXI_RD(ADDR_WIDTH-1 downto 0);
            -- end if;

            -- if AXI_HDC_INSTR_replicate(HVPERM_bit_position) = '1' then
            --   first_perm_source_addr_r <= AXI_RS1(ADDR_WIDTH-1 downto 0);
            --   first_perm_dest_addr_r   <= AXI_RD(ADDR_WIDTH-1 downto 0);
            -- end if;

			if (AXI_HDC_INSTR_replicate(HVPERM_bit_position) = '1') then
              AXI_RD_lat_r  <= std_logic_vector(unsigned(AXI_RD(ADDR_WIDTH-1 downto 0)) + resize((SIMD_RD_BYTES) * (unsigned(AXI_RS2_lat_r)), AXI_RD_lat_r'length)); -- source 1 address increment
            else
              AXI_RD_lat_r <= AXI_RD(ADDR_WIDTH-1 downto 0);
            end if;

            hdc_rs1_to_sc_r <= rs1_to_sc;
            hdc_rs2_to_sc_r <= rs2_to_sc;
            hdc_rd_to_sc_r  <= rd_to_sc;

            -- HVSIZE_WRITE Initialization
            if AXI_HDC_INSTR_replicate(HVBUNDLE_bit_position) = '1' then
              HVSIZE_WRITE_r <= std_logic_vector(resize(unsigned(AXI_HVSIZE) * Data_Width/COUNTERS_NUMBER, HVSIZE_WRITE_r'length));
            elsif AXI_HDC_INSTR_replicate(HVSIM_bit_position) = '1' then
              HVSIZE_WRITE_r <= std_logic_vector(to_unsigned(4, HVSIZE_WRITE_r'length));
            elsif AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' then
              HVSIZE_WRITE_r <= std_logic_vector(to_unsigned(4, HVSIZE_WRITE_r'length));
              AMSIZE_READ_r      <= std_logic_vector(resize(unsigned(AXI_HVSIZE), AMSIZE_READ_r'length));
              AMSIZE_READ_lat_r  <= std_logic_vector(resize(unsigned(AXI_HVSIZE), AMSIZE_READ_lat_r'length));
			elsif AXI_HDC_INSTR_replicate(HVPERM_bit_position) = '1' then
				-- axihvsize - simdreadbites
				HVSIZE_WRITE_r <= std_logic_vector(resize(unsigned(AXI_HVSIZE) - SIMD_RD_BYTES, HVSIZE_WRITE_r'length));
            else
              HVSIZE_WRITE_r <= AXI_HVSIZE;
            end if;

            -- Addresses init when grant
            if hdc_data_gnt_i = '1' then
              -- RS1
              if AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' and
                 to_integer(unsigned(AXI_HVSIZE)) <= SIMD_RD_BYTES then
                AXI_RS1_lat_r <= AXI_RS1;
              else
                AXI_RS1_lat_r <= std_logic_vector(unsigned(AXI_RS1));
              end if;

              -- RS2
              if AXI_HDC_INSTR_replicate(HVBUNDLE_bit_position) = '1' then
                AXI_RS2_lat_r <= AXI_RS2;
              else
                if AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' and
                   to_integer(unsigned(AXI_HVSIZE)) < SIMD_RD_BYTES then
                  AXI_RS2_lat_r <= std_logic_vector(unsigned(AXI_RS2) + unsigned(AXI_HVSIZE));
                else
                  AXI_RS2_lat_r <= std_logic_vector(unsigned(AXI_RS2));
                end if;
              end if;

              -- HVSIZE_READ init
              if (AXI_HDC_INSTR_replicate(HVBUNDLE_bit_position) = '1' or
                  AXI_HDC_INSTR_replicate(HVCLIP_bit_position)   = '1') then

                if (unsigned(AXI_HVSIZE) * to_unsigned(Data_Width/COUNTERS_NUMBER, AXI_HVSIZE'length)) >= SIMD_RD_BYTES then
                  HVSIZE_READ_r <= std_logic_vector(resize(unsigned(AXI_HVSIZE) * Data_Width/COUNTERS_NUMBER, HVSIZE_READ_r'length));
                else
                  HVSIZE_READ_r <= (others => '0');
                end if;

            --   elsif AXI_HDC_INSTR_replicate(HVPERM_bit_position) = '1' then
            --     if unsigned(AXI_HVSIZE) >= SIMD_RD_BYTES then
            --       HVSIZE_READ_r <= AXI_HVSIZE;
            --     else
            --       HVSIZE_READ_r     <= std_logic_vector(to_unsigned(SIMD_RD_BYTES, HVSIZE_READ_r'length));
            --       HVSIZE_READ_lat_r <= std_logic_vector(to_unsigned(SIMD_RD_BYTES, HVSIZE_READ_lat_r'length));
            --     end if;

              elsif AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' then
            --    HVSIZE_READ_r     <= std_logic_vector(resize(unsigned(AXI_HVSIZE) * unsigned(AXI_HVCLASS), HVSIZE_READ_r'length));
                HVSIZE_READ_r     <= std_logic_vector(resize(unsigned(AXI_HVCLASS), HVSIZE_READ_r'length));
                head_ptr_encoded_hv_r <= AXI_RS1;
              else
                HVSIZE_READ_r <= std_logic_vector(unsigned(AXI_HVSIZE));
              end if;

            else
              AXI_RS1_lat_r <= AXI_RS1;
              AXI_RS2_lat_r <= AXI_RS2;

              if AXI_HDC_INSTR_replicate(HVBUNDLE_bit_position) = '1' or
                 AXI_HDC_INSTR_replicate(HVCLIP_bit_position)   = '1' then
                HVSIZE_READ_r <= std_logic_vector(resize(unsigned(AXI_HVSIZE) * Data_Width/COUNTERS_NUMBER, HVSIZE_READ_r'length));
              elsif AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' then
            --    HVSIZE_READ_r <= std_logic_vector(resize(unsigned(AXI_HVSIZE) * unsigned(AXI_HVCLASS), HVSIZE_READ_r'length));
                HVSIZE_READ_r <= std_logic_vector(resize(unsigned(AXI_HVCLASS), HVSIZE_READ_r'length));
                head_ptr_encoded_hv_r <= AXI_RS1;
              else
                HVSIZE_READ_r <= AXI_HVSIZE;
              end if;
            end if;

          when hdc_exec =>
            recover_state_r <= recover_state_wires;

            hdc_rs1_to_sc_r <= rs1_to_sc;
            hdc_rs2_to_sc_r <= rs2_to_sc;
            hdc_rd_to_sc_r  <= rd_to_sc;

            if halt_hdc = '1' and halt_hdc_lat = '0' then
              hdc_sc_data_write_int_r <= hdc_sc_data_write_wire_int;
            end if;

            if halt_hdc = '0' then
              -- HVSIZE_WRITE + RD update on WB
              if wb_ready = '1' then
				if (AXI_HDC_INSTR_replicate(HVPERM_bit_position) = '1') then
					-- When we reach the last hdcu_in_perm_operand_1 chunk, we reset the destination address to the original one
					if (HVSIZE_READ_lat_r = std_logic_vector(resize((SIMD_RD_BYTES) * (unsigned(AXI_RS2)), HVSIZE_READ_lat_r'length))) then
						AXI_RD_lat_r  <= AXI_RD(ADDR_WIDTH-1 downto 0);
					else
						AXI_RD_lat_r  <= std_logic_vector(unsigned(AXI_RD_lat_r) + SIMD_RD_BYTES); -- destination address increment
					end if;
				else
                	AXI_RD_lat_r <= std_logic_vector(unsigned(AXI_RD_lat_r) + SIMD_RD_BYTES);
				end if;
                if to_integer(unsigned(HVSIZE_WRITE_r)) >= SIMD_RD_BYTES then
                  HVSIZE_WRITE_r <= std_logic_vector(unsigned(HVSIZE_WRITE_r) - SIMD_RD_BYTES);
                else
                  HVSIZE_WRITE_r <= (others => '0');
                end if;
              end if;

              -- class index update for search (small)
              if AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' and
                 to_integer(unsigned(AMSIZE_READ_lat_r)) = 0 and as_stage_3_en = '0' then
                if to_integer(unsigned(AMSIZE_READ_r)) = 0 then
                  class_index_r <= class_index_r;
                else
                  class_index_r <= (class_index_r + 1);
                end if;
              end if;

              -- RS* increments when reading
              if to_integer(unsigned(HVSIZE_READ_r)) >= SIMD_RD_BYTES and hdc_data_gnt_i = '1' then
                -- RS1
                if AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' then
                  if (to_integer(unsigned(AMSIZE_READ_lat_r)) = 2*SIMD_RD_BYTES and
                      to_integer(unsigned(HVSIZE_READ_lat_r)) > to_integer(unsigned(AXI_HVSIZE))) or
                      to_integer(unsigned(AXI_HVSIZE)) = SIMD_RD_BYTES then
                    AXI_RS1_lat_r <= head_ptr_encoded_hv_r;
                  elsif to_integer(unsigned(AXI_HVSIZE) - SIMD_RD_BYTES) = SIMD_RD_BYTES and
                        to_integer(unsigned(AMSIZE_READ_lat_r)) = 0 then
                    AXI_RS1_lat_r <= head_ptr_encoded_hv_r;
                  else
                    AXI_RS1_lat_r <= std_logic_vector(unsigned(AXI_RS1_lat_r) + SIMD_RD_BYTES);
                  end if;
                else
                  AXI_RS1_lat_r <= std_logic_vector(unsigned(AXI_RS1_lat_r) + SIMD_RD_BYTES);
                end if;

                -- RS2
                if AXI_HDC_INSTR_replicate(HVBUNDLE_bit_position) = '1' then
                  if bundle_processed_bytes = (COUNTER_BITS-1)-2 then
                    AXI_RS2_lat_r <= std_logic_vector(unsigned(AXI_RS2_lat_r) + SIMD_RD_BYTES);
                  end if;
                elsif AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' and
                      to_integer(unsigned(AXI_HVSIZE)) < SIMD_RD_BYTES then
                  AXI_RS2_lat_r <= std_logic_vector(unsigned(AXI_RS2_lat_r) + unsigned(AXI_HVSIZE));
                else
                  AXI_RS2_lat_r <= std_logic_vector(unsigned(AXI_RS2_lat_r) + SIMD_RD_BYTES);
                end if;

              else
                if AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' and
                   to_integer(unsigned(AXI_HVSIZE)) < SIMD_RD_BYTES then
                  if to_integer(unsigned(AMSIZE_READ_r)) = 0 and as_stage_3_en = '0' then
                    class_index_r <= (class_index_r + 1);
                  end if;
                  AXI_RS2_lat_r <= std_logic_vector(unsigned(AXI_RS2_lat_r) + unsigned(AXI_HVSIZE));
                end if;
              end if;

              AMSIZE_READ_lat_r <= AMSIZE_READ_r;

              -- HVSIZE_READ decrements
              if hdc_data_gnt_i = '1' then
                if to_integer(unsigned(HVSIZE_READ_r)) >= SIMD_RD_BYTES then
                  HVSIZE_READ_r <= std_logic_vector(unsigned(HVSIZE_READ_r) - SIMD_RD_BYTES);

                  if AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' then
                    if to_integer(unsigned(AMSIZE_READ_r)) >= SIMD_RD_BYTES then
                      AMSIZE_READ_r <= std_logic_vector(unsigned(AMSIZE_READ_r) - SIMD_RD_BYTES);
                    else
                      AMSIZE_READ_r <= std_logic_vector(resize(unsigned(AXI_HVSIZE) - SIMD_RD_BYTES, AMSIZE_READ_r'length));
                    end if;
                  end if;

                else
                  if AXI_HDC_INSTR_replicate(HVSEARCH_bit_position) = '1' then
                    HVSIZE_READ_r <= std_logic_vector(unsigned(HVSIZE_READ_r) - unsigned(AXI_HVSIZE));
                    AMSIZE_READ_r <= (others => '0');
                  else
                    HVSIZE_READ_r <= (others => '0');
                  end if;
                end if;

                if SIMD_RD_BYTES > to_integer(unsigned(AXI_HVSIZE)) then
                  HVSIZE_READ_r <= std_logic_vector(unsigned(HVSIZE_READ_r) - unsigned(AXI_HVSIZE));
                end if;
              end if;
            end if;

          when others =>
            null;
        end case;
      end if;
    end if;
  end process;
end architecture;
