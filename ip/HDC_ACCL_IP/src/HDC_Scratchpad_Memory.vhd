library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;
use work.HDC_PKG.all;

entity Scratchpad_memory is
  generic(
    SPM_NUM             : natural := 4;  
    SIMD                : natural := 2;
    SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
    Data_Width          : natural := 32;
    ADDR_WIDTH          : natural
  );
  port(
      clk_i                 : in  std_logic;
      sc_we                 : in  std_logic_vector(SIMD*SPM_NUM-1 downto 0);
      sc_addr_wr            : in  array_2d(SIMD*SPM_NUM-1 downto 0)(ADDR_WIDTH-(SIMD_BITS+3) downto 0);
      sc_addr_rd            : in  array_2d(SIMD*SPM_NUM-1 downto 0)(ADDR_WIDTH-(SIMD_BITS+3) downto 0);
      sc_data_wr            : in  array_2d(SIMD*SPM_NUM-1 downto 0)(Data_Width-1 downto 0);
      sc_data_rd            : out array_2d(SIMD*SPM_NUM-1 downto 0)(Data_Width-1 downto 0)
  );
end Scratchpad_memory;

architecture RTL of Scratchpad_memory is

  -- Memory depth calculation
  constant MEM_DEPTH : integer := 2**(ADDR_WIDTH-(SIMD_BITS+2));
  
  -- Simple Dual Port RAM type - optimized for block RAM inference
  type ram_type is array (0 to MEM_DEPTH-1) of std_logic_vector(Data_Width-1 downto 0);

begin

  -- Generate individual memory banks - each bank is a separate Simple Dual Port RAM
  gen_banks : for b in 0 to SIMD*SPM_NUM-1 generate
  
    -- Individual memory bank signal with block RAM attribute
    signal mem_bank : ram_type := (others => (others => '0'));
    attribute ram_style : string;
    attribute ram_style of mem_bank : signal is "block";
    
  begin
  
    -- Simple Dual Port RAM process - Xilinx recommended template for separate R/W addresses
    -- This template guarantees block RAM inference
    mem_proc : process(clk_i)
    begin
      if rising_edge(clk_i) then
        -- Write port (when write enable is active)
        if sc_we(b) = '1' then
          mem_bank(to_integer(unsigned(sc_addr_wr(b)))) <= sc_data_wr(b);
        end if;
        
        -- Read port (independent read address, always active)
        sc_data_rd(b) <= mem_bank(to_integer(unsigned(sc_addr_rd(b))));
      end if;
    end process mem_proc;
    
  end generate gen_banks;

end RTL;

--------------------------------------------------------------------------------------------------
-- END of Scratchpad Memory architecture ---------------------------------------------------------
--------------------------------------------------------------------------------------------------
