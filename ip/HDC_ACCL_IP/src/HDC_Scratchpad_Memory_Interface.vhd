-- ieee packages ------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;

-- local packages ------------
use work.HDC_PKG.all;
--use work.klessydra_parameters.all;


entity SPM_Interface is
   generic(
        SPM_NUM             : natural := 4;  
        SIMD                : natural := 2;
        SIMD_BITS           : natural := integer(ceil(log2(real(SIMD))));
        SIMD_WIDTH          : natural := SIMD*DATA_WIDTH;
        ADDR_WIDTH            : natural     -- address width in byte of an entire SPM
   );
   port(
      clk_i, rst_ni  :  in    std_logic;

      -- Axi-stream write port
      s_axis_tdata   :  in    std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
      s_axis_tvalid  :  in    std_logic;
      s_axis_tready  :  out   std_logic;
      s_axis_tlast   :  in    std_logic;  -- When asserted, terminates DMA write transfer early

      -- Axi-stream read port
      m_axis_tdata   :  out   std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
      m_axis_tvalid  :  out   std_logic;
      m_axis_tready  :  in    std_logic;
      m_axis_tlast   :  out   std_logic;

      load_store_busy:   out std_logic;  -- set when interface is busy with load or stores

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
      DMA_addr_r     : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- starting address of spm for reading SPM, address of bytes
      DMA_SPM_sel_r  : in std_logic_vector(SPM_NUM-1 downto 0);     -- SPM select for read
      DMA_size_r     : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- size of transfer for read, size in byte
      DMA_r          : in std_logic;                                -- read enable

      DMA_addr_w     : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- starting address of spm for writing SPM, address of bytes
      DMA_SPM_sel_w  : in std_logic_vector(SPM_NUM-1 downto 0);     -- SPM select for write
      DMA_size_w     : in std_logic_vector(ADDR_WIDTH-1 downto 0);  -- size of transfer for write, size in byte
      DMA_w          : in std_logic;                                -- write enable

      DMA_start      : in std_logic                               -- start transfer bit

   );
end entity;

architecture SCI of SPM_Interface is

   signal s_axis_tready_int   : std_logic;
   signal m_axis_tdata_int    : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
   signal m_axis_tvalid_int   : std_logic;
   signal m_axis_tlast_int    : std_logic;

   signal hdc_sci_wr_gnt_int   : std_logic;
   signal hdc_data_gnt_i_int   : std_logic;

   -- counters used for writing and reading SPM from axis
   signal DMA_w_counter : integer;
   signal DMA_r_counter : integer;

   -- transfer information are saved into registers so that the spu can't overwrite them with an axi write
   signal DMA_addr_r_int      : std_logic_vector(ADDR_WIDTH-1 downto 0); 
   signal DMA_size_r_int      : std_logic_vector(ADDR_WIDTH-1 downto 0); 
   signal DMA_SPM_sel_r_int   : std_logic_vector(SPM_NUM-1 downto 0);
   signal DMA_addr_w_int      : std_logic_vector(ADDR_WIDTH-1 downto 0); 
   signal DMA_size_w_int      : std_logic_vector(ADDR_WIDTH-1 downto 0);
   signal DMA_SPM_sel_w_int   : std_logic_vector(SPM_NUM-1 downto 0);

   -- these indicates who read which spm in previous cycle
   signal hdcu_read_prev_1       : std_logic_vector(SPM_NUM-1 downto 0);   -- register
   signal hdcu_read_prev_1_int   : std_logic_vector(SPM_NUM-1 downto 0);   -- asynchronous   
   signal hdcu_read_prev_2       : std_logic_vector(SPM_NUM-1 downto 0);   -- register
   signal hdcu_read_prev_2_int   : std_logic_vector(SPM_NUM-1 downto 0);   -- asynchronous
   signal DMA_read_prev          : std_logic_vector(SPM_NUM-1 downto 0);   -- register
   signal DMA_read_prev_int      : std_logic_vector(SPM_NUM-1 downto 0);   -- asynchronous

   -- these are registers that are set when the sci receives a request
   signal DMA_reading      : std_logic;   -- register
   signal DMA_reading_int  : std_logic;   -- asynchronous
   signal DMA_writing      : std_logic;   -- register
   signal DMA_writing_int  : std_logic;   -- asynchronous

   -- Signal to track when DMA data is valid (accounting for SPM pipeline)
   signal DMA_data_valid   : std_logic;   -- High when SPM data is valid for DMA

   -- signals already present in the interface for the HDCU
   signal dsp_sc_data_write_int_wire      : std_logic_vector(SIMD*DATA_WIDTH-1 downto 0);
   signal rd_offset                       : array_2d(1 downto 0)(SIMD-1 downto 0);
   signal wr_offset                       : std_logic_vector(SIMD-1 downto 0);
   signal dsp_sc_data_read_int_wire       : array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
   signal dsp_sc_read_addr_lat            : array_2d(1 downto 0)(SIMD_BITS+1 downto 0);  --  Only need the lower part to check for the word access
   signal dsp_sc_data_read_wire           : array_2d(1 downto 0)(SIMD*DATA_WIDTH-1 downto 0);
   signal halt_hdc                        : std_logic;

   -- scratchpad memory signals
   signal sc_we_int      :  std_logic_vector(SIMD*SPM_NUM-1 downto 0);
   signal sc_addr_wr_int :  array_2d(SIMD*SPM_NUM-1 downto 0)(ADDR_WIDTH-(SIMD_BITS+3) downto 0);
   signal sc_addr_rd_int :  array_2d(SIMD*SPM_NUM-1 downto 0)(ADDR_WIDTH-(SIMD_BITS+3) downto 0);
   signal sc_data_wr_int :  array_2d(SIMD*SPM_NUM-1 downto 0)(Data_Width-1 downto 0);
   signal sc_data_rd_int :  array_2d(SIMD*SPM_NUM-1 downto 0)(Data_Width-1 downto 0);

   component Scratchpad_memory
      generic(
         SPM_NUM               : natural; 
         ADDR_WIDTH            : natural;
         SIMD                  : natural;
         --------------------------------
         SIMD_BITS             : natural;
         Data_Width            : natural
      );
      port(
         clk_i                 : in  std_logic;
         sc_we                 : in  std_logic_vector(SIMD*SPM_NUM-1 downto 0);
         sc_addr_wr            : in  array_2d(SIMD*SPM_NUM-1 downto 0)(ADDR_WIDTH-(SIMD_BITS+2) - 1 downto 0);
         sc_addr_rd            : in  array_2d(SIMD*SPM_NUM-1 downto 0)(ADDR_WIDTH-(SIMD_BITS+2) - 1 downto 0);
         sc_data_wr            : in  array_2d(SIMD*SPM_NUM-1 downto 0)(Data_Width-1 downto 0);
         sc_data_rd            : out array_2d(SIMD*SPM_NUM-1 downto 0)(Data_Width-1 downto 0)
      );
   end component;

begin

   -- component instantiation
   scratchpad_memory_inst: Scratchpad_memory
      generic map(
         SPM_NUM     => SPM_NUM, 
         ADDR_WIDTH  => ADDR_WIDTH,
         SIMD        => SIMD,
         SIMD_BITS   => SIMD_BITS,
         Data_Width  => Data_Width
      )
      port map(
         clk_i      => clk_i,
         sc_we      => sc_we_int,
         sc_addr_wr => sc_addr_wr_int,
         sc_addr_rd => sc_addr_rd_int,
         sc_data_wr => sc_data_wr_int,
         sc_data_rd => sc_data_rd_int
      );

   -- output assignments
   hdc_sci_wr_gnt <= hdc_sci_wr_gnt_int;
   hdc_data_gnt_i <= hdc_data_gnt_i_int;

   s_axis_tready <= s_axis_tready_int;
   m_axis_tvalid <= m_axis_tvalid_int;
   m_axis_tdata  <= m_axis_tdata_int;
   m_axis_tlast  <= m_axis_tlast_int;
   
   load_store_busy  <= DMA_reading or DMA_writing;

   process(clk_i, rst_ni)
   begin
      if rst_ni = '0' then
         DMA_reading <= '0';
         DMA_writing <= '0';
         DMA_addr_r_int <= (others => '0');
         DMA_size_r_int <= (others => '0');
         DMA_SPM_sel_r_int <= (others => '0');
         DMA_r_counter  <= 0;
         
         DMA_addr_w_int <= (others => '0');
         DMA_size_w_int <= (others => '0');
         DMA_w_counter  <= 0;
         DMA_SPM_sel_w_int <= (others => '0');

         dsp_sc_read_addr_lat <= (others => (others => '0'));
         halt_hdc             <= '0';
         
         -- Initialize DMA read previous signals
         DMA_read_prev        <= (others => '0');
         hdcu_read_prev_1     <= (others => '0');
         hdcu_read_prev_2     <= (others => '0');

         -- Initialize DMA data valid signal
         DMA_data_valid       <= '0';
         
         -- Note: m_axis_tlast_int is driven only by the combinational process to avoid multiple drivers

      elsif rising_edge(clk_i) then

         halt_hdc             <= '0';
         -- DMA_addr_r_int should NOT be reset every cycle! Only when transfer ends or starts   

         ----------------------- hdcu registers assignments ---------------------------
         if (hdc_sci_wr_gnt = '0' and hdc_sci_we /= (0 to SPM_NUM-1 => '0')) then
            halt_hdc <= '1';
         end if;

         if halt_hdc = '0' then
            hdc_sc_data_read <= dsp_sc_data_read_wire;
         end if;

         for i in 0 to SPM_NUM-1 loop
            if hdc_sci_req(i) = '1' then 
               for k in 0 to 1 loop
                  dsp_sc_read_addr_lat(k) <= '0' & hdc_sc_read_addr(k)(SIMD_BITS downto 0);
               end loop;
            end if;
         end loop;
         ----------------------- HDCU registers assignments ---------------------------

         -- update who read from spm in this cycle
         DMA_read_prev     <= DMA_read_prev_int;
         hdcu_read_prev_1  <= hdcu_read_prev_1_int;
         hdcu_read_prev_2  <= hdcu_read_prev_2_int;

         -----------------------------------------------
         --------------- DMA reading -------------------
         -----------------------------------------------

         -- FIXED: End transfer when we've read all data (counter equals transfer size)
         if (DMA_r_counter >= to_integer(unsigned(DMA_size_r_int))) and (DMA_reading = '1') then    -- end of transfer condition
            DMA_reading    <= '0';
            DMA_r_counter  <= 0;
            DMA_addr_r_int <= (others => '0');  -- Reset address only at end of transfer
            DMA_data_valid <= '0';  -- No more valid data

         elsif (DMA_start and DMA_r and (not DMA_reading)) then
            DMA_reading       <= '1';
            -- saving transfer info into registers
            DMA_addr_r_int    <= DMA_addr_r;
            DMA_size_r_int    <= DMA_size_r;
            DMA_SPM_sel_r_int <= DMA_SPM_sel_r;
            -- Start with address 0 to prime the SPM pipeline
            DMA_data_valid    <= '0';  -- Data not valid yet (SPM pipeline delay)
         
         -- checking if transfer has started
         elsif (DMA_reading_int) then

            -- Data becomes valid one cycle after reading starts (SPM pipeline)
            if (DMA_reading = '1') and (DMA_data_valid = '0') then
               DMA_data_valid <= '1';  -- Data is now valid from SPM
               -- At the same time, increment address to get second word ready while first is being prepared
               DMA_addr_r_int <= std_logic_vector(unsigned(DMA_addr_r_int) + 4*SIMD);
            end if;

            --checking if DMA can transmit data (complete handshake) and we haven't reached the end yet
            if m_axis_tready = '1' and m_axis_tvalid = '1' and (DMA_r_counter < to_integer(unsigned(DMA_size_r_int))) then

               -- counter value is the number of data already sent/received, so as soon as it reaches the size transfer we must stop
               DMA_r_counter  <= DMA_r_counter + 4*SIMD;    -- we store a word per bank, so 4 bytes per bank

               -- Increment address only during successful handshake to prepare next word
               -- Only increment if we need more words (total words = size_in_bytes / 4*SIMD)
               DMA_addr_r_int <= std_logic_vector(unsigned(DMA_addr_r_int) + 4*SIMD);
            end if;
         end if;


         -----------------------------------------------
         --------------- DMA writing -------------------
         -----------------------------------------------


         if (DMA_w_counter >= to_integer(unsigned(DMA_size_w_int))) and (DMA_writing = '1') then    -- end of transfer condition
            DMA_writing    <= '0';
            DMA_addr_w_int <= (others => '0');
            DMA_size_w_int <= (others => '0');
            DMA_w_counter  <= 0;
            --DMA_SPM_sel_w_int <= (others => '0');

         elsif ( DMA_start and DMA_w and (not DMA_writing)) then
            DMA_writing       <= '1';
            -- saving transfer info into registers
            DMA_addr_w_int    <= DMA_addr_w;
            DMA_size_w_int    <= DMA_size_w;
            DMA_SPM_sel_w_int <= DMA_SPM_sel_w;

         -- checking if transfer has started
         elsif (DMA_writing_int) then
            -- update tready

            --checking if DMA can receive next data
            if s_axis_tvalid = '1' then
               -- counter value is the number of data already sent/received, so as soon as it reaches the size transfer we must stop
               DMA_w_counter  <= DMA_w_counter + 4*SIMD;                          -- we store a word per bank, so 4 bytes per bank
               DMA_addr_w_int <= std_logic_vector(unsigned(DMA_addr_w_int) + 4*SIMD);  -- address is in word, we increment by 1 
               
               -- If tlast is asserted, terminate the transfer after this transaction
               if s_axis_tlast = '1' then
                  DMA_writing <= '0';
                  -- Update the actual transferred size to match what was received
                  DMA_size_w_int <= std_logic_vector(to_unsigned(DMA_w_counter + 4*SIMD, ADDR_WIDTH));
               end if;
            end if;
         end if;

      end if;
   end process;


   -- DMA transfer comb process
   process(all)
      
      variable sc_addr_rd_var : array_2d(SIMD*SPM_NUM-1 downto 0)(ADDR_WIDTH-(SIMD_BITS+3) downto 0);
      variable sc_addr_wr_var : array_2d(SIMD*SPM_NUM-1 downto 0)(ADDR_WIDTH-(SIMD_BITS+3) downto 0);

      variable hdcu_read_prev_1_var : std_logic_vector(SPM_NUM-1 downto 0);
      variable hdcu_read_prev_2_var : std_logic_vector(SPM_NUM-1 downto 0);
      variable DMA_read_prev_var    : std_logic_vector(SPM_NUM-1 downto 0);
      
   begin

      -- FIRST: Initialize m_axis_tlast_int to avoid X state
      m_axis_tlast_int <= '0';

      -- default values
      sc_addr_rd_var       := (others => (others => '0'));
      sc_addr_wr_var       := (others => (others => '0'));
      hdcu_read_prev_1_var := (others => '0');
      hdcu_read_prev_2_var := (others => '0');
      DMA_read_prev_var    := (others => '0');
      
      -- Default assignments for output signals to prevent latches
      dsp_sc_data_read_int_wire <= (others => (others => '0'));
      s_axis_tready_int <= '0';
      m_axis_tvalid_int <= '0';
      m_axis_tdata_int <= (others => '0');
      -- m_axis_tlast_int is initialized at the top of the process
      dsp_sc_data_write_int_wire <= (others => '0');
      dsp_sc_data_read_wire <= (others => (others => '0'));
      wr_offset <= (others => '0');
      rd_offset <= (others => (others => '0'));
      
      -- Initialize all scratchpad memory control signals to prevent latches
      sc_we_int <= (others => '0');
      sc_data_wr_int <= (others => (others => '0'));
     
      dsp_sc_data_read_int_wire <= (others => (others => '0'));

      rd_offset <= (others => (others => '0'));
      wr_offset <= (others => '0');

      DMA_reading_int <= DMA_reading;
      DMA_writing_int <= DMA_writing;

    
      -- by using an asynchronous signal we avoid performing an additional data transfer at last cycle
      -- FIXED: Keep DMA_reading_int active until we've read all data (counter equals or exceeds transfer size)
      if (DMA_r_counter >= to_integer(unsigned(DMA_size_r_int))) and (DMA_reading = '1') then
         DMA_reading_int <= '0';
      elsif (DMA_start and DMA_r and (not DMA_reading)) then
         DMA_reading_int <= '1';
      end if;

      -- by using an asynchronous signal we avoid performing an additional data transfer at last cycle
      if (DMA_w_counter >= to_integer(unsigned(DMA_size_w_int))) and (DMA_writing = '1') then
         DMA_writing_int <= '0';

      elsif ( DMA_start and DMA_w and (not DMA_writing) ) then
         DMA_writing_int <= '1';

      end if;


      -- grant signal for reading data
      hdc_data_gnt_i_int <= or hdc_sci_req;  -- we are supposing that the hdcu will never make 2 read requests to the same SPM in the same cycle...
      hdc_sci_wr_gnt_int <= or hdc_sci_we;
      
      --------------------------------------------------------------------------------
      ----------------------- Read and Write port assignment -------------------------
      --------------------------------------------------------------------------------
 
      for i in 0 to SPM_NUM-1 loop
         ------------------- read address ------------------------------
         -- here we decide who has priority in reading the SPM, if DMA or HDCU
         if (hdc_sci_req(i) = '1') then

            if (hdc_to_sc(i)(0) = '1') then  -- HDCU port 1

               hdcu_read_prev_1_var(i) := '1';    -- next cycle we know who read from that SPM
               for j in 0 to SIMD-1 loop
                  sc_addr_rd_var((SIMD)*i+j) := std_logic_vector(unsigned(hdc_sc_read_addr(0)(ADDR_WIDTH-1 downto SIMD_BITS+2)) + rd_offset(0)(j));
               end loop;

            elsif (hdc_to_sc(i)(1) = '1') then  -- HDCU port 2

               hdcu_read_prev_2_var(i) := '1';
               for j in 0 to SIMD-1 loop
                  sc_addr_rd_var((SIMD)*i+j) := std_logic_vector(unsigned(hdc_sc_read_addr(1)(ADDR_WIDTH-1 downto SIMD_BITS+2)) + rd_offset(1)(j));
               end loop;

            end if;

         elsif (DMA_SPM_sel_r_int(i) = '1' and DMA_reading_int = '1') then
            -- DMA read port - use current address directly
            DMA_read_prev_var(i) := '1';  -- we know that the DMA reads from this SPM
            for j in 0 to SIMD-1 loop
               sc_addr_rd_var((SIMD)*i+j) := DMA_addr_r_int(ADDR_WIDTH-1 downto (SIMD_BITS+2));
            end loop; 
         end if;

         ------------------- read value ------------------------------

         -- here we decide who has priority in reading the SPM, if DMA or HDCU
         if (hdcu_read_prev_1(i) = '1') then 
            for j in 0 to SIMD-1 loop
               dsp_sc_data_read_wire(0)(31+32*j downto 32*j) <= sc_data_rd_int((SIMD)*i+j);
            end loop;

         elsif (hdcu_read_prev_2(i) = '1') then
            for j in 0 to SIMD-1 loop
               dsp_sc_data_read_wire(1)(31+32*j downto 32*j) <= sc_data_rd_int((SIMD)*i+j);
            end loop;

         elsif (DMA_read_prev(i) = '1') and (DMA_SPM_sel_r_int(i) = '1') and (DMA_reading_int = '1') and (DMA_data_valid = '1') then
            -- DMA has valid data available - assert tvalid when we have data to transmit and haven't reached the end
            if (DMA_r_counter < to_integer(unsigned(DMA_size_r_int))) then
               m_axis_tvalid_int <= '1';
            else
               m_axis_tvalid_int <= '0';
            end if;
            for j in 0 to SIMD-1 loop
               m_axis_tdata_int((Data_Width-1+(Data_Width*j)) downto (Data_Width*j)) <= sc_data_rd_int(SIMD*i + j);
            end loop;

         end if;


         ------------------- write port ------------------------------
         if (hdc_sci_we(i) = '1') then         -- HDC write port;
            for j in 0 to SIMD-1 loop        
               sc_we_int((SIMD)*i+j)       <= hdc_we_word(j);
               sc_addr_wr_var((SIMD)*i+j)  := std_logic_vector(unsigned(hdc_sc_write_addr(ADDR_WIDTH-1 downto SIMD_BITS+2)) + wr_offset(j));
               sc_data_wr_int((SIMD)*i+j)  <= hdc_sc_data_write_wire(31+32*j downto 32*j);
            end loop;

         elsif (DMA_SPM_sel_w_int(i) = '1' and DMA_writing_int = '1') then
            -- Always assert tready when we're ready to receive data during DMA write
            s_axis_tready_int <= '1';
            
            -- Always keep address stable during DMA write, update data and write enable based on valid
            for j in 0 to SIMD-1 loop        
               sc_addr_wr_var((SIMD)*i+j) := DMA_addr_w_int(ADDR_WIDTH-1 downto (SIMD_BITS+2));
            end loop;
            
            -- Only write when valid data is available (proper AXI-Stream handshake)
            if (s_axis_tvalid = '1') then
               for j in 0 to SIMD-1 loop        
                  sc_we_int((SIMD)*i+j) <= '1';
                  sc_data_wr_int((SIMD)*i+j) <= s_axis_tdata((Data_Width-1+(Data_Width*j)) downto (Data_Width*j));
               end loop;
            else
               -- Don't write when data is not valid, but keep address stable
               for j in 0 to SIMD-1 loop        
                  sc_we_int((SIMD)*i+j) <= '0';
               end loop;
            end if;
         else
            -- Clear write enable when no write operation is active for this SPM
            for j in 0 to SIMD-1 loop
               sc_we_int((SIMD)*i+j) <= '0';
            end loop;
         end if; 

      end loop;

      -- Handle m_axis_tlast_int outside the loop to avoid multiple drivers
      -- Assert tlast when DMA is reading and this is the last transfer
      if (DMA_reading_int = '1') and (DMA_data_valid = '1') then
         -- Check if this is the last transfer (next increment would reach or exceed size)
         if (DMA_r_counter + 4*SIMD >= to_integer(unsigned(DMA_size_r_int))) then
            m_axis_tlast_int <= '1';
         end if;
      end if;


      ------------------------------------------------------------------------------------------------
      --  ██████╗  █████╗ ████████╗ █████╗     ██████╗  ██████╗ ████████╗ █████╗ ████████╗███████╗  --
      --  ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗    ██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗╚══██╔══╝██╔════╝  --
      --  ██║  ██║███████║   ██║   ███████║    ██████╔╝██║   ██║   ██║   ███████║   ██║   █████╗    --
      --  ██║  ██║██╔══██║   ██║   ██╔══██║    ██╔══██╗██║   ██║   ██║   ██╔══██║   ██║   ██╔══╝    --
      --  ██████╔╝██║  ██║   ██║   ██║  ██║    ██║  ██║╚██████╔╝   ██║   ██║  ██║   ██║   ███████╗  --
      --  ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝   ╚═╝   ╚══════╝  --
      ------------------------------------------------------------------------------------------------ 

    -- never forget

    --  for i in 0 to SIMD-1 loop
    --     if (hdc_sc_write_addr(SIMD_BITS+1 downto 0) = std_logic_vector(to_unsigned(4*i, SIMD_BITS+2))) and (i /= 0) then
    --        wr_offset(i-1 downto 0) <= (others => '1');
    --     end if;
    --  end loop;
    --  for i in 0 to SIMD-1 loop		  
    --     if hdc_sc_write_addr(SIMD_BITS+1 downto 0) = std_logic_vector(to_unsigned(4*i, SIMD_BITS+2)) then
    --        for j in 0 to SIMD-1 loop
    --           if j <= (SIMD-1)-i then
    --              dsp_sc_data_write_int_wire(31+32*(j+i) downto 32*(j+i)) <= hdc_sc_data_write_wire(31+32*j downto 32*j);
    --           elsif j > (SIMD-1)-i then
    --              dsp_sc_data_write_int_wire(31+32*(j-(SIMD-1)+(i-1)) downto 32*(j-(SIMD-1)+(i-1))) <= hdc_sc_data_write_wire(31+32*j downto 32*j);
    --           end if;
    --        end loop;
    --     end if;
    --  end loop;
	--  
    --  for k in 0 to 1 loop  -- index for the rs1 and rs2 read addresses
    --     for i in 0 to SIMD-1 loop -- index points to the 
    --        if (hdc_sc_read_addr(k)(SIMD_BITS+1 downto 0) = std_logic_vector(to_unsigned(4*i, SIMD_BITS+2))) and (i /= 0) then
    --           rd_offset(k)(i-1 downto 0) <= (others => '1'); -- sets the bank offset withing the scratchpad that will be used for the correct bank access
    --        end if;
    --     end loop;
    --     for i in 0 to SIMD-1 loop
    --        if dsp_sc_read_addr_lat(k) = std_logic_vector(to_unsigned(4*i, SIMD_BITS+2)) then
    --           for j in 0 to SIMD-1 loop
    --              if j >= i then
    --                 dsp_sc_data_read_wire(k)(31+32*(j-i) downto 32*(j-i)) <= dsp_sc_data_read_int_wire(k)(31+32*j downto 32*j);
    --              elsif j < i then
    --                 dsp_sc_data_read_wire(k)(31+32*((SIMD-1)-i+(j+1)) downto 32*((SIMD-1)-i+(j+1))) <= dsp_sc_data_read_int_wire(k)(31+32*j downto 32*j);
    --              end if;
    --           end loop;
    --        end if;
    --     end loop;
    --  end loop;



      -- variables assignment
      sc_addr_rd_int       <= sc_addr_rd_var;
      sc_addr_wr_int       <= sc_addr_wr_var;
      DMA_read_prev_int    <= DMA_read_prev_var;
      hdcu_read_prev_1_int <= hdcu_read_prev_1_var;
      hdcu_read_prev_2_int <= hdcu_read_prev_2_var;

   end process;

end architecture;




