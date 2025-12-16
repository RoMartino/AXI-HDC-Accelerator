library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

-- local packages
use work.HDC_PKG.all;

entity HDC_HW_Accelerator is
	generic (
		---------------------------------------------
		-- Users to add parameters here
		---------------------------------------------
		SPM_NUM         		: natural := 4;  
		ADDR_WIDTH      		: natural := 16;  
		SIMD            		: natural := 2;
		COUNTER_BITS			: natural := 4;
		PERFORMANCE_COUNTER     : boolean := false;
		---------------------------------------------
		-- User parameters ends
		-- Do not modify the parameters beyond this line
		---------------------------------------------

		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 7
	);
	port (
		---------------------------------------------
		-- Users to add ports here
		---------------------------------------------
		-- Clock and Reset
		axis_clk		: in std_logic;
		rst_ni			: in std_logic;
		
		-- SPM Interface Signals
        load_store_busy_o :   out std_logic;

		-- HDC Status Signals
		done_hdc_o		: out std_logic;  -- HDC done pulse signal (1 for one clock cycle when operation completes)
		busy_hdc_o      : out std_logic;  -- HDC busy signal
		---------------------------------------------
		-- User ports ends
		-- Do not modify the ports beyond this line
		---------------------------------------------

		-- Axi-stream write port
		s_axis_tdata   :  in    std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
		s_axis_tvalid  :  in    std_logic;
		s_axis_tready  :  out   std_logic;
		s_axis_tlast   :  in    std_logic;

		-- Axi-stream read port
		m_axis_tdata   :  out   std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
		m_axis_tvalid  :  out   std_logic;
		m_axis_tready  :  in    std_logic;
		m_axis_tlast   :  out   std_logic;

		-- Axi Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
	);
end HDC_HW_Accelerator;

architecture arch_imp of HDC_HW_Accelerator is

	------------------------------------------------------------
    -- ███████╗██╗ ██████╗ ███╗   ██╗ █████╗ ██╗     ███████╗ --
    -- ██╔════╝██║██╔════╝ ████╗  ██║██╔══██╗██║     ██╔════╝ --
    -- ███████╗██║██║  ███╗██╔██╗ ██║███████║██║     ███████╗ --
    -- ╚════██║██║██║   ██║██║╚██╗██║██╔══██║██║     ╚════██║ --
    -- ███████║██║╚██████╔╝██║ ╚████║██║  ██║███████╗███████║ --
    -- ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚══════╝ --
	------------------------------------------------------------

	constant SIMD_BITS          	: integer := integer(ceil(log2(real(SIMD))));
    constant SIMD_WIDTH         	: natural := SIMD*DATA_WIDTH;
    constant SIMD_RD_BYTES      	: integer := SIMD*DATA_WIDTH/8;

	signal hdc_sc_data_read 		: array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
	signal hdc_sci_wr_gnt 			: std_logic;
	signal hdc_data_gnt_i 			: std_logic;
	signal hdc_we_word 				: std_logic_vector(SIMD-1 downto 0);
	signal hdc_sc_data_write_wire 	: std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
	signal hdc_sc_write_addr 		: std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal hdc_sc_read_addr 		: array_2d(1 downto 0)(ADDR_WIDTH-1 downto 0);
	signal hdc_to_sc 				: array_2d(SPM_NUM-1 downto 0)(1 downto 0);
	signal hdc_sci_we 				: std_logic_vector(SPM_NUM-1 downto 0);
	signal hdc_sci_req 				: std_logic_vector(SPM_NUM-1 downto 0);

	signal DMA_addr_r 				: std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Indirizzo di partenza
	signal DMA_SPM_sel_r 			: std_logic_vector(SPM_NUM-1 downto 0);  -- Selezione SPM per lettura
	signal DMA_size_r 				: std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Dimensione della lettura in byte
	signal DMA_r 					: std_logic;  -- Indica che è richiesta una lettura

	signal DMA_addr_w 				: std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Indirizzo di partenza per scrittura
	signal DMA_SPM_sel_w 			: std_logic_vector(SPM_NUM-1 downto 0);  -- Selezione SPM per scrittura
	signal DMA_size_w 				: std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Dimensione della scrittura in byte
	signal DMA_w 					: std_logic;  -- Indica che è richiesta una scrittura

	signal DMA_start 				: std_logic;  -- Indica che è richiesta una operazione DMA

	---------------------------------------------------------------------------------------- 
	--  ██████╗ ██████╗ ███╗   ███╗██████╗  ██████╗ ███╗   ██╗███████╗███╗   ██╗████████╗ --
	-- ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔═══██╗████╗  ██║██╔════╝████╗  ██║╚══██╔══╝ --
	-- ██║     ██║   ██║██╔████╔██║██████╔╝██║   ██║██╔██╗ ██║█████╗  ██╔██╗ ██║   ██║    --
	-- ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║   ██║██║╚██╗██║██╔══╝  ██║╚██╗██║   ██║    --
	-- ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ╚██████╔╝██║ ╚████║███████╗██║ ╚████║   ██║    --
	--  ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═══╝   ╚═╝    --
	---------------------------------------------------------------------------------------- 	
 	component HDC_HW_Accelerator_v1_0_S00_AXI is
		generic (
			-----------------------------------------
			-- Users to add parameters here
			-----------------------------------------
			SPM_NUM                 : natural;  
		    ADDR_WIDTH              : natural;  
		    SIMD                    : natural;
			COUNTER_BITS			: natural;
		    PERFORMANCE_COUNTER     : boolean; 
            SIMD_BITS               : natural;
            SIMD_WIDTH              : natural;
            SIMD_RD_BYTES           : integer;
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
			---------------------------------------------------------------------------
			-- Users to add ports here
			---------------------------------------------------------------------------
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
			done_hdc_o    				: out std_logic;  -- HDC done pulse signal (1 for one clock cycle when operation completes)
			rst_status      			: out std_logic;  -- For debugging purposes
			axi_is_working  			: out std_logic;  -- For debugging purposes
			busy_hdc_o   			   	: out std_logic;  -- For debugging purposes
			--------------------------------------------------------------------------------
			-- User ports ends
			-- Do not modify the ports beyond this line
			--------------------------------------------------------------------------------
			S_AXI_ACLK		: in std_logic;
			S_AXI_ARESETN	: in std_logic;
			S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
			S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
			S_AXI_AWVALID	: in std_logic;
			S_AXI_AWREADY	: out std_logic;
			S_AXI_WDATA		: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
			S_AXI_WSTRB		: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
			S_AXI_WVALID	: in std_logic;
			S_AXI_WREADY	: out std_logic;
			S_AXI_BRESP		: out std_logic_vector(1 downto 0);
			S_AXI_BVALID	: out std_logic;
			S_AXI_BREADY	: in std_logic;
			S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
			S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
			S_AXI_ARVALID	: in std_logic;
			S_AXI_ARREADY	: out std_logic;
			S_AXI_RDATA		: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
			S_AXI_RRESP		: out std_logic_vector(1 downto 0);
			S_AXI_RVALID	: out std_logic;
			S_AXI_RREADY	: in std_logic
		);
	end component;
	
	component SPM_Interface is
		generic(
			SPM_NUM             : natural;  
            SIMD                : natural;
            SIMD_BITS           : natural;
            SIMD_WIDTH          : natural;
            ADDR_WIDTH          : natural     -- address width in byte of an entire SPM
		);
		port(
			-- Clock and Reset Signals
			clk_i, rst_ni  :  in    std_logic;

			-- Axi-stream write port
			s_axis_tdata   :  in    std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
			s_axis_tvalid  :  in    std_logic;
			s_axis_tready  :  out   std_logic;
			s_axis_tlast   :  in    std_logic;

			-- Axi-stream read port
			m_axis_tdata   :  out   std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
			m_axis_tvalid  :  out   std_logic;
			m_axis_tready  :  in    std_logic;
			m_axis_tlast   :  out   std_logic;

            load_store_busy : out   std_logic;

			---------------- HDCU ports -------------
			hdc_we_word             : in std_logic_vector(SIMD-1 downto 0);        -- write enable for a bank inside a SPM
			hdc_sc_data_write_wire  : in std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);  -- write data
			hdc_sc_write_addr       : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- write address, relative to a single SPM
			hdc_sc_read_addr        : in array_2d(1 downto 0)(ADDR_WIDTH-1 downto 0);
			hdc_to_sc               : in array_2d(SPM_NUM-1 downto 0)(1 downto 0);
			hdc_sci_we              : in std_logic_vector(SPM_NUM-1 downto 0);
			hdc_sci_req             : in std_logic_vector(SPM_NUM-1 downto 0);     -- memory req, 1 bit per SPM
			
			hdc_sc_data_read        : out array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
			hdc_sci_wr_gnt          : out std_logic;
			hdc_data_gnt_i          : out std_logic;

			-- Axi registers from hdcu
			DMA_addr_r     : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- starting address of spm for reading SPM, address of a word
			DMA_SPM_sel_r  : in std_logic_vector(SPM_NUM-1 downto 0);     -- SPM select for read
			DMA_size_r     : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- size of transfer for read, size in byte
			DMA_r          : in std_logic;                                -- read enable

			DMA_addr_w     : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- starting address of spm for writing SPM, address of a word
			DMA_SPM_sel_w  : in std_logic_vector(SPM_NUM-1 downto 0);     -- SPM select for write
			DMA_size_w     : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- size of transfer for write, size in byte
			DMA_w          : in std_logic;                                -- write enable

			DMA_start      : in std_logic                                 -- start transfer bit
		);
	end component;

begin

	-- Instantiation of Axi Bus Interface S00_AXI
	HDC_HW_Accelerator_v1_0_S00_AXI_inst : HDC_HW_Accelerator_v1_0_S00_AXI
		generic map (
			-----------------------------------------
			-- Users to add parameters here
			-----------------------------------------
			ADDR_WIDTH          => ADDR_WIDTH,
            SPM_NUM             => SPM_NUM,
            SIMD                => SIMD,
			COUNTER_BITS		=> COUNTER_BITS,
			PERFORMANCE_COUNTER => PERFORMANCE_COUNTER,
            SIMD_BITS           => SIMD_BITS,
            SIMD_WIDTH          => SIMD_WIDTH,    
            SIMD_RD_BYTES       => SIMD_RD_BYTES,   
			-----------------------------------------
			-- User parameters ends
			-- Do not modify the parameters beyond this line
			-----------------------------------------
			C_S_AXI_DATA_WIDTH	=> C_S00_AXI_DATA_WIDTH,
			C_S_AXI_ADDR_WIDTH	=> C_S00_AXI_ADDR_WIDTH
		)
		port map (
			---------------------------------------------------------------------------
			-- Users to add ports here
			---------------------------------------------------------------------------
			-- Clock and Reset Signals
			clk_i => axis_clk,
			rst_ni => rst_ni,

			-- SPM Interface Signals
			hdc_sc_data_read		=> hdc_sc_data_read,
			hdc_sci_wr_gnt			=> hdc_sci_wr_gnt,
			hdc_data_gnt_i			=> hdc_data_gnt_i,

			hdc_we_word				=> hdc_we_word,
			hdc_sc_data_write_wire	=> hdc_sc_data_write_wire,
			hdc_sc_write_addr		=> hdc_sc_write_addr,
			hdc_sc_read_addr		=> hdc_sc_read_addr,
			hdc_to_sc				=> hdc_to_sc,
			hdc_sci_we				=> hdc_sci_we,
			hdc_sci_req				=> hdc_sci_req,

			DMA_addr_r              => DMA_addr_r, 	  -- Indirizzo di partenza
			DMA_SPM_sel_r           => DMA_SPM_sel_r,  -- Selezione SPM per lettura
			DMA_size_r              => DMA_size_r, 	  -- Dimensione della lettura in byte
			DMA_r                   => DMA_r, 		  -- Indica che è richiesta una lettura

			DMA_addr_w              => DMA_addr_w, 	  -- Indirizzo di partenza per la scrittura
			DMA_SPM_sel_w           => DMA_SPM_sel_w,  -- Selezione SPM per scrittura
			DMA_size_w              => DMA_size_w, 	  -- Dimensione della scrittura in byte
			DMA_w                   => DMA_w, 		  -- Indica che è richiesta una scrittura

			DMA_start               => DMA_start, 	  -- Indica che è richiesta una operazione di DMA
			
			-- HDC Status Signals
			done_hdc_o              => done_hdc_o,
			busy_hdc_o              => busy_hdc_o,
			rst_status              => open,           -- Not connected (debug only)
			axi_is_working          => open,           -- Not connected (debug only)
			----------------------------------------------------------------------------------------------------
			-- User ports ends
			-- Do not modify the ports beyond this line
			----------------------------------------------------------------------------------------------------
			
			S_AXI_ACLK		=> s00_axi_aclk,
			S_AXI_ARESETN	=> s00_axi_aresetn,
			S_AXI_AWADDR	=> s00_axi_awaddr,
			S_AXI_AWPROT	=> s00_axi_awprot,
			S_AXI_AWVALID	=> s00_axi_awvalid,
			S_AXI_AWREADY	=> s00_axi_awready,
			S_AXI_WDATA		=> s00_axi_wdata,
			S_AXI_WSTRB		=> s00_axi_wstrb,
			S_AXI_WVALID	=> s00_axi_wvalid,
			S_AXI_WREADY	=> s00_axi_wready,
			S_AXI_BRESP		=> s00_axi_bresp,
			S_AXI_BVALID	=> s00_axi_bvalid,
			S_AXI_BREADY	=> s00_axi_bready,
			S_AXI_ARADDR	=> s00_axi_araddr,
			S_AXI_ARPROT	=> s00_axi_arprot,
			S_AXI_ARVALID	=> s00_axi_arvalid,
			S_AXI_ARREADY	=> s00_axi_arready,
			S_AXI_RDATA		=> s00_axi_rdata,
			S_AXI_RRESP		=> s00_axi_rresp,
			S_AXI_RVALID	=> s00_axi_rvalid,
			S_AXI_RREADY	=> s00_axi_rready
		);

	SPM_Interfance_inst: SPM_Interface
		generic map (
			ADDR_WIDTH          => ADDR_WIDTH,
            SPM_NUM             => SPM_NUM,
            SIMD                => SIMD,
            SIMD_BITS           => SIMD_BITS,
            SIMD_WIDTH          => SIMD_WIDTH
		)
		port map (
			-- Clock and Reset Signals
			clk_i		=> axis_clk,
			rst_ni		=> rst_ni,

			-- Axi-stream Ports from External Interface
			s_axis_tdata   => s_axis_tdata,
			s_axis_tvalid  => s_axis_tvalid,
			s_axis_tready  => s_axis_tready,
			s_axis_tlast   => s_axis_tlast,

			m_axis_tdata   => m_axis_tdata,
			m_axis_tvalid  => m_axis_tvalid,
			m_axis_tready  => m_axis_tready,
			m_axis_tlast   => m_axis_tlast,

            load_store_busy => load_store_busy_o,

			-- HDCU Interface Ports
			hdc_sc_data_read		=> hdc_sc_data_read,
			hdc_sci_wr_gnt			=> hdc_sci_wr_gnt,
			hdc_data_gnt_i			=> hdc_data_gnt_i,

			hdc_we_word				=> hdc_we_word,
			hdc_sc_data_write_wire	=> hdc_sc_data_write_wire,
			hdc_sc_write_addr		=> hdc_sc_write_addr,
			hdc_sc_read_addr		=> hdc_sc_read_addr,
			hdc_to_sc				=> hdc_to_sc,
			hdc_sci_we				=> hdc_sci_we,
			hdc_sci_req				=> hdc_sci_req,

			DMA_addr_r              => DMA_addr_r, 	  -- Indirizzo di partenza
			DMA_SPM_sel_r           => DMA_SPM_sel_r, -- Selezione SPM per lettura
			DMA_size_r              => DMA_size_r, 	  -- Dimensione della lettura in byte
			DMA_r                   => DMA_r, 		  -- Indica che è richiesta una lettura 
			
			DMA_addr_w              => DMA_addr_w, 	  -- Indirizzo di partenza per la scrittura
			DMA_SPM_sel_w           => DMA_SPM_sel_w, -- Selezione SPM per scrittura
			DMA_size_w              => DMA_size_w, 	  -- Dimensione della scrittura in byte
			DMA_w                   => DMA_w, 		  -- Indica che è richiesta una scrittura

			DMA_start               => DMA_start 	  -- Indica che è richiesta una operazione di DMA
		);

end arch_imp;
