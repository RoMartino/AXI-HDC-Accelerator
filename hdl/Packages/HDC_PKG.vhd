-- ieee packages
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

package HDC_PKG is
    
    type array_2d           is array (integer range<>) of std_logic_vector;
    type array_2d_int       is array (integer range<>) of integer;
    type array_2d_csnt_int  is array (integer range<>) of integer range 0 to 24;
    type array_2d_shift_int is array (integer range<>) of integer range 0 to 7;
    type array_2d_int_sim   is array (integer range<>) of integer range 0 to 8192;
    
    type array_3d           is array (integer range<>) of array_2d;
    type array_3d_int       is array (integer range<>) of array_2d_int;
    type array_3d_csnt_int  is array (integer range<>) of array_2d_csnt_int;  

    type CountArray         is array (integer range<>) of std_logic_vector; 
    type CountArray2d       is array (integer range<>) of CountArray;
    type CountArray3d       is array (integer range<>) of CountArray2d;
    
    constant DATA_WIDTH              : natural := 32; 
    --constant SIMD                    : natural := 2;
    --constant SIMD_BITS               : natural := integer(ceil(log2(real(SIMD))));
    --constant SPM_NUM                 : natural := 4;    
    --constant SIMD_WIDTH              : natural := SIMD*Data_Width;
    constant HDC_INIT                : std_logic_vector(1 downto 0) := "00";
    constant HDC_HALT_HART           : std_logic_vector(1 downto 0) := "01";
    constant HDC_EXEC                : std_logic_vector(1 downto 0) := "10";
    --constant COUNTER_BITS            : natural := 4;
	--constant COUNTERS_NUMBER         : natural := DATA_WIDTH/COUNTER_BITS; 
	constant SIMILARITY_BITS         : natural := 32;

    constant HDC_UNIT_INSTR_SET_SIZE : natural := 8; 

    -- HDC UNIT BIT POSITION ------------------------
    constant HVBIND_bit_position    : natural := 0;
    constant HVBUNDLE_bit_position  : natural := 1;
    constant HVCLIP_bit_position    : natural := 2;
    constant HVPERM_bit_position    : natural := 3;
    constant HVSIM_bit_position     : natural := 4;
    constant HVSEARCH_bit_position  : natural := 5;
    constant HVMEMLD_bit_position   : natural := 6;
    constant HVMEMSTR_bit_position  : natural := 7;

    ----------------------------------------------------------------------------------------------------------------------------
    --  ███████╗██╗  ██╗ ██████╗███████╗██████╗ ████████╗██╗ ██████╗ ███╗   ██╗     ██████╗ ██████╗ ██████╗ ███████╗███████╗  --
    --  ██╔════╝╚██╗██╔╝██╔════╝██╔════╝██╔══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║    ██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔════╝  --
    --  █████╗   ╚███╔╝ ██║     █████╗  ██████╔╝   ██║   ██║██║   ██║██╔██╗ ██║    ██║     ██║   ██║██║  ██║█████╗  ███████╗  --
    --  ██╔══╝   ██╔██╗ ██║     ██╔══╝  ██╔═══╝    ██║   ██║██║   ██║██║╚██╗██║    ██║     ██║   ██║██║  ██║██╔══╝  ╚════██║  --
    --  ███████╗██╔╝ ██╗╚██████╗███████╗██║        ██║   ██║╚██████╔╝██║ ╚████║    ╚██████╗╚██████╔╝██████╔╝███████╗███████║  --
    --  ╚══════╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚═╝        ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝     ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝  --
    ----------------------------------------------------------------------------------------------------------------------------

    constant ILLEGAL_INSN_EXCEPT_CODE          : std_logic_vector(31 downto 0) := x"00000002";
    constant LOAD_ERROR_EXCEPT_CODE            : std_logic_vector(31 downto 0) := x"00000005";
    constant STORE_ERROR_EXCEPT_CODE           : std_logic_vector(31 downto 0) := x"00000007";
    constant ECALL_EXCEPT_CODE                 : std_logic_vector(31 downto 0) := x"0000000B";
    constant LOAD_MISALIGNED_EXCEPT_CODE       : std_logic_vector(31 downto 0) := x"00000004";
    constant STORE_MISALIGNED_EXCEPT_CODE      : std_logic_vector(31 downto 0) := x"00000006";
    constant ILLEGAL_VECTOR_SIZE_EXCEPT_CODE   : std_logic_vector(31 downto 0) := x"00000100"; 
    constant ILLEGAL_ADDRESS_EXCEPT_CODE       : std_logic_vector(31 downto 0) := x"00000101"; 
    constant SCRATCHPAD_OVERFLOW_EXCEPT_CODE   : std_logic_vector(31 downto 0) := x"00000102"; 
    constant READ_SAME_SCARTCHPAD_EXCEPT_CODE  : std_logic_vector(31 downto 0) := x"00000103"; 
    constant WRITE_SAME_SCARTCHPAD_EXCEPT_CODE : std_logic_vector(31 downto 0) := x"00000104";
    -- SPM specific overflow exception codes
    constant SPM_A_OVERFLOW_RS1_EXCEPT_CODE    : std_logic_vector(31 downto 0) := x"00000110"; 
    constant SPM_A_OVERFLOW_RS2_EXCEPT_CODE    : std_logic_vector(31 downto 0) := x"00000111"; 
    constant SPM_A_OVERFLOW_RD_EXCEPT_CODE     : std_logic_vector(31 downto 0) := x"00000112"; 
    constant SPM_B_OVERFLOW_RS1_EXCEPT_CODE    : std_logic_vector(31 downto 0) := x"00000120"; 
    constant SPM_B_OVERFLOW_RS2_EXCEPT_CODE    : std_logic_vector(31 downto 0) := x"00000121"; 
    constant SPM_B_OVERFLOW_RD_EXCEPT_CODE     : std_logic_vector(31 downto 0) := x"00000122"; 
    constant SPM_C_OVERFLOW_RS1_EXCEPT_CODE    : std_logic_vector(31 downto 0) := x"00000130"; 
    constant SPM_C_OVERFLOW_RS2_EXCEPT_CODE    : std_logic_vector(31 downto 0) := x"00000131"; 
    constant SPM_C_OVERFLOW_RD_EXCEPT_CODE     : std_logic_vector(31 downto 0) := x"00000132"; 
    constant SPM_D_OVERFLOW_RS1_EXCEPT_CODE    : std_logic_vector(31 downto 0) := x"00000140"; 
    constant SPM_D_OVERFLOW_RS2_EXCEPT_CODE    : std_logic_vector(31 downto 0) := x"00000141"; 
    constant SPM_D_OVERFLOW_RD_EXCEPT_CODE     : std_logic_vector(31 downto 0) := x"00000142"; 

    -- Function declarations
    function log2(x : integer) return integer;
    function popcount(x : std_logic_vector) return integer;
    
end package;

package body HDC_PKG is

    function log2(x : integer) return integer is
		begin
			return integer(ceil(log2(real(x))));
	end function;
	
	function popcount(x : std_logic_vector) return integer is
		variable count : integer := 0;
		begin
		for i in x'range loop
			if x(i) = '1' then
			count := count + 1;
			end if;
		end loop;
		return count;
	end function;

end package body;
