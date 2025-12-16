library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;


use work.HDC_PKG.all;

entity HDCU_exception_ctrl is
  generic (
    C_S_AXI_DATA_WIDTH  : integer := 32;
    ADDR_WIDTH          : natural := 32;
    SPM_NUM             : natural := 4;  
    SIMD                : natural := 2;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    SIMD_WIDTH          : natural := SIMD*DATA_WIDTH;
    SIMD_RD_BYTES       : integer := SIMD*DATA_WIDTH/8
  );
  port (
    ----------------------------------------------------------------
    -- Inputs from AXI mirror registers
    ----------------------------------------------------------------
    AXI_HVSIZE                  : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RS1                     : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RS2                     : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RD                      : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_HDC_INSTR               : in  std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
    AXI_HDC_INSTR_replicate     : in  std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
    AXI_HVCLASS                 : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_HDC_REQ                 : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RSIZE                   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_WSIZE                   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_HDC_INSTR_replicate_lat : in std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
    HVSIZE_READ_lat             : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    first_perm_source_addr      : in std_logic_vector(ADDR_WIDTH-1 downto 0);
	first_perm_dest_addr        : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    ----------------------------------------------------------------
    -- Latched/working copies from Exec unit (used as READS here)
    ----------------------------------------------------------------
    AXI_RS1_lat                 : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RS2_lat                 : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RD_lat                  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    HVSIZE_READ                 : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    HVSIZE_WRITE                : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

    ----------------------------------------------------------------
    -- State / grants / enables used by this comb block
    ----------------------------------------------------------------
    state_HDC                   : in  std_logic_vector(1 downto 0);
    busy_hdc_internal_lat       : in  std_logic;
    hdc_sci_wr_gnt              : in  std_logic;
    hdc_data_gnt_i              : in  std_logic;

    -- stage enables
    bundle_stage_2_en           : in  std_logic := '0';
    bind_stage_2_en             : in  std_logic := '0';
    sim_stage_2_en              : in  std_logic := '0';
    clip_stage_2_en             : in  std_logic := '0';
    perm_stage_1_en             : in  std_logic := '0';
    perm_stage_2_en             : in  std_logic := '0';
    as_stage_3_en               : in  std_logic := '0';

    ----------------------------------------------------------------
    -- Scratchpad selections (as used by the monolith)
    ----------------------------------------------------------------
    rs1_to_sc                   : in  std_logic_vector(SPM_NUM-1 downto 0);
    rs2_to_sc                   : in  std_logic_vector(SPM_NUM-1 downto 0);
    rd_to_sc                    : in  std_logic_vector(SPM_NUM-1 downto 0);

    -- The exec unit’s “latched” selects (names used inside logic)
    hdc_rs1_to_sc               : in  std_logic_vector(SPM_NUM-1 downto 0);
    hdc_rs2_to_sc               : in  std_logic_vector(SPM_NUM-1 downto 0);
    hdc_rd_to_sc                : in  std_logic_vector(SPM_NUM-1 downto 0);

    ----------------------------------------------------------------
    -- Sticky/latched flags read by this comb logic
    ----------------------------------------------------------------
    recover_state               : in  std_logic;
    hdc_except_data             : in  std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Datapath characteristic
    ----------------------------------------------------------------

    ----------------------------------------------------------------
    -- Outputs to the rest of the design (comb results)
    ----------------------------------------------------------------
    nextstate_HDC               : out std_logic_vector(1 downto 0);
    busy_hdc_internal           : out std_logic;
    wb_ready                    : out std_logic;
    halt_hdc                    : out std_logic;

    hdc_we_word                 : out std_logic_vector(SIMD-1 downto 0);
    hdc_sci_req                 : out std_logic_vector(SPM_NUM-1 downto 0);
    hdc_sci_we                  : out std_logic_vector(SPM_NUM-1 downto 0);
    hdc_sc_write_addr           : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    hdc_sc_read_addr            : out array_2d(1 downto 0)(ADDR_WIDTH-1 downto 0);
    hdc_to_sc                   : out array_2d(SPM_NUM-1 downto 0)(1 downto 0);

    recover_state_wires         : out std_logic;
    hdc_except_data_wire        : out std_logic_vector(31 downto 0)
  );
end HDCU_exception_ctrl;


architecture rtl of HDCU_exception_ctrl is
	  -- Locals that existed in the monolith (written & read by the comb logic)
  signal overflow_rs1_sc : std_logic_vector(ADDR_WIDTH downto 0) := (others => '0');
  signal overflow_rs2_sc : std_logic_vector(ADDR_WIDTH downto 0) := (others => '0');
  signal overflow_rd_sc  : std_logic_vector(ADDR_WIDTH downto 0) := (others => '0');

begin
	
  -- ===== Original HDC_Excpt_Cntrl_Unit_comb process (logic unchanged) =====
  HDC_Excpt_Cntrl_Unit_comb : process(all)
	
	variable busy_hdc_internal_wires 	: std_logic;  
		
	begin

		busy_hdc_internal_wires     := '0';
		wb_ready                    <= '0';
		halt_hdc                    <= '0';
		nextstate_HDC               <= hdc_init;
		recover_state_wires         <= recover_state;
		hdc_except_data_wire        <= hdc_except_data;
		overflow_rs1_sc             <= (others => '0');
		overflow_rs2_sc             <= (others => '0');
		overflow_rd_sc              <= (others => '0');
		hdc_we_word                 <= (others => '0');
		hdc_sci_req                 <= (others => '0');
		hdc_sci_we                  <= (others => '0');
		hdc_sc_write_addr           <= (others => '0');
		hdc_sc_read_addr            <= (others => (others => '0'));
		hdc_to_sc                   <= (others => (others => '0'));

		if unsigned(AXI_HDC_INSTR) /= 0  or busy_hdc_internal_lat = '1' then
		
			case state_HDC is

				when hdc_init =>

					overflow_rs1_sc <= std_logic_vector(resize(('0' & unsigned(AXI_RS1(ADDR_WIDTH -1 downto 0))) + unsigned(AXI_HVSIZE(ADDR_WIDTH -1 downto 0)) - 1, overflow_rs1_sc'length));
					overflow_rs2_sc <= std_logic_vector(resize(('0' & unsigned(AXI_RS2(ADDR_WIDTH -1 downto 0))) + unsigned(AXI_HVSIZE(ADDR_WIDTH -1 downto 0)) - 1, overflow_rs2_sc'length));
					overflow_rd_sc  <= std_logic_vector(resize(('0' & unsigned(AXI_RD(ADDR_WIDTH  -1 downto 0))) + unsigned(AXI_HVSIZE(ADDR_WIDTH -1 downto 0)) - 1, overflow_rd_sc'length));

					if AXI_HVSIZE(ADDR_WIDTH-1 downto 0) = (ADDR_WIDTH-1 downto 0 => '0') then
						null;
					elsif AXI_HVSIZE(1 downto 0) /= "00" then  -- Set exception if the number of bytes are not divisible by four
--						hdc_except_condition_wires := '1';
--						hdc_taken_branch_wires     := '1';    
						hdc_except_data_wire <= ILLEGAL_VECTOR_SIZE_EXCEPT_CODE;
					elsif AXI_HVSIZE(0) /= '0' then            -- Set exception if the number of bytes are not divisible by two
--						hdc_except_condition_wires := '1';
--						hdc_taken_branch_wires     := '1';
						hdc_except_data_wire <= ILLEGAL_VECTOR_SIZE_EXCEPT_CODE;
					elsif (unsigned(AXI_RS1(31 downto ADDR_WIDTH)) > SPM_NUM - 1) or
						  (unsigned(AXI_RS2(31 downto ADDR_WIDTH)) > SPM_NUM - 1) or
						  (unsigned(AXI_RD(31 downto ADDR_WIDTH)) > SPM_NUM - 1) then     -- Set exception for non scratchpad access
--						hdc_except_condition_wires := '1';
--						hdc_taken_branch_wires     := '1';    
						hdc_except_data_wire <= ILLEGAL_ADDRESS_EXCEPT_CODE;
					elsif rs1_to_sc = rs2_to_sc and unsigned(rs1_to_sc) /= 0 and unsigned(rs2_to_sc) /= 0 and unsigned(AXI_HDC_INSTR) /= 8 then -- Set exception for same read access
--						hdc_except_condition_wires := '1';
--						hdc_taken_branch_wires     := '1';    
						hdc_except_data_wire <= READ_SAME_SCARTCHPAD_EXCEPT_CODE;    
					elsif (overflow_rs1_sc(ADDR_WIDTH) = '1' ) then -- Set exception if RS1 reading overflows the scratchpad's address
--						hdc_except_condition_wires := '1';
--						hdc_taken_branch_wires     := '1';    
						-- Determine which SPM caused the overflow for RS1
						if unsigned(AXI_RS1(31 downto ADDR_WIDTH)) > 0 then
							hdc_except_data_wire <= SPM_A_OVERFLOW_RS1_EXCEPT_CODE;
						elsif unsigned(AXI_RS1(31 downto ADDR_WIDTH)) > 1 then
							hdc_except_data_wire <= SPM_B_OVERFLOW_RS1_EXCEPT_CODE;
						elsif unsigned(AXI_RS1(31 downto ADDR_WIDTH)) > 2 then
							hdc_except_data_wire <= SPM_C_OVERFLOW_RS1_EXCEPT_CODE;
						elsif unsigned(AXI_RS1(31 downto ADDR_WIDTH)) > 3 then
							hdc_except_data_wire <= SPM_D_OVERFLOW_RS1_EXCEPT_CODE;
						else
							hdc_except_data_wire <= SCRATCHPAD_OVERFLOW_EXCEPT_CODE; -- Generic fallback
						end if;
					elsif overflow_rs2_sc(ADDR_WIDTH) = '1' then -- Set exception if RS2 reading overflows the scratchpad's address
--						hdc_except_condition_wires := '1';
--						hdc_taken_branch_wires     := '1';    
						-- Determine which SPM caused the overflow for RS2
						if unsigned(AXI_RS2(31 downto ADDR_WIDTH)) > 0 then
							hdc_except_data_wire <= SPM_A_OVERFLOW_RS2_EXCEPT_CODE;
						elsif unsigned(AXI_RS2(31 downto ADDR_WIDTH)) > 1 then
							hdc_except_data_wire <= SPM_B_OVERFLOW_RS2_EXCEPT_CODE;
						elsif unsigned(AXI_RS2(31 downto ADDR_WIDTH)) > 2 then
							hdc_except_data_wire <= SPM_C_OVERFLOW_RS2_EXCEPT_CODE;
						elsif unsigned(AXI_RS2(31 downto ADDR_WIDTH)) > 3 then
							hdc_except_data_wire <= SPM_D_OVERFLOW_RS2_EXCEPT_CODE;
						else
							hdc_except_data_wire <= SCRATCHPAD_OVERFLOW_EXCEPT_CODE; -- Generic fallback
						end if;
					elsif overflow_rd_sc(ADDR_WIDTH) = '1' then           -- Set exception if RD writing overflows the scratchpad's address, scalar writes are excluded
--						hdc_except_condition_wires := '1';
--						hdc_taken_branch_wires     := '1';    
						-- Determine which SPM caused the overflow for RD
						if unsigned(AXI_RD(31 downto ADDR_WIDTH)) > 0 then
							hdc_except_data_wire <= SPM_A_OVERFLOW_RD_EXCEPT_CODE;
						elsif unsigned(AXI_RD(31 downto ADDR_WIDTH)) > 1 then
							hdc_except_data_wire <= SPM_B_OVERFLOW_RD_EXCEPT_CODE;
						elsif unsigned(AXI_RD(31 downto ADDR_WIDTH)) > 2 then
							hdc_except_data_wire <= SPM_C_OVERFLOW_RD_EXCEPT_CODE;
						elsif unsigned(AXI_RD(31 downto ADDR_WIDTH)) > 3 then
							hdc_except_data_wire <= SPM_D_OVERFLOW_RD_EXCEPT_CODE;
						else
							hdc_except_data_wire <= SCRATCHPAD_OVERFLOW_EXCEPT_CODE; -- Generic fallback
						end if;
					else
						nextstate_HDC <= hdc_exec;
						busy_hdc_internal_wires := '1';
					end if;

					busy_hdc_internal_wires := '1';

				when hdc_exec =>

					if (hdc_sci_wr_gnt = '0' and wb_ready = '1') then
						halt_hdc <= '1';
						recover_state_wires <= '1';
					elsif unsigned(HVSIZE_WRITE) <= SIMD_RD_BYTES then
						recover_state_wires <= '0';
					end if;

					if hdc_sci_we = hdc_rd_to_sc then
						if ((unsigned(HVSIZE_WRITE) >= (SIMD)*4+1) or 
							(perm_stage_2_en='1')) then  -- 
							hdc_we_word <= (others => '1');
						elsif  unsigned(HVSIZE_WRITE) >= 1 then
							for i in 0 to SIMD-1 loop
								if i <= to_integer(unsigned(HVSIZE_WRITE)-1)/4 then -- Four because of the number of bytes per word
									if to_integer(unsigned(hdc_sc_write_addr(SIMD_BITS+1 downto 0))/4 + i) < SIMD then
										hdc_we_word(to_integer(unsigned(hdc_sc_write_addr(SIMD_BITS+1 downto 0))/4 + i)) <= '1';
									elsif to_integer(unsigned(hdc_sc_write_addr(SIMD_BITS+1 downto 0))/4 + i) >= SIMD then
										hdc_we_word(to_integer(unsigned(hdc_sc_write_addr(SIMD_BITS+1 downto 0))/4 + i - SIMD)) <= '1';
									end if;
								end if;
							end loop;
						end if;
					elsif hdc_sci_we = hdc_rd_to_sc then
						hdc_we_word(to_integer(unsigned(hdc_sc_write_addr(SIMD_BITS+1 downto 0))/4)) <= '1';
					end if;
					-------------------------------------------------------------------------------------------------------------------------

					--------------------------- BUNDLING ---------------------------------
					if AXI_HDC_INSTR_replicate_lat(HVBUNDLE_bit_position)  = '1' then

						if bundle_stage_2_en = '1' then 
							wb_ready <= '1';
						elsif recover_state = '1' then
							wb_ready <= '1';  
						end if;

						if HVSIZE_READ(ADDR_WIDTH-1 downto 0) > (0 to ADDR_WIDTH-1 => '0') then
							for i in 0 to SPM_NUM - 1 loop
								if hdc_rs1_to_sc(i) = '1' then
									hdc_to_sc(i)(0) <= '1';
								end if;
								if hdc_rs2_to_sc(i) = '1' then
									hdc_to_sc(i)(1) <= '1';
								end if;
							end loop;
							hdc_sci_req <= rs1_to_sc or rs2_to_sc;
							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 downto 0);
							hdc_sc_read_addr(1)  <= AXI_RS2_lat(ADDR_WIDTH - 1 downto 0);
--							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);
--							hdc_sc_read_addr(1)  <= AXI_RS2_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);

							nextstate_HDC <= hdc_exec;
							busy_hdc_internal_wires := '1';
						elsif HVSIZE_WRITE(ADDR_WIDTH-1 downto 0) = (0 to ADDR_WIDTH-1 => '0') then
							nextstate_HDC <= hdc_init;
						else
							nextstate_HDC <= hdc_exec;
							busy_hdc_internal_wires := '1';
						end if;

						if wb_ready = '1' then
							hdc_sci_we <= hdc_rd_to_sc;
							hdc_sc_write_addr <= AXI_RD_lat;
						end if;
					end if;
					----------------------------------------------------------------------

                    ---------------------------- CLIPPING -----------------------------------
					if AXI_HDC_INSTR_replicate_lat(HVCLIP_bit_position)  = '1' then
					
						if clip_stage_2_en = '1' then 
							wb_ready <= '1';
						elsif recover_state = '1' then
							wb_ready <= '1';  
						end if;
						
						if HVSIZE_READ(ADDR_WIDTH-1 downto 0) > (0 to ADDR_WIDTH-1 => '0') then
						
						    for i in 0 to SPM_NUM - 1 loop
								if hdc_rs1_to_sc(i) = '1' then
									hdc_to_sc(i)(0) <= '1';
								end if;
							end loop;
						    
                            hdc_sci_req <= rs1_to_sc;
							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 downto 0);
--							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);
							
						end if;
						
						if HVSIZE_WRITE(ADDR_WIDTH-1 downto 0) > (0 to ADDR_WIDTH-1 => '0') then
							nextstate_HDC <= hdc_exec;
							busy_hdc_internal_wires := '1';
						end if;
						
						if wb_ready = '1' then
							hdc_sci_we    <= hdc_rd_to_sc;
							hdc_sc_write_addr <= AXI_RD_lat;
						end if;
					end if;
					------------------------------------------------------------------------
					
					----------------------------- BINDING --------------------------------
					if AXI_HDC_INSTR_replicate_lat(HVBIND_bit_position)    = '1' then 

						if bind_stage_2_en = '1' then 
							wb_ready <= '1';
						elsif recover_state = '1' then
							wb_ready <= '1';
						end if;

						if unsigned(HVSIZE_READ(ADDR_WIDTH-1 downto 0)) > 0 then
							for i in 0 to SPM_NUM - 1 loop
								if hdc_rs1_to_sc(i) = '1' then
									hdc_to_sc(i)(0) <= '1';
								end if;
								if hdc_rs2_to_sc(i) = '1' then
									hdc_to_sc(i)(1) <= '1';
								end if;
							end loop; 
							hdc_sci_req <= rs1_to_sc or rs2_to_sc;
							hdc_sc_read_addr(1)  <= AXI_RS2_lat(ADDR_WIDTH - 1 downto 0); 
							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 downto 0);
--							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);
--							hdc_sc_read_addr(1)  <= AXI_RS2_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);
							nextstate_HDC <= hdc_exec;
							busy_hdc_internal_wires := '1';
						elsif HVSIZE_WRITE(ADDR_WIDTH-1 downto 0) = (0 to ADDR_WIDTH-1 => '0') then
							nextstate_HDC <= hdc_init;
						else
							nextstate_HDC <= hdc_exec;
							busy_hdc_internal_wires := '1';
						end if;

						if wb_ready = '1' then
							hdc_sci_we <= hdc_rd_to_sc;
							hdc_sc_write_addr <= AXI_RD_lat(ADDR_WIDTH - 1 downto 0);
						end if;
						
					end if;
					----------------------------------------------------------------------------
					
					
					----------------------------- SIMILARITY -----------------------------------
					if AXI_HDC_INSTR_replicate_lat(HVSIM_bit_position)    = '1' then 
					
						if sim_stage_2_en = '1' then 
							wb_ready <= '1';
						elsif recover_state = '1' then
							wb_ready <= '1';
						end if;
						
						if HVSIZE_READ(ADDR_WIDTH-1 downto 0) > (0 to ADDR_WIDTH-1 => '0') then
							
							for i in 0 to SPM_NUM - 1 loop
								if hdc_rs1_to_sc(i) = '1' then
									hdc_to_sc(i)(0) <= '1';
								end if;
								if hdc_rs2_to_sc(i) = '1' then
									hdc_to_sc(i)(1) <= '1';
								end if;
							end loop;
							
							hdc_sci_req <= rs1_to_sc or rs2_to_sc;
							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 downto 0);
							hdc_sc_read_addr(1)  <= AXI_RS2_lat(ADDR_WIDTH - 1 downto 0);
--							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);
--							hdc_sc_read_addr(1)  <= AXI_RS2_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);
							nextstate_HDC <= hdc_exec;
							busy_hdc_internal_wires := '1';
							
						elsif HVSIZE_WRITE(ADDR_WIDTH-1 downto 0) = (0 to ADDR_WIDTH-1 => '0') then
							nextstate_HDC <= hdc_init;
						else
							nextstate_HDC <= hdc_exec;
							busy_hdc_internal_wires := '1';
						end if;
						if wb_ready = '1' then
							hdc_sci_we <= hdc_rd_to_sc;
							hdc_sc_write_addr <= AXI_RD_lat;
						end if;
					end if;
					-------------------------------------------------------------------------


					------------------------------ PERMUTATION -----------------------------
					if AXI_HDC_INSTR_replicate(HVPERM_bit_position)  = '1' then
					
						if perm_stage_1_en = '1' then 
							wb_ready <= '1';
						elsif recover_state = '1' then
							wb_ready <= '1';  
						end if;
						
						if HVSIZE_READ_lat(ADDR_WIDTH-1 downto 0) > (0 to ADDR_WIDTH-1 => '0') then
							
							for i in 0 to SPM_NUM - 1 loop
								if hdc_rs1_to_sc(i) = '1' then
									hdc_to_sc(i)(0) <= '1';
								end if;
							end loop;
							
							hdc_sci_req <= rs1_to_sc;
							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 downto 0);
--							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);

							
						end if;

						if HVSIZE_WRITE(ADDR_WIDTH-1 downto 0) > (0 to ADDR_WIDTH-1 => '0') then
							nextstate_HDC <= hdc_exec;
							busy_hdc_internal_wires := '1';
						else 
							nextstate_HDC <= hdc_init;
						end if;

						if wb_ready = '1' then
							hdc_sci_we <= hdc_rd_to_sc;
							hdc_sc_write_addr <= AXI_RD_lat;
						end if;
					end if;
					-------------------------------------------------------------------------


					------------------------------ SEARCH -----------------------------------
					if AXI_HDC_INSTR_replicate_lat(HVSEARCH_bit_position) = '1' then 
						-- Set write-back ready signal when processing is complete and we still have bytes to write
						if (as_stage_3_en = '1' and HVSIZE_WRITE(ADDR_WIDTH-1 downto 0) > (0 to ADDR_WIDTH-1 => '0')) or recover_state = '1' then
							wb_ready <= '1';
						end if;
						
						-- Configure memory access when bytes remain to be read
						if HVSIZE_READ(ADDR_WIDTH-1 downto 0) > (0 to ADDR_WIDTH-1 => '0') then
							-- Set up memory interface connections
							for i in 0 to SPM_NUM - 1 loop
								if hdc_rs1_to_sc(i) = '1' then
									hdc_to_sc(i)(0) <= '1';
								end if;
								if hdc_rs2_to_sc(i) = '1' then
									hdc_to_sc(i)(1) <= '1';
								end if;
							end loop;
							
							-- Enable access to required scratchpads
							hdc_sci_req <= rs1_to_sc or rs2_to_sc;
							
							-- Set read addresses
							hdc_sc_read_addr(0) <= AXI_RS1_lat(ADDR_WIDTH - 1 downto 0);
							hdc_sc_read_addr(1) <= AXI_RS2_lat(ADDR_WIDTH - 1 downto 0);
--							hdc_sc_read_addr(0)  <= AXI_RS1_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);
--							hdc_sc_read_addr(1)  <= AXI_RS2_lat(ADDR_WIDTH - 1 + SIMD_BITS-1 downto SIMD_BITS-1);
						end if;

						-- Continue execution if bytes remain to be written, stop when write is complete
						if HVSIZE_WRITE(ADDR_WIDTH-1 downto 0) > (0 to ADDR_WIDTH-1 => '0') then
							nextstate_HDC <= hdc_exec;
							busy_hdc_internal_wires := '1';
						elsif HVSIZE_WRITE(ADDR_WIDTH-1 downto 0) = (0 to ADDR_WIDTH-1 => '0') then
							nextstate_HDC <= hdc_init;
						end if;

						-- Configure memory write when ready
						if wb_ready = '1' then
							hdc_sci_we <= hdc_rd_to_sc;
							hdc_sc_write_addr <= AXI_RD_lat;
						end if;
					end if;
					---------------------------------------------------------------------------

				when others =>
				null;
			end case;
		end if;
		
		busy_hdc_internal    <= busy_hdc_internal_wires;

		
	end process;
end rtl;
