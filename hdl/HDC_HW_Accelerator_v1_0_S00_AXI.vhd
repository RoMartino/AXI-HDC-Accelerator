library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

-- local packages
use work.HDC_PKG.all;

entity HDC_HW_Accelerator_v1_0_S00_AXI is
	generic (
		-----------------------------------------
		-- Users to add parameters here
		-----------------------------------------
		SPM_NUM                 : natural;  
		ADDR_WIDTH              : natural;  
		SIMD                    : natural;
		COUNTER_BITS			: natural;
		PERFORMANCE_COUNTER     : boolean := false; 
        SIMD_BITS               : natural := integer(ceil(log2(real(SIMD))));
        SIMD_WIDTH              : natural := SIMD*DATA_WIDTH;
        SIMD_RD_BYTES           : integer := SIMD*DATA_WIDTH/8;
		-----------------------------------------
		-- User parameters ends
		-- Do not modify the parameters beyond this line
		-----------------------------------------

		-- Width of S_AXI data bus
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		-- Width of S_AXI address bus
		C_S_AXI_ADDR_WIDTH	: integer	:= 7
	);
	port (
		----------------------------------------------------------------------------------------------------
		-- Users to add ports here
		----------------------------------------------------------------------------------------------------
		-- Clock and Reset Signals
		clk_i, rst_ni              : in std_logic;
		
		-- SPM Interface Signals
		hdc_sc_data_read           : in  array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
		hdc_sci_wr_gnt             : in  std_logic;
		hdc_data_gnt_i             : in  std_logic;

		hdc_we_word                : out std_logic_vector(SIMD-1 downto 0);
		hdc_sc_data_write_wire     : out std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
		hdc_sc_write_addr          : out std_logic_vector(ADDR_WIDTH-1 downto 0);
		hdc_sc_read_addr           : out array_2d(1 downto 0)(ADDR_WIDTH-1 downto 0);
		hdc_to_sc                  : out array_2d(SPM_NUM-1 downto 0)(1 downto 0);
		hdc_sci_we                 : out std_logic_vector(SPM_NUM-1 downto 0);
		hdc_sci_req                : out std_logic_vector(SPM_NUM-1 downto 0);
		
		-- Axi registers from hdcu
		DMA_addr_r     			   : out std_logic_vector(ADDR_WIDTH-1 downto 0);  -- starting address of spm for reading SPM, address of a word
		DMA_SPM_sel_r  			   : out std_logic_vector(SPM_NUM-1 downto 0);     -- SPM select for read
		DMA_size_r     			   : out std_logic_vector(ADDR_WIDTH-1 downto 0);  -- size of transfer for read, size in byte
		DMA_r          			   : out std_logic;                                -- read enable

		DMA_addr_w     			   : out std_logic_vector(ADDR_WIDTH-1 downto 0);  -- starting address of spm for writing SPM, address of a word
		DMA_SPM_sel_w  			   : out std_logic_vector(SPM_NUM-1 downto 0);     -- SPM select for write
		DMA_size_w     			   : out std_logic_vector(ADDR_WIDTH-1 downto 0);  -- size of transfer for write, size in byte
		DMA_w          			   : out std_logic;                                -- write enable

		DMA_start      			   : out std_logic;
		
		-- HDC Done Signal
		done_hdc_o    			   : out std_logic := '0';  -- HDC done pulse signal (1 for one clock cycle when busy_hdc goes from 1 to 0)
		rst_status     			   : out std_logic := '1';  -- For debugging purposes
		axi_is_working  		   : out std_logic := '0';  -- For debugging purposes
		busy_hdc_o   			   : out std_logic := '0';  -- For debugging purposes
	    ----------------------------------------------------------------------------------------------------
		-- User ports ends
		-- Do not modify the ports beyond this line
		----------------------------------------------------------------------------------------------------

		-- Global Clock Signal
		S_AXI_ACLK	: in std_logic;
		-- Global Reset Signal. This Signal is Active LOW
		S_AXI_ARESETN	: in std_logic;
		-- Write address (issued by master, acceped by Slave)
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		-- Write channel Protection type. This signal indicates the
    	-- privilege and security level of the transaction, and whether
    	-- the transaction is a data access or an instruction access.
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		-- Write address valid. This signal indicates that the master signaling
    	-- valid write address and control information.
		S_AXI_AWVALID	: in std_logic;
		-- Write address ready. This signal indicates that the slave is ready
    	-- to accept an address and associated control signals.
		S_AXI_AWREADY	: out std_logic;
		-- Write data (issued by master, acceped by Slave) 
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		-- Write strobes. This signal indicates which byte lanes hold
    	-- valid data. There is one write strobe bit for each eight
    	-- bits of the write data bus.    
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		-- Write valid. This signal indicates that valid write
    	-- data and strobes are available.
		S_AXI_WVALID	: in std_logic;
		-- Write ready. This signal indicates that the slave
    	-- can accept the write data.
		S_AXI_WREADY	: out std_logic;
		-- Write response. This signal indicates the status
    	-- of the write transaction.
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		-- Write response valid. This signal indicates that the channel
    	-- is signaling a valid write response.
		S_AXI_BVALID	: out std_logic;
		-- Response ready. This signal indicates that the master
    	-- can accept a write response.
		S_AXI_BREADY	: in std_logic;
		-- Read address (issued by master, acceped by Slave)
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		-- Protection type. This signal indicates the privilege
    	-- and security level of the transaction, and whether the
    	-- transaction is a data access or an instruction access.
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		-- Read address valid. This signal indicates that the channel
    	-- is signaling valid read address and control information.
		S_AXI_ARVALID	: in std_logic;
		-- Read address ready. This signal indicates that the slave is
    	-- ready to accept an address and associated control signals.
		S_AXI_ARREADY	: out std_logic;
		-- Read data (issued by slave)
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		-- Read response. This signal indicates the status of the
    	-- read transfer.
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		-- Read valid. This signal indicates that the channel is
    	-- signaling the required read data.
		S_AXI_RVALID	: out std_logic;
		-- Read ready. This signal indicates that the master can
    	-- accept the read data and response information.
		S_AXI_RREADY	: in std_logic
	);
end HDC_HW_Accelerator_v1_0_S00_AXI;

architecture arch_imp of HDC_HW_Accelerator_v1_0_S00_AXI is

	---------------------------------------------------------------------------------------------------------------------------- 	
	-- ██╗  ██╗██████╗  ██████╗     █████╗  ██████╗ ██████╗██╗         ███████╗██╗ ██████╗ ███╗   ██╗ █████╗ ██╗     ███████╗ --
	-- ██║  ██║██╔══██╗██╔════╝    ██╔══██╗██╔════╝██╔════╝██║         ██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗██║     ██╔════╝ --
	-- ███████║██║  ██║██║         ███████║██║     ██║     ██║         ███████╗██║██║  ███╗██╔██╗ ██║███████║██║     ███████╗ --
	-- ██╔══██║██║  ██║██║         ██╔══██║██║     ██║     ██║         ╚════██║██║██║   ██║██║╚██╗██║██╔══██║██║     ╚════██║ --
	-- ██║  ██║██████╔╝╚██████╗    ██║  ██║╚██████╗╚██████╗███████╗    ███████║██║╚██████╔╝██║ ╚████║██║  ██║███████╗███████║ --
	-- ╚═╝  ╚═╝╚═════╝  ╚═════╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝╚══════╝    ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚══════╝ --
	----------------------------------------------------------------------------------------------------------------------------
	-- Costants
	constant COUNTERS_NUMBER           : natural := DATA_WIDTH/COUNTER_BITS;  
	constant SPM_STRT_ADDR             : std_logic_vector(31 downto 0) := x"00000000";

	-- FSM States
	signal state_HDC				   : std_logic_vector(1 downto 0); 
	signal nextstate_HDC 			   : std_logic_vector(1 downto 0);
	signal busy_hdc 				   : std_logic; 
	signal busy_hdc_lat                : std_logic;  -- Latched version of busy_hdc for edge detection
	signal busy_hdc_internal           : std_logic;
	signal busy_hdc_internal_lat       : std_logic;
	signal done_hdc_reg                : std_logic;  -- Register to hold the done interrupt state
	signal recover_state               : std_logic;
	signal recover_state_wires         : std_logic;
	
	-- FSM Done
	-- Interrupt state machine
	type interrupt_state_t is (IDLE, DONE_ASSERTED);
	signal interrupt_state : interrupt_state_t := IDLE;
	signal interrupt_next_state : interrupt_state_t;

	-- HW Loop Signals
	signal HVSIZE_READ                 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);  -- Bytes remaining to read
	signal HVSIZE_READ_lat             : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);  -- Bytes remaining to read
	signal HVSIZE_WRITE                : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);  -- Bytes remaining to write

	-- Operation Signals
	signal AXI_HDC_INSTR_replicate_lat     : std_logic_vector(31 downto 0);

	-- Operands Signals
	signal AXI_RS1_lat                 	   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_RS2_lat                 	   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_RD_lat                  	   : std_logic_vector(ADDR_WIDTH - 1 downto 0);
	
	-- SPM Interface Signals
	signal hdc_sc_data_write_wire_int      : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
	signal hdc_sc_data_write_int           : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
	signal hdc_data_gnt_i_lat              : std_logic;
	signal overflow_rs1_sc                 : std_logic_vector(ADDR_WIDTH downto 0);
	signal overflow_rs2_sc                 : std_logic_vector(ADDR_WIDTH downto 0);
	signal overflow_rd_sc                  : std_logic_vector(ADDR_WIDTH downto 0);
	signal rs1_to_sc					   : std_logic_vector(SPM_NUM-1 downto 0);
	signal rs2_to_sc					   : std_logic_vector(SPM_NUM-1 downto 0);
	signal rd_to_sc						   : std_logic_vector(SPM_NUM-1 downto 0);
	signal ID_rs1_to_sc   				   : std_logic_vector(SPM_NUM-1 downto 0);
	signal ID_rs2_to_sc   				   : std_logic_vector(SPM_NUM-1 downto 0);
	signal ID_rd_to_sc    				   : std_logic_vector(SPM_NUM-1 downto 0);
	signal hdc_rs1_to_sc                   : std_logic_vector(SPM_NUM-1 downto 0);
	signal hdc_rs2_to_sc                   : std_logic_vector(SPM_NUM-1 downto 0);
	signal hdc_rd_to_sc                    : std_logic_vector(SPM_NUM-1 downto 0);

	-- Exception Signals
	signal hdc_except_data   		   	   : std_logic_vector(31 downto 0):= (others => '0'); 
	signal hdc_except_data_wire            : std_logic_vector(31 downto 0);
	signal halt_hdc                        : std_logic; 
	signal halt_hdc_lat                    : std_logic;
	
	signal wb_ready                        : std_logic;

	------------------ BUNDLING --------------------
	signal bundle_en                  : std_logic;  
	signal bundle_stage_1_en          : std_logic;
	signal bundle_stage_2_en          : std_logic;

	signal counters_flat              : std_logic_vector(SIMD*COUNTERS_NUMBER*COUNTER_BITS-1 downto 0) := (others => '0');
	signal counters_wire_flat         : std_logic_vector(SIMD*COUNTERS_NUMBER*COUNTER_BITS-1 downto 0) := (others => '0');
	signal bundle_processed_bytes     : integer;
	signal hdcu_in_bundle_operands    : array_2d(1 downto 0)(SIMD*DATA_WIDTH - 1 downto 0) := (others => (others => '0'));
	signal hdcu_out_bundle_results    : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0) := (others => '0');
	------------------------------------------------

	------------------ BINDING ---------------------        
	signal bind_en                    : std_logic;  
	signal bind_stage_1_en            : std_logic;
	signal bind_stage_2_en            : std_logic;
	signal hdcu_in_bind_operands      : array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0) := (others => (others => '0'));
	signal hdcu_out_bind_results      : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0) := (others => '0');
	------------------------------------------------

	------------------ SIMILARITY ------------------
	signal sim_en                    : std_logic; 
	signal sim_stage_1_en            : std_logic;
	signal sim_stage_2_en            : std_logic;
	signal sim_measure               : std_logic_vector(SIMILARITY_BITS*SIMD - 1 downto 0) := (others => '0');
	signal hamming_distance_wire     : std_logic_vector(SIMILARITY_BITS - 1 downto 0) := (others => '0');
	signal hdcu_in_sim_operands      : array_2d(1 downto 0)(SIMD*DATA_WIDTH - 1 downto 0) := (others => (others => '0'));
	signal hdcu_out_sim_results      : std_logic_vector(SIMILARITY_BITS - 1 downto 0) := (others => '0');
	------------------------------------------------
  
	----------------- CLIPPING ---------------------
	signal clip_en                         : std_logic;
	signal clip_stage_1_en                 : std_logic;
	signal clip_stage_2_en                 : std_logic;
	signal clip_processed_bytes            : integer;
	signal hdcu_in_clip_operand_0          : std_logic_vector(SIMD*DATA_WIDTH - 1 downto 0) := (others => '0');
	signal hdcu_in_clip_operand_1          : std_logic_vector(Data_Width - 1 downto 0) := (others => '0'); 
	signal hdcu_out_clip_results           : std_logic_vector(SIMD*DATA_WIDTH - 1 downto 0) := (others => '0');
	------------------------------------------------

	----------------- PERMUTATION ---------------------
	signal perm_en                         : std_logic;
	signal perm_stage_1_en                 : std_logic;
	signal perm_stage_2_en                 : std_logic;
	signal first_perm_source_addr          : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
	signal first_perm_dest_addr            : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
	signal hdcu_in_perm_operand_0          : std_logic_vector(SIMD*DATA_WIDTH - 1 downto 0) := (others => '0');
	signal hdcu_in_perm_operand_1          : std_logic_vector(Data_Width - 1 downto 0) := (others => '0');
	signal hdcu_out_perm_results           : std_logic_vector(SIMD*DATA_WIDTH - 1 downto 0) := (others => '0');
	---------------------------------------------------

	---------------ASSOCIATIVE SEARCH -----------------
	signal as_en                           : std_logic;
	signal as_stage_1_en                   : std_logic;
	signal as_stage_2_en                   : std_logic;
	signal as_stage_3_en                   : std_logic;
	signal class_index 					   : integer := 0;
	signal AMSIZE_READ                     : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
	signal AMSIZE_READ_lat                 : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 
	signal head_ptr_encoded_hv             : std_logic_vector(31 downto 0) := (others => '0'); 
	signal temp_best_class_index           : integer; 
	---------------------------------------------------
    
	------------------------------------------------
	---- Signals for user logic register space example
	--------------------------------------------------
	signal AXI_HVSIZE	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_HVTYPE	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_RS1		:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_RS2		:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_RD		:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_HDC_INSTR:std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
	signal AXI_HDC_INSTR_replicate:std_logic_vector(HDC_UNIT_INSTR_SET_SIZE-1 downto 0);
	signal AXI_HVCLASS	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_HDC_REQ	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_RSIZE    :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_WSIZE    :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_INTERRUPT:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);  -- Bit 0: enable interrupt, Bit 1: clear done
	signal AXI_SIMD_VALUE   :std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_SPM_NUM_VALUE:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg12	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg13	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg14	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg15	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg16	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg17	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg18	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg19	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg20	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg21	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg22	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg23	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg24	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg25	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg26	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg27	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg28	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg29	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal slv_reg30	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal AXI_TEST		:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	
	signal axi_test_written_signal : std_logic;  -- Signal to detect AXI_TEST write
	signal slv_reg_rden	: std_logic;
	signal slv_reg_wren	: std_logic;
	signal reg_data_out	:std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal byte_index	: integer;
	signal aw_en		: std_logic;



    -- intervento di Marco P per spezzare il percorso critico
    signal hdcu_in_sim_operands_reg : array_2d(1 downto 0)(SIMD*DATA_WIDTH - 1 downto 0);

    signal sim_en_reg           : std_logic;
    signal sim_stage_1_en_reg   : std_logic;
    signal sim_stage_2_en_reg   : std_logic;
    signal sim_stage_2_en_reg_2 : std_logic;
    signal as_en_reg            : std_logic;
    signal as_en_reg_2          : std_logic;
    signal as_stage_1_en_reg    : std_logic;
    signal as_stage_1_en_reg_2  : std_logic;
    signal as_stage_1_en_reg_3  : std_logic;
    signal as_stage_2_en_reg    : std_logic;
    signal as_stage_3_en_reg    : std_logic;
    signal as_stage_3_en_reg_2  : std_logic;
    signal as_stage_3_en_reg_3  : std_logic;

	signal AMSIZE_READ_lat_reg          : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); 
	signal AMSIZE_READ_lat_reg_2        : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); 
	signal AMSIZE_READ_lat_reg_3        : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); 
	signal hamming_distance_wire_reg    : std_logic_vector(SIMILARITY_BITS - 1 downto 0);
	signal class_index_reg 			    : integer := 0;
	signal class_index_reg_2            : integer := 0;
	signal class_index_reg_3            : integer := 0;

	----------------------------------------------------------------------------------------------------------------------------
	-- ██████╗ ███████╗██████╗ ███████╗ ██████╗ ██████╗ ███╗   ███╗ █████╗ ███╗   ██╗ ██████╗███████╗                        --
	-- ██╔══██╗██╔════╝██╔══██╗██╔════╝██╔═══██╗██╔══██╗████╗ ████║██╔══██╗████╗  ██║██╔════╝██╔════╝                        --
	-- ██████╔╝█████╗  ██████╔╝█████╗  ██║   ██║██████╔╝██╔████╔██║███████║██╔██╗ ██║██║     █████╗                          --
	-- ██╔═══╝ ██╔══╝  ██╔══██╗██╔══╝  ██║   ██║██╔══██╗██║╚██╔╝██║██╔══██║██║╚██╗██║██║     ██╔══╝                          --
	-- ██║     ███████╗██║  ██║██║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║██║  ██║██║ ╚████║╚██████╗███████╗                        --
	-- ╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝                        --
	--  ██████╗ ██████╗ ██╗   ██╗███╗   ██╗████████╗███████╗██████╗ ███████╗                                                --
	-- ██╔════╝██╔═══██╗██║   ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗██╔════╝                                                --
	-- ██║     ██║   ██║██║   ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝███████╗                                                --
	-- ██║     ██║   ██║██║   ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗╚════██║                                                --
	-- ╚██████╗╚██████╔╝╚██████╔╝██║ ╚████║   ██║   ███████╗██║  ██║███████║                                                --
	--  ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝                                                --
	----------------------------------------------------------------------------------------------------------------------------
	-- Performance counters for each functional unit
	-- Each counter counts the number of clock cycles when the corresponding enable signal is high
	-- Counters are reset when a new operation starts (0->1 transition of enable signal)
	-- Counter values are copied to AXI registers when the operation completes (1->0 transition)
	----------------------------------------------------------------------------------------------------------------------------
	
	-- Performance counter signals (32-bit counters)
	signal perf_bundle_counter       : unsigned(31 downto 0) := (others => '0');
	signal perf_bind_counter         : unsigned(31 downto 0) := (others => '0');
	signal perf_sim_counter          : unsigned(31 downto 0) := (others => '0');
	signal perf_clip_counter         : unsigned(31 downto 0) := (others => '0');
	signal perf_perm_counter         : unsigned(31 downto 0) := (others => '0');
	signal perf_as_counter           : unsigned(31 downto 0) := (others => '0');
	
	-- Latched enable signals for edge detection
	signal bundle_en_lat             : std_logic := '0';
	signal bind_en_lat               : std_logic := '0';
	signal sim_en_lat                : std_logic := '0';
	signal clip_en_lat               : std_logic := '0';
	signal perm_en_lat               : std_logic := '0';
	signal as_en_lat                 : std_logic := '0';
	
	-- AXI register signals for performance counters
	signal perf_bundle_count_axi     : std_logic_vector(31 downto 0) := (others => '0');
	signal perf_bind_count_axi       : std_logic_vector(31 downto 0) := (others => '0');
	signal perf_sim_count_axi        : std_logic_vector(31 downto 0) := (others => '0');
	signal perf_clip_count_axi       : std_logic_vector(31 downto 0) := (others => '0');
	signal perf_perm_count_axi       : std_logic_vector(31 downto 0) := (others => '0');
	signal perf_as_count_axi         : std_logic_vector(31 downto 0) := (others => '0');
	----------------------------------------------------------------------------------------------------------------------------

begin

	-- DEBUG
	rst_status <= rst_ni;
	busy_hdc_o <= busy_hdc;
	
	u_axi_regs : entity work.HDCU_axi_regs
	generic map (
        ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
        SIMD                => SIMD,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH,
		C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH
	)
	port map (
		----------------------------------------------------------------
		-- AXI4-Lite Slave Interface 
		----------------------------------------------------------------
		S_AXI_ACLK    => S_AXI_ACLK,
		S_AXI_ARESETN => S_AXI_ARESETN,
		S_AXI_AWADDR  => S_AXI_AWADDR,
		S_AXI_AWPROT  => S_AXI_AWPROT,
		S_AXI_AWVALID => S_AXI_AWVALID,
		S_AXI_AWREADY => S_AXI_AWREADY,
		S_AXI_WDATA   => S_AXI_WDATA,
		S_AXI_WSTRB   => S_AXI_WSTRB,
		S_AXI_WVALID  => S_AXI_WVALID,
		S_AXI_WREADY  => S_AXI_WREADY,
		S_AXI_BRESP   => S_AXI_BRESP,
		S_AXI_BVALID  => S_AXI_BVALID,
		S_AXI_BREADY  => S_AXI_BREADY,
		S_AXI_ARADDR  => S_AXI_ARADDR,
		S_AXI_ARPROT  => S_AXI_ARPROT,
		S_AXI_ARVALID => S_AXI_ARVALID,
		S_AXI_ARREADY => S_AXI_ARREADY,
		S_AXI_RDATA   => S_AXI_RDATA,
		S_AXI_RRESP   => S_AXI_RRESP,
		S_AXI_RVALID  => S_AXI_RVALID,
		S_AXI_RREADY  => S_AXI_RREADY,

		------------------------------------------------------------
		-- AXI register file (outputs to design)
		------------------------------------------------------------
		AXI_HVSIZE              => AXI_HVSIZE,
		AXI_HVTYPE              => AXI_HVTYPE,
		AXI_RS1                 => AXI_RS1,
		AXI_RS2                 => AXI_RS2,
		AXI_RD                  => AXI_RD,
		AXI_HDC_INSTR           => AXI_HDC_INSTR,
		AXI_HDC_INSTR_replicate => AXI_HDC_INSTR_replicate,
		AXI_HVCLASS             => AXI_HVCLASS,
		AXI_HDC_REQ             => AXI_HDC_REQ,
		AXI_RSIZE               => AXI_RSIZE,
		AXI_WSIZE               => AXI_WSIZE,
		AXI_INTERRUPT           => AXI_INTERRUPT,      -- <- becomes AXI_INTERRUPT via alias above
		AXI_SIMD_VALUE          => AXI_SIMD_VALUE,
		AXI_SPM_NUM_VALUE       => AXI_SPM_NUM_VALUE,
		slv_reg13               => slv_reg13,
		slv_reg14               => slv_reg14,
		slv_reg15               => slv_reg15,
		slv_reg16               => slv_reg16,
		slv_reg17               => slv_reg17,
		slv_reg18               => slv_reg18,
		slv_reg19               => slv_reg19,
		slv_reg20               => slv_reg20,
		slv_reg21               => slv_reg21,
		slv_reg22               => slv_reg22,
		slv_reg23               => slv_reg23,
		slv_reg24               => slv_reg24,
		slv_reg25               => slv_reg25,
		slv_reg26               => slv_reg26,
		slv_reg27               => slv_reg27,
		slv_reg28               => slv_reg28,
		slv_reg29               => slv_reg29,
		slv_reg30               => slv_reg30,
		AXI_TEST                => AXI_TEST,
		axi_test_written        => axi_test_written_signal,
		
		------------------------------------------------------------
		-- Performance counter inputs
		------------------------------------------------------------
		perf_bundle_count_i     => perf_bundle_count_axi,
		perf_bind_count_i       => perf_bind_count_axi,
		perf_sim_count_i        => perf_sim_count_axi,
		perf_clip_count_i       => perf_clip_count_axi,
		perf_perm_count_i       => perf_perm_count_axi,
		perf_as_count_i         => perf_as_count_axi
	);

	-----------------------------------------------------------------
	-- Add user logic here
	-----------------------------------------------------------------

	-- AXI_TEST Write Detection Logic
	-- When AXI_TEST is written, set axi_is_working to '1'
	-- AXI_TEST_Write_Detection : process(clk_i, rst_ni)
	-- begin
	-- 	if rst_ni = '0' then
	-- 		axi_is_working <= '0';
	-- 	elsif rising_edge(clk_i) then
	-- 		if axi_test_written_signal = '1' then
	-- 			axi_is_working <= '1';
	-- 		end if;
	-- 	end if;
	-- end process;

	-----------------------------------------------------------------------
	-- ███████╗██████╗ ███╗   ███╗              ███████╗███████╗██╗      --
	-- ██╔════╝██╔══██╗████╗ ████║              ██╔════╝██╔════╝██║      --
	-- ███████╗██████╔╝██╔████╔██║    █████╗    ███████╗█████╗  ██║      --
	-- ╚════██║██╔═══╝ ██║╚██╔╝██║    ╚════╝    ╚════██║██╔══╝  ██║      --
	-- ███████║██║     ██║ ╚═╝ ██║              ███████║███████╗███████╗ --
	-- ╚══════╝╚═╝     ╚═╝     ╚═╝              ╚══════╝╚══════╝╚══════╝ -- 
    -----------------------------------------------------------------------
    Spm_Addr_Mapping : process(all)
    begin
		ID_rs1_to_sc <= (others => '0');
		ID_rs2_to_sc <= (others => '0');
		ID_rd_to_sc  <= (others => '0');
		if unsigned(AXI_HDC_INSTR_replicate) /= 0 then
			for i in 0 to SPM_NUM-1 loop 
				if AXI_RS1(31 downto ADDR_WIDTH) >= std_logic_vector(unsigned(SPM_STRT_ADDR(31 downto ADDR_WIDTH)) + (i)) and
				AXI_RS1(31 downto ADDR_WIDTH) <  std_logic_vector(unsigned(SPM_STRT_ADDR(31 downto ADDR_WIDTH)) + (i+1)) then
					ID_rs1_to_sc(i) <= '1';
				end if;
				if AXI_HDC_INSTR(HVMEMLD_bit_position) /= '1' and AXI_HDC_INSTR(HVMEMSTR_bit_position) /= '1' then
					if AXI_RS2(31 downto ADDR_WIDTH) >= std_logic_vector(unsigned(SPM_STRT_ADDR(31 downto ADDR_WIDTH)) + (i)) and
					AXI_RS2(31 downto ADDR_WIDTH) <  std_logic_vector(unsigned(SPM_STRT_ADDR(31 downto ADDR_WIDTH)) + (i+1)) then
						ID_rs2_to_sc(i) <= '1';
					end if;
					if AXI_RD(31 downto ADDR_WIDTH)  >= std_logic_vector(unsigned(SPM_STRT_ADDR(31 downto ADDR_WIDTH)) + (i)) and
					AXI_RD(31 downto ADDR_WIDTH)  <  std_logic_vector(unsigned(SPM_STRT_ADDR(31 downto ADDR_WIDTH)) + (i+1)) then
						ID_rd_to_sc(i) <= '1';
					end if;
				end if;
			end loop;
		end if;
    end process;

	Spm_Addr_Mapping_Synch : process(clk_i, rst_ni)
	begin
	  if rst_ni = '0' then
           rs1_to_sc <= (others => '0');
           rs2_to_sc <= (others => '0');
           rd_to_sc  <= (others => '0');
	  elsif rising_edge(clk_i) then
           if(unsigned(AXI_HDC_INSTR_replicate) /= 0) then
                rs1_to_sc <= ID_rs1_to_sc;
                rs2_to_sc <= ID_rs2_to_sc;
                rd_to_sc  <= ID_rd_to_sc;
           else
                rs1_to_sc <= (others => '0');
                rs2_to_sc <= (others => '0');
                rd_to_sc  <= (others => '0');
          	end if;
          end if;
	end process;
    
    LD_STR_comb: process(all)

	begin
	          
		if (AXI_HDC_INSTR(HVMEMSTR_bit_position) = '1') then
			DMA_addr_r 	  <= AXI_RS1(ADDR_WIDTH-1 downto 0);
		    DMA_SPM_sel_r <= ID_rs1_to_sc;
			DMA_size_r 	  <= AXI_RSIZE(ADDR_WIDTH-1 downto 0);
			DMA_r         <= '1';
		else
			DMA_addr_r 	  <= (others => '0');
			DMA_SPM_sel_r <= (others => '0');
			DMA_size_r 	  <= (others => '0');
			DMA_r         <= '0';
		end if;

		if (AXI_HDC_INSTR(HVMEMLD_bit_position) = '1') then
			DMA_addr_w 	  <= AXI_RS1(ADDR_WIDTH-1 downto 0);
            DMA_SPM_sel_w <= ID_rs1_to_sc;
			DMA_size_w 	  <= AXI_WSIZE(ADDR_WIDTH-1 downto 0);
			DMA_w         <= '1';
		else
			DMA_addr_w 	  <= (others => '0');
			DMA_SPM_sel_w <= (others => '0');
			DMA_size_w 	  <= (others => '0');
			DMA_w         <= '0';
		end if;

	end process;
	
	DMA_start <= AXI_HDC_INSTR(HVMEMSTR_bit_position) or AXI_HDC_INSTR(HVMEMLD_bit_position);

	----------------------------------------------------------------------------	
	-- ██╗  ██╗██████╗  ██████╗               █████╗  ██████╗ ██████╗██╗      --
	-- ██║  ██║██╔══██╗██╔════╝              ██╔══██╗██╔════╝██╔════╝██║      --
	-- ███████║██║  ██║██║         █████╗    ███████║██║     ██║     ██║      --
	-- ██╔══██║██║  ██║██║         ╚════╝    ██╔══██║██║     ██║     ██║      --
	-- ██║  ██║██████╔╝╚██████╗              ██║  ██║╚██████╗╚██████╗███████╗ --
	-- ╚═╝  ╚═╝╚═════╝  ╚═════╝              ╚═╝  ╚═╝ ╚═════╝ ╚═════╝╚══════╝ --
	----------------------------------------------------------------------------                                                                       

	busy_hdc <= busy_hdc_internal;

	-- Combinational logic for next state
	HDC_Done_next_state_proc : process(all)
	begin
		interrupt_next_state <= interrupt_state;
		
		case interrupt_state is
			when IDLE =>
				if busy_hdc_lat = '1' and busy_hdc = '0' then
					interrupt_next_state <= DONE_ASSERTED;
				end if;
				
			when DONE_ASSERTED =>
				if AXI_INTERRUPT(1) = '1' then
					interrupt_next_state <= IDLE;
				end if;
		end case;
	end process;

	-- Sequential logic for state update
	HDC_Done_state_proc : process(clk_i, rst_ni)
	begin
		if rst_ni = '0' then
			interrupt_state <= IDLE;
		elsif rising_edge(clk_i) then
			interrupt_state <= interrupt_next_state;
		end if;
	end process;

	-- Output logic
	HDC_Done_output_proc : process(all)
	begin
		case interrupt_state is
			when IDLE =>
				done_hdc_o <= '0';
			when DONE_ASSERTED =>
				done_hdc_o <= '1';
		end case;
	end process;

	-----------------------------------------------------------------------------------
	-- ███████╗██╗  ██╗███████╗ ██████╗              ██╗   ██╗███╗   ██╗██╗████████╗ --
	-- ██╔════╝╚██╗██╔╝██╔════╝██╔════╝              ██║   ██║████╗  ██║██║╚══██╔══╝ --
	-- █████╗   ╚███╔╝ █████╗  ██║         █████╗    ██║   ██║██╔██╗ ██║██║   ██║    --
	-- ██╔══╝   ██╔██╗ ██╔══╝  ██║         ╚════╝    ██║   ██║██║╚██╗██║██║   ██║    --
	-- ███████╗██╔╝ ██╗███████╗╚██████╗              ╚██████╔╝██║ ╚████║██║   ██║    --
	-- ╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝               ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    --
	----------------------------------------------------------------------------------- 
	
	u_exec : entity work.HDCU_exec_unit
	generic map (
        ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
        SIMD                => SIMD,
		COUNTER_BITS        => COUNTER_BITS,
		COUNTERS_NUMBER 	=> COUNTERS_NUMBER,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH,
        SIMD_RD_BYTES       => SIMD_RD_BYTES,
		C_S_AXI_DATA_WIDTH  => C_S_AXI_DATA_WIDTH
	)
	port map (
		clk_i                   => clk_i,
		rst_ni                  => rst_ni,

		state_HDC               => state_HDC,
		busy_hdc_internal_lat   => busy_hdc_internal_lat,
		wb_ready                => wb_ready,
		hdc_data_gnt_i          => hdc_data_gnt_i,
		halt_hdc                => halt_hdc,
		halt_hdc_lat            => halt_hdc_lat,
		bundle_processed_bytes  => bundle_processed_bytes,
		as_stage_3_en           => as_stage_3_en_reg,
		recover_state_wires     => recover_state_wires,

		AXI_HVSIZE              => AXI_HVSIZE,
		AXI_HVCLASS             => AXI_HVCLASS,
		AXI_RS1                 => AXI_RS1,
		AXI_RS2                 => AXI_RS2,
		AXI_RD                  => AXI_RD,
		AXI_HDC_INSTR           => AXI_HDC_INSTR,
		AXI_HDC_INSTR_replicate => AXI_HDC_INSTR_replicate,

		rs1_to_sc               => rs1_to_sc,
		rs2_to_sc               => rs2_to_sc,
		rd_to_sc                => rd_to_sc,

		hdc_sc_data_write_wire_int => hdc_sc_data_write_wire_int,

		recover_state              => recover_state,
		hdc_rs1_to_sc              => hdc_rs1_to_sc,
		hdc_rs2_to_sc              => hdc_rs2_to_sc,
		hdc_rd_to_sc               => hdc_rd_to_sc,

		AXI_HDC_INSTR_replicate_lat => AXI_HDC_INSTR_replicate_lat(HDC_UNIT_INSTR_SET_SIZE-1 downto 0),

		AXI_RS1_lat              => AXI_RS1_lat,
		AXI_RS2_lat              => AXI_RS2_lat,
		AXI_RD_lat               => AXI_RD_lat,

		HVSIZE_READ              => HVSIZE_READ,
		HVSIZE_READ_lat          => HVSIZE_READ_lat,
		HVSIZE_WRITE             => HVSIZE_WRITE,

		AMSIZE_READ              => AMSIZE_READ,
		AMSIZE_READ_lat          => AMSIZE_READ_lat,

		head_ptr_encoded_hv      => head_ptr_encoded_hv,
		class_index              => class_index,

		first_perm_source_addr   => first_perm_source_addr,
		first_perm_dest_addr     => first_perm_dest_addr,

		hdc_sc_data_write_int    => hdc_sc_data_write_int
	);

	
	u_exception_ctrl : entity work.HDCU_exception_ctrl
	generic map (
		C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
		ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
        SIMD                => SIMD,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH,
        SIMD_RD_BYTES       => SIMD_RD_BYTES
	)
	port map (
		----------------------------------------------------------------
		-- Inputs from AXI mirror registers
		----------------------------------------------------------------
		AXI_HVSIZE                  => AXI_HVSIZE,
		AXI_RS1                     => AXI_RS1,
		AXI_RS2                     => AXI_RS2,
		AXI_RD                      => AXI_RD,
		AXI_HDC_INSTR               => AXI_HDC_INSTR,
		AXI_HDC_INSTR_replicate     => AXI_HDC_INSTR_replicate,
		AXI_HVCLASS                 => AXI_HVCLASS,
		AXI_HDC_REQ                 => AXI_HDC_REQ,
		AXI_RSIZE                   => AXI_RSIZE,
		AXI_WSIZE                   => AXI_WSIZE,
		AXI_HDC_INSTR_replicate_lat => AXI_HDC_INSTR_replicate_lat(HDC_UNIT_INSTR_SET_SIZE-1 downto 0),
		HVSIZE_READ_lat             => HVSIZE_READ_lat,
		first_perm_source_addr      => first_perm_source_addr,
		first_perm_dest_addr        => first_perm_dest_addr,

		----------------------------------------------------------------
		-- Latched/working copies from Exec unit (used as READS here)
		----------------------------------------------------------------
		AXI_RS1_lat                 => AXI_RS1_lat,
		AXI_RS2_lat                 => AXI_RS2_lat,
		AXI_RD_lat                  => AXI_RD_lat,
		HVSIZE_READ                 => HVSIZE_READ,
		HVSIZE_WRITE                => HVSIZE_WRITE,

		----------------------------------------------------------------
		-- State / grants / enables used by this comb block
		----------------------------------------------------------------
		state_HDC                   => state_HDC,
		busy_hdc_internal_lat       => busy_hdc_internal_lat,
		hdc_sci_wr_gnt              => hdc_sci_wr_gnt,
		hdc_data_gnt_i              => hdc_data_gnt_i,

		bundle_stage_2_en           => bundle_stage_2_en,
		bind_stage_2_en             => bind_stage_2_en,
		--sim_stage_2_en              => sim_stage_2_en,
		sim_stage_2_en              => sim_stage_2_en_reg_2,
		clip_stage_2_en             => clip_stage_2_en,
		perm_stage_1_en             => perm_stage_1_en,
		perm_stage_2_en             => perm_stage_2_en,
		--as_stage_3_en               => as_stage_3_en,
		as_stage_3_en               => as_stage_3_en_reg_3,

		----------------------------------------------------------------
		-- Scratchpad selections
		----------------------------------------------------------------
		rs1_to_sc                   => rs1_to_sc,
		rs2_to_sc                   => rs2_to_sc,
		rd_to_sc                    => rd_to_sc,

		-- Exec’s latched selects
		hdc_rs1_to_sc               => hdc_rs1_to_sc,
		hdc_rs2_to_sc               => hdc_rs2_to_sc,
		hdc_rd_to_sc                => hdc_rd_to_sc,

		----------------------------------------------------------------
		-- Sticky/latched flags read by this comb logic
		----------------------------------------------------------------
		recover_state               => recover_state,
		hdc_except_data             => hdc_except_data,

		----------------------------------------------------------------
		-- Datapath characteristic
		----------------------------------------------------------------

		----------------------------------------------------------------
		-- Outputs to the rest of the design (comb results)
		----------------------------------------------------------------
		nextstate_HDC               => nextstate_HDC,
		busy_hdc_internal           => busy_hdc_internal,
		wb_ready                    => wb_ready,
		halt_hdc                    => halt_hdc,

		hdc_we_word                 => hdc_we_word,
		hdc_sci_req                 => hdc_sci_req,
		hdc_sci_we                  => hdc_sci_we,
		hdc_sc_write_addr           => hdc_sc_write_addr,
		hdc_sc_read_addr            => hdc_sc_read_addr,
		hdc_to_sc                   => hdc_to_sc,

		recover_state_wires         => recover_state_wires,
		hdc_except_data_wire        => hdc_except_data_wire
	);

    -- Exception Cont
	---------------------------------------------------------------------------------------------------------------------------------------------------------
	--  ██████╗ ██╗██████╗ ███████╗██╗     ██╗███╗   ██╗███████╗     ██████╗ ██████╗ ███╗   ██╗████████╗██████╗  ██████╗ ██╗     ██╗     ███████╗██████╗   --
	--  ██╔══██╗██║██╔══██╗██╔════╝██║     ██║████╗  ██║██╔════╝    ██╔════╝██╔═══██╗████╗  ██║╚══██╔══╝██╔══██╗██╔═══██╗██║     ██║     ██╔════╝██╔══██╗  --
	--  ██████╔╝██║██████╔╝█████╗  ██║     ██║██╔██╗ ██║█████╗      ██║     ██║   ██║██╔██╗ ██║   ██║   ██████╔╝██║   ██║██║     ██║     █████╗  ██████╔╝  --
	--  ██╔═══╝ ██║██╔═══╝ ██╔══╝  ██║     ██║██║╚██╗██║██╔══╝      ██║     ██║   ██║██║╚██╗██║   ██║   ██╔══██╗██║   ██║██║     ██║     ██╔══╝  ██╔══██╗  --
	--  ██║     ██║██║     ███████╗███████╗██║██║ ╚████║███████╗    ╚██████╗╚██████╔╝██║ ╚████║   ██║   ██║  ██║╚██████╔╝███████╗███████╗███████╗██║  ██║  --
	--  ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝  --
	---------------------------------------------------------------------------------------------------------------------------------------------------------

	u_pipeline_ctrl : entity work.HDCU_pipeline_ctrl
	generic map (
		ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
        SIMD                => SIMD,
		COUNTER_BITS        => COUNTER_BITS,
        COUNTERS_NUMBER     => COUNTERS_NUMBER,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH,
        SIMD_RD_BYTES       => SIMD_RD_BYTES
	)
	port map (
		clk_i                 => clk_i,
		rst_ni                => rst_ni,

		hdc_data_gnt_i        => hdc_data_gnt_i,
		busy_hdc              => busy_hdc,
		busy_hdc_internal     => busy_hdc_internal,
		nextstate_HDC         => nextstate_HDC,
		halt_hdc              => halt_hdc,

		HVSIZE_READ_lat       => HVSIZE_READ_lat(ADDR_WIDTH-1 downto 0),
		clip_processed_bytes  => clip_processed_bytes,

		AXI_HDC_INSTR           => AXI_HDC_INSTR(HDC_UNIT_INSTR_SET_SIZE-1 downto 0),
		AXI_HDC_INSTR_replicate => AXI_HDC_INSTR_replicate(HDC_UNIT_INSTR_SET_SIZE-1 downto 0),

		hdc_data_gnt_i_lat    => hdc_data_gnt_i_lat,
		state_HDC             => state_HDC,
		busy_hdc_internal_lat => busy_hdc_internal_lat,
		busy_hdc_lat          => busy_hdc_lat,
		halt_hdc_lat          => halt_hdc_lat,

		bundle_stage_1_en     => bundle_stage_1_en,
		bundle_stage_2_en     => bundle_stage_2_en,

		bind_stage_1_en       => bind_stage_1_en,
		bind_stage_2_en       => bind_stage_2_en,

		sim_stage_1_en        => sim_stage_1_en,
		sim_stage_2_en        => sim_stage_2_en,

		clip_stage_1_en       => clip_stage_1_en,
		clip_stage_2_en       => clip_stage_2_en,

		perm_stage_1_en       => perm_stage_1_en,
		perm_stage_2_en       => perm_stage_2_en,

		as_stage_1_en         => as_stage_1_en,
		as_stage_2_en         => as_stage_2_en,
		as_stage_3_en         => as_stage_3_en,

		bundle_en             => bundle_en,
		bind_en               => bind_en,
		sim_en                => sim_en,
		clip_en               => clip_en,
		perm_en               => perm_en,
		as_en                 => as_en
	);


	-----------------------------------------------------------------
	--  ███╗   ███╗ █████╗ ██████╗ ██████╗ ██╗███╗   ██╗ ██████╗   --
	--  ████╗ ████║██╔══██╗██╔══██╗██╔══██╗██║████╗  ██║██╔════╝   --
	--  ██╔████╔██║███████║██████╔╝██████╔╝██║██╔██╗ ██║██║  ███╗  --
	--  ██║╚██╔╝██║██╔══██║██╔═══╝ ██╔═══╝ ██║██║╚██╗██║██║   ██║  --
	--  ██║ ╚═╝ ██║██║  ██║██║     ██║     ██║██║ ╚████║╚██████╔╝  --
	--  ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚═╝╚═╝  ╚═══╝ ╚═════╝   --
	-----------------------------------------------------------------

	u_mapping : entity work.HDCU_mapping
	generic map (
		C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
		ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
		COUNTER_BITS        => COUNTER_BITS,
		COUNTERS_NUMBER     => COUNTERS_NUMBER,
        SIMD                => SIMD,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH,
        SIMD_RD_BYTES       => SIMD_RD_BYTES
	)
	port map (
		wb_ready                    => wb_ready,
		busy_hdc_internal_lat       => busy_hdc_internal_lat,
		state_HDC                   => state_HDC,

		AXI_HDC_INSTR_replicate_lat => AXI_HDC_INSTR_replicate_lat(HDC_UNIT_INSTR_SET_SIZE-1 downto 0),
		AXI_HDC_INSTR_replicate     => AXI_HDC_INSTR_replicate(HDC_UNIT_INSTR_SET_SIZE-1 downto 0), 

		hdc_sc_data_read            => hdc_sc_data_read,
		AXI_HVSIZE                  => AXI_HVSIZE,
		AXI_RS2                     => AXI_RS2,

		hdcu_out_bundle_results     => hdcu_out_bundle_results,
		hdcu_out_bind_results       => hdcu_out_bind_results,
		hdcu_out_sim_results        => hdcu_out_sim_results,
		hdcu_out_clip_results       => hdcu_out_clip_results,
		hdcu_out_perm_results       => hdcu_out_perm_results,

		temp_best_class_index       => temp_best_class_index,

		halt_hdc                    => halt_hdc,
		halt_hdc_lat                => halt_hdc_lat,
		hdc_sc_data_write_int       => hdc_sc_data_write_int,

		hdc_sc_data_write_wire_int  => hdc_sc_data_write_wire_int,
		hdc_sc_data_write_wire      => hdc_sc_data_write_wire,

		hdcu_in_bundle_operands     => hdcu_in_bundle_operands,
		hdcu_in_bind_operands       => hdcu_in_bind_operands,
		hdcu_in_sim_operands        => hdcu_in_sim_operands,
		hdcu_in_clip_operand_0      => hdcu_in_clip_operand_0,
		hdcu_in_clip_operand_1      => hdcu_in_clip_operand_1,
		hdcu_in_perm_operand_0      => hdcu_in_perm_operand_0,
		hdcu_in_perm_operand_1      => hdcu_in_perm_operand_1
	);

	----------------------------------------------------------------------------------------------------------
		-------------------------------FUNCTIONAL UNITS--------------------------------------------
	-- Binding Unit
	u_binding_unit : entity work.HDCU_binding_unit
    generic map (
		ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
        SIMD                => SIMD,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH
	)
	port map (
		clk_i                 => clk_i,
		rst_ni                => rst_ni,
		halt_hdc_lat          => halt_hdc_lat,
		bind_en               => bind_en,
		bind_stage_1_en       => bind_stage_1_en,
		recover_state_wires   => recover_state_wires,
		hdcu_in_bind_operands => hdcu_in_bind_operands,
		hdcu_out_bind_results => hdcu_out_bind_results
	);

	-- Bundling Unit
	u_bundling_unit : entity work.HDCU_bundling_unit
    generic map (
		ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
        SIMD                => SIMD,
		COUNTER_BITS        => COUNTER_BITS,
        COUNTERS_NUMBER     => COUNTERS_NUMBER,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH
	)
	port map (
		clk_i                   => clk_i,
		rst_ni                  => rst_ni,
		halt_hdc_lat            => halt_hdc_lat,
		bundle_en               => bundle_en,
		bundle_stage_1_en       => bundle_stage_1_en,
		recover_state_wires     => recover_state_wires,
		hdcu_in_bundle_operands => hdcu_in_bundle_operands,
		hdcu_out_bundle_results => hdcu_out_bundle_results,
		bundle_processed_bytes  => bundle_processed_bytes
	);

    -- Clipping Unit
	u_clipping_unit : entity work.HDCU_clipping_unit
    generic map (
		ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
        SIMD                => SIMD,
		COUNTER_BITS        => COUNTER_BITS,
        COUNTERS_NUMBER     => COUNTERS_NUMBER,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH
	)
	port map (
		clk_i                  => clk_i,
		rst_ni                 => rst_ni,
		halt_hdc_lat           => halt_hdc_lat,
		clip_en                => clip_en,
		clip_stage_1_en        => clip_stage_1_en,
		recover_state_wires    => recover_state_wires,
		hdcu_in_clip_operand_0 => hdcu_in_clip_operand_0,
		hdcu_in_clip_operand_1 => hdcu_in_clip_operand_1,
		hdcu_out_clip_results  => hdcu_out_clip_results,
		clip_processed_bytes   => clip_processed_bytes
	);

    -- intervento di Marco P per spezzare il percorso critico
    process(clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            hdcu_in_sim_operands_reg    <= (others => (others => '0'));

            sim_en_reg              <= '0';
            sim_stage_1_en_reg      <= '0';
            sim_stage_2_en_reg      <= '0';
            sim_stage_2_en_reg_2    <= '0';
            as_en_reg               <= '0';
            as_en_reg_2             <= '0';
            as_stage_1_en_reg       <= '0';
            as_stage_1_en_reg_2     <= '0';
            as_stage_1_en_reg_3     <= '0';
            as_stage_2_en_reg       <= '0';
            as_stage_3_en_reg       <= '0';
            as_stage_3_en_reg_2     <= '0';
            as_stage_3_en_reg_3     <= '0';

            AMSIZE_READ_lat_reg         <= (others => '0');
            AMSIZE_READ_lat_reg_2       <= (others => '0');
            AMSIZE_READ_lat_reg_3       <= (others => '0');
            hamming_distance_wire_reg   <= (others => '0');
            class_index_reg             <= 0;
            class_index_reg_2           <= 0;
            class_index_reg_3           <= 0;

        elsif rising_edge(clk_i) then
            hdcu_in_sim_operands_reg    <= hdcu_in_sim_operands;

            sim_en_reg           <= sim_en;
            sim_stage_1_en_reg   <= sim_stage_1_en;
            sim_stage_2_en_reg   <= sim_stage_2_en;
            sim_stage_2_en_reg_2 <= sim_stage_2_en_reg;
            as_en_reg            <= as_en;
            as_en_reg_2          <= as_en_reg;
            as_stage_1_en_reg    <= as_stage_1_en;
            as_stage_1_en_reg_2  <= as_stage_1_en_reg;
            as_stage_1_en_reg_3  <= as_stage_1_en_reg_2;
            as_stage_2_en_reg    <= as_stage_2_en;
            as_stage_3_en_reg    <= as_stage_3_en;
            as_stage_3_en_reg_2  <= as_stage_3_en_reg;
            as_stage_3_en_reg_3  <= as_stage_3_en_reg_2;

            AMSIZE_READ_lat_reg         <= AMSIZE_READ_lat;
            AMSIZE_READ_lat_reg_2       <= AMSIZE_READ_lat_reg;
            AMSIZE_READ_lat_reg_3       <= AMSIZE_READ_lat_reg_2;
            hamming_distance_wire_reg   <= hamming_distance_wire;

            class_index_reg     <= class_index;
            class_index_reg_2   <= class_index_reg;
            class_index_reg_3   <= class_index_reg_2;
        end if;
    end process;


  	-- Similarity Unit
	u_similarity_unit : entity work.HDCU_similarity_unit
	generic map (
        ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
        SIMD                => SIMD,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH,
		C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH
	)
	port map (
		clk_i                       => clk_i,
		rst_ni                      => rst_ni,
		halt_hdc_lat                => halt_hdc_lat,
		sim_en                      => sim_en_reg,
		sim_stage_1_en              => sim_stage_1_en_reg,
		AXI_HDC_INSTR_replicate_lat => AXI_HDC_INSTR_replicate_lat(HDC_UNIT_INSTR_SET_SIZE-1 downto 0),
		AMSIZE_READ_lat             => AMSIZE_READ_lat_reg,
		recover_state_wires         => recover_state_wires,
		hdcu_in_sim_operands        => hdcu_in_sim_operands_reg,
		hdcu_out_sim_results        => hdcu_out_sim_results,
		hamming_distance_wire       => hamming_distance_wire
	);

	-- Search Unit
	u_search_unit : entity work.HDCU_search_unit
	generic map (
        ADDR_WIDTH          => ADDR_WIDTH,
        SPM_NUM             => SPM_NUM,
        SIMD                => SIMD,
        SIMD_BITS           => SIMD_BITS,
        SIMD_WIDTH          => SIMD_WIDTH,
		C_S_AXI_DATA_WIDTH  => C_S_AXI_DATA_WIDTH
	)
	port map (
		clk_i                 => clk_i,
		rst_ni                => rst_ni,
		halt_hdc_lat          => halt_hdc_lat,
		as_en                 => as_en_reg_2,
		as_stage_1_en         => as_stage_1_en_reg_3,
		recover_state_wires   => recover_state_wires,
		AMSIZE_READ_lat       => AMSIZE_READ_lat_reg_3,
		hamming_distance_wire => hamming_distance_wire_reg,
		class_index           => class_index_reg_3,
		temp_best_class_index => temp_best_class_index
	);

	----------------------------------------------------------------------------------------------------------------------------
	-- ██████╗ ███████╗██████╗ ███████╗ ██████╗ ██████╗ ███╗   ███╗ █████╗ ███╗   ██╗ ██████╗███████╗                        --
	-- ██╔══██╗██╔════╝██╔══██╗██╔════╝██╔═══██╗██╔══██╗████╗ ████║██╔══██╗████╗  ██║██╔════╝██╔════╝                        --
	-- ██████╔╝█████╗  ██████╔╝█████╗  ██║   ██║██████╔╝██╔████╔██║███████║██╔██╗ ██║██║     █████╗                          --
	-- ██╔═══╝ ██╔══╝  ██╔══██╗██╔══╝  ██║   ██║██╔══██╗██║╚██╔╝██║██╔══██║██║╚██╗██║██║     ██╔══╝                          --
	-- ██║     ███████╗██║  ██║██║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║██║  ██║██║ ╚████║╚██████╗███████╗                        --
	-- ╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝                        --
	--  ██████╗ ██████╗ ██╗   ██╗███╗   ██╗████████╗███████╗██████╗     ██╗      ██████╗  ██████╗ ██╗ ██████╗               --
	-- ██╔════╝██╔═══██╗██║   ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗    ██║     ██╔═══██╗██╔════╝ ██║██╔════╝               --
	-- ██║     ██║   ██║██║   ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝    ██║     ██║   ██║██║  ███╗██║██║                    --
	-- ██║     ██║   ██║██║   ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗    ██║     ██║   ██║██║   ██║██║██║                    --
	-- ╚██████╗╚██████╔╝╚██████╔╝██║ ╚████║   ██║   ███████╗██║  ██║    ███████╗╚██████╔╝╚██████╔╝██║╚██████╗               --
	--  ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝    ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝ ╚═════╝               --
	----------------------------------------------------------------------------------------------------------------------------
	-- Performance Counter Logic
	-- Each counter tracks the number of clock cycles a functional unit is active
	-- Counters reset on 0->1 transition of enable signal (new operation start)
	-- Counter value is captured to AXI register on 1->0 transition (operation complete)
	----------------------------------------------------------------------------------------------------------------------------
	
	GEN_PERF_COUNTERS: if PERFORMANCE_COUNTER generate
	
		----------------------------------------------------------------------------------------------------------------------------
		-- BUNDLING UNIT PERFORMANCE COUNTER
		----------------------------------------------------------------------------------------------------------------------------
		process(clk_i, rst_ni)
		begin
			if rst_ni = '0' then
				perf_bundle_counter <= (others => '0');
				bundle_en_lat <= '0';
				perf_bundle_count_axi <= (others => '0');
			elsif rising_edge(clk_i) then
				bundle_en_lat <= bundle_en;
				
				-- Detect 0->1 transition: reset counter for new operation
				if bundle_en = '1' and bundle_en_lat = '0' then
					perf_bundle_counter <= (others => '0');
				-- Count while enable is high
				elsif bundle_en = '1' then
					perf_bundle_counter <= perf_bundle_counter + 1;
				end if;
				
				-- Detect 1->0 transition: copy counter value to AXI register
				if bundle_en = '0' and bundle_en_lat = '1' then
					perf_bundle_count_axi <= std_logic_vector(perf_bundle_counter);
				end if;
			end if;
		end process;
		
		----------------------------------------------------------------------------------------------------------------------------
		-- BINDING UNIT PERFORMANCE COUNTER
		----------------------------------------------------------------------------------------------------------------------------
		process(clk_i, rst_ni)
		begin
			if rst_ni = '0' then
				perf_bind_counter <= (others => '0');
				bind_en_lat <= '0';
				perf_bind_count_axi <= (others => '0');
			elsif rising_edge(clk_i) then
				bind_en_lat <= bind_en;
				
				-- Detect 0->1 transition: reset counter for new operation
				if bind_en = '1' and bind_en_lat = '0' then
					perf_bind_counter <= (others => '0');
				-- Count while enable is high
				elsif bind_en = '1' then
					perf_bind_counter <= perf_bind_counter + 1;
				end if;
				
				-- Detect 1->0 transition: copy counter value to AXI register
				if bind_en = '0' and bind_en_lat = '1' then
					perf_bind_count_axi <= std_logic_vector(perf_bind_counter);
				end if;
			end if;
		end process;
		
		----------------------------------------------------------------------------------------------------------------------------
		-- SIMILARITY UNIT PERFORMANCE COUNTER
		----------------------------------------------------------------------------------------------------------------------------
		process(clk_i, rst_ni)
		begin
			if rst_ni = '0' then
				perf_sim_counter <= (others => '0');
				sim_en_lat <= '0';
				perf_sim_count_axi <= (others => '0');
			elsif rising_edge(clk_i) then
				sim_en_lat <= sim_en;
				
				-- Detect 0->1 transition: reset counter for new operation
				if sim_en = '1' and sim_en_lat = '0' then
					perf_sim_counter <= (others => '0');
				-- Count while enable is high
				elsif sim_en = '1' then
					perf_sim_counter <= perf_sim_counter + 1;
				end if;
				
				-- Detect 1->0 transition: copy counter value to AXI register
				if sim_en = '0' and sim_en_lat = '1' then
					perf_sim_count_axi <= std_logic_vector(perf_sim_counter);
				end if;
			end if;
		end process;
		
		----------------------------------------------------------------------------------------------------------------------------
		-- CLIPPING UNIT PERFORMANCE COUNTER
		----------------------------------------------------------------------------------------------------------------------------
		process(clk_i, rst_ni)
		begin
			if rst_ni = '0' then
				perf_clip_counter <= (others => '0');
				clip_en_lat <= '0';
				perf_clip_count_axi <= (others => '0');
			elsif rising_edge(clk_i) then
				clip_en_lat <= clip_en;
				
				-- Detect 0->1 transition: reset counter for new operation
				if clip_en = '1' and clip_en_lat = '0' then
					perf_clip_counter <= (others => '0');
				-- Count while enable is high
				elsif clip_en = '1' then
					perf_clip_counter <= perf_clip_counter + 1;
				end if;
				
				-- Detect 1->0 transition: copy counter value to AXI register
				if clip_en = '0' and clip_en_lat = '1' then
					perf_clip_count_axi <= std_logic_vector(perf_clip_counter);
				end if;
			end if;
		end process;
		
		----------------------------------------------------------------------------------------------------------------------------
		-- PERMUTATION UNIT PERFORMANCE COUNTER
		----------------------------------------------------------------------------------------------------------------------------
		process(clk_i, rst_ni)
		begin
			if rst_ni = '0' then
				perf_perm_counter <= (others => '0');
				perm_en_lat <= '0';
				perf_perm_count_axi <= (others => '0');
			elsif rising_edge(clk_i) then
				perm_en_lat <= perm_en;
				
				-- Detect 0->1 transition: reset counter for new operation
				if perm_en = '1' and perm_en_lat = '0' then
					perf_perm_counter <= (others => '0');
				-- Count while enable is high
				elsif perm_en = '1' then
					perf_perm_counter <= perf_perm_counter + 1;
				end if;
				
				-- Detect 1->0 transition: copy counter value to AXI register
				if perm_en = '0' and perm_en_lat = '1' then
					perf_perm_count_axi <= std_logic_vector(perf_perm_counter);
				end if;
			end if;
		end process;
		
		----------------------------------------------------------------------------------------------------------------------------
		-- ASSOCIATIVE SEARCH UNIT PERFORMANCE COUNTER
		----------------------------------------------------------------------------------------------------------------------------
		process(clk_i, rst_ni)
		begin
			if rst_ni = '0' then
				perf_as_counter <= (others => '0');
				as_en_lat <= '0';
				perf_as_count_axi <= (others => '0');
			elsif rising_edge(clk_i) then
				as_en_lat <= as_en;
				
				-- Detect 0->1 transition: reset counter for new operation
				if as_en = '1' and as_en_lat = '0' then
					perf_as_counter <= (others => '0');
				-- Count while enable is high
				elsif as_en = '1' then
					perf_as_counter <= perf_as_counter + 1;
				end if;
				
				-- Detect 1->0 transition: copy counter value to AXI register
				if as_en = '0' and as_en_lat = '1' then
					perf_as_count_axi <= std_logic_vector(perf_as_counter);
				end if;
			end if;
		end process;
		
	end generate GEN_PERF_COUNTERS;
	
	----------------------------------------------------------------------------------------------------------------------------
	-- When performance counters are disabled, tie AXI outputs to zero
	----------------------------------------------------------------------------------------------------------------------------
	GEN_NO_PERF_COUNTERS: if not PERFORMANCE_COUNTER generate
		perf_bundle_count_axi <= (others => '0');
		perf_bind_count_axi   <= (others => '0');
		perf_sim_count_axi    <= (others => '0');
		perf_clip_count_axi   <= (others => '0');
		perf_perm_count_axi   <= (others => '0');
		perf_as_count_axi     <= (others => '0');
	end generate GEN_NO_PERF_COUNTERS;

end arch_imp;
