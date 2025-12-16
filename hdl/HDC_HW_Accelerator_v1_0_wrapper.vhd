library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.HDC_PKG.all;

entity HDC_HW_Accelerator_v1_0_wrapper is
	generic (
		---------------------------------------------
		-- Users to add parameters here
		---------------------------------------------
		SPM_NUM               : natural := 4;  
		ADDR_WIDTH            : natural := 16;  
		SIMD                  : natural := 1;
		COUNTER_BITS		  : natural := 4;
		PERFORMANCE_COUNTER   : boolean := true;
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
		clk_i			  : in std_logic;
		rst_ni			  : in std_logic;
        load_store_busy_o : out std_logic;
		
		-- HDC Status Signals
		done_hdc_o        : out std_logic;
		busy_hdc_o        : out std_logic;
		---------------------------------------------
		-- User ports ends
		-- Do not modify the ports beyond this line
		---------------------------------------------

		-- Axi-stream write port
		s_axis_tdata   :  in    std_logic_vector((SIMD*32)-1 downto 0);  
		s_axis_tvalid  :  in    std_logic;
		s_axis_tready  :  out   std_logic;
		s_axis_tlast   :  in    std_logic;

		-- Axi-stream read port
		m_axis_tdata   :  out   std_logic_vector((SIMD*32)-1 downto 0); 
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
end HDC_HW_Accelerator_v1_0_wrapper;

architecture wrapper_arch of HDC_HW_Accelerator_v1_0_wrapper is

	component HDC_HW_Accelerator is
		generic (
			SPM_NUM               : natural := 4;  
			ADDR_WIDTH            : natural := 16;  
			SIMD                  : natural := 1;
			COUNTER_BITS		  : natural := 4;
			PERFORMANCE_COUNTER   : boolean := false;
			C_S00_AXI_DATA_WIDTH  : integer := 32;
			C_S00_AXI_ADDR_WIDTH  : integer := 7
		);
		port (
			
			axis_clk		: in std_logic;
			rst_ni			: in std_logic;
			load_store_busy_o:out std_logic;
			
			-- HDC Status Signals
			done_hdc_o      : out std_logic;
			busy_hdc_o      : out std_logic;
			
			s_axis_tdata   	: in  std_logic_vector((SIMD*32)-1 downto 0);
			s_axis_tvalid  	: in  std_logic;
			s_axis_tready  	: out std_logic;
			s_axis_tlast   	: in  std_logic;
			m_axis_tdata   	: out std_logic_vector((SIMD*32)-1 downto 0);
			m_axis_tvalid  	: out std_logic;
			m_axis_tready  	: in  std_logic;
			m_axis_tlast   	: out std_logic;
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
	end component;

begin

	hdc_inst : HDC_HW_Accelerator
		generic map (
			SPM_NUM => SPM_NUM,
			ADDR_WIDTH => ADDR_WIDTH,
			SIMD => SIMD,
			COUNTER_BITS => COUNTER_BITS,
			PERFORMANCE_COUNTER => PERFORMANCE_COUNTER,
			C_S00_AXI_DATA_WIDTH => C_S00_AXI_DATA_WIDTH,
			C_S00_AXI_ADDR_WIDTH => C_S00_AXI_ADDR_WIDTH
		)
		port map (
			axis_clk => clk_i,    
			rst_ni => rst_ni,
			s_axis_tdata => s_axis_tdata,
			s_axis_tvalid => s_axis_tvalid,
			s_axis_tready => s_axis_tready,
			s_axis_tlast => s_axis_tlast,
			load_store_busy_o => load_store_busy_o,
			
			-- HDC Status Signals
			done_hdc_o => done_hdc_o,
			busy_hdc_o => busy_hdc_o,
			
			m_axis_tdata => m_axis_tdata,
			m_axis_tvalid => m_axis_tvalid,
			m_axis_tready => m_axis_tready,
			m_axis_tlast => m_axis_tlast,
			s00_axi_aclk => s00_axi_aclk,
			s00_axi_aresetn => s00_axi_aresetn,
			s00_axi_awaddr => s00_axi_awaddr,
			s00_axi_awprot => s00_axi_awprot,
			s00_axi_awvalid => s00_axi_awvalid,
			s00_axi_awready => s00_axi_awready,
			s00_axi_wdata => s00_axi_wdata,
			s00_axi_wstrb => s00_axi_wstrb,
			s00_axi_wvalid => s00_axi_wvalid,
			s00_axi_wready => s00_axi_wready,
			s00_axi_bresp => s00_axi_bresp,
			s00_axi_bvalid => s00_axi_bvalid,
			s00_axi_bready => s00_axi_bready,
			s00_axi_araddr => s00_axi_araddr,
			s00_axi_arprot => s00_axi_arprot,
			s00_axi_arvalid => s00_axi_arvalid,
			s00_axi_arready => s00_axi_arready,
			s00_axi_rdata => s00_axi_rdata,
			s00_axi_rresp => s00_axi_rresp,
			s00_axi_rvalid => s00_axi_rvalid,
			s00_axi_rready => s00_axi_rready
		);

end wrapper_arch;
