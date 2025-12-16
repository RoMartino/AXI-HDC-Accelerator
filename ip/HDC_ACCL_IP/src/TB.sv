`timescale 1ns/1ps
module tb_HDC_HW_Accelerator;

  //---------------------------------------------------------------------------
  // Scratchpad memory parameters
  //---------------------------------------------------------------------------
  localparam int          SPM_NUM          = 4;
  localparam int          ADDR_WIDTH       = 20;

  localparam logic [31:0] SPM_A_START_ADDR = 32'h0000_0000;
  localparam logic [31:0] SPM_B_START_ADDR = 32'h0010_0000;
  localparam logic [31:0] SPM_C_START_ADDR = 32'h0020_0000;
  localparam logic [31:0] SPM_D_START_ADDR = 32'h0030_0000;

  // ---------------------------------------------------------------------------
  // Parallelism Level
  // ---------------------------------------------------------------------------
  localparam int DATA_WIDTH   = 32; 
  localparam int SIMD         = 16;
  localparam int SIMD_BITS    = $clog2(SIMD);
  localparam int SIMD_WIDTH   = DATA_WIDTH*SIMD; 
  localparam int PERF_CNT     = 0;
  localparam int COUNTER_BITS = 4; 
  localparam int COUNTER_NUM  = DATA_WIDTH/COUNTER_BITS; // Number of counters per 32-bit word (8 counters of 4 bits each) 

  // ---------------------------------------------------------------------------
  // HDC Model parameters
  // ---------------------------------------------------------------------------
  localparam int HV_SIZE_BIT  = 4096;              // Size of each HV in bits
  localparam int HV_CHUNKS    = HV_SIZE_BIT / 32; // Number of 32-bit chunks per HV
  localparam int HVSIZE_BYTES = HV_SIZE_BIT / 8;  // Size in bytes (compatibility)
  localparam int THRESHOLD    = 2;
  localparam int PERMUTATION  = 1;
  localparam int HVCLASS      = 4;

  // Instruction encodings
  typedef logic [31:0] instr_t;
  localparam instr_t HVBIND   = 32'h0000_0001;
  localparam instr_t HVBUNDLE = 32'h0000_0002;
  localparam instr_t HVCLIP   = 32'h0000_0004;
  localparam instr_t HVPERM   = 32'h0000_0008;
  localparam instr_t HVSIM    = 32'h0000_0010;
  localparam instr_t HVSEARCH = 32'h0000_0020;
  localparam instr_t HVMEMLD  = 32'h0000_0040;
  localparam instr_t HVMESTR  = 32'h0000_0080;

  // ---------------------------------------------------------------------------
  // Random HV Generation Functions
  // ---------------------------------------------------------------------------
  function automatic void generate_random_hv(ref logic [31:0] hv_array [0:HV_CHUNKS-1]);
    for (int i = 0; i < HV_CHUNKS; i++) hv_array[i] = $random();
  endfunction

  function automatic void generate_bundled_hv(ref logic [31:0] hv_array [0:HV_CHUNKS*COUNTER_BITS-1]);
    for (int i = 0; i < HV_CHUNKS*COUNTER_BITS; i++) hv_array[i] = $random();
  endfunction

  // ---------------------------------------------------------------------------
  // Clock & reset
  // ---------------------------------------------------------------------------
  logic clk  = 1'b0;
  logic rstn = 1'b0;
  always #5 clk = ~clk; // 100 MHz

  // ---------------------------------------------------------------------------
  // AXI-Lite
  // ---------------------------------------------------------------------------
  localparam int C_S_AXI_DATA_WIDTH  = 32;
  localparam int C_S_AXI_ADDR_WIDTH  = 8;
  localparam int WSTRB_WIDTH         = C_S_AXI_DATA_WIDTH/8;

  // AXI register map (byte offsets)
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_HVSIZE    = 8'h00;
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_RS1       = 8'h08;
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_RS2       = 8'h0C;
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_RD        = 8'h10;
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_HDC_INSTR = 8'h14;
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_HVCLASS   = 8'h18;
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_RSIZE     = 8'h20;  // Read size register
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_WSIZE     = 8'h24;
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_INTERRUPT = 8'h28;  // Interrupt control register
  localparam logic [C_S_AXI_ADDR_WIDTH-1:0] AXI_TEST      = 8'h7C;  // AXI_TEST register (address 31*4 = 124 = 0x7C)

  logic [C_S_AXI_ADDR_WIDTH-1:0] awaddr  = '0;  logic [2:0] awprot  = '0;  logic awvalid = 1'b0;  logic awready;
  logic [C_S_AXI_DATA_WIDTH-1:0] wdata   = '0;  logic [WSTRB_WIDTH-1:0] wstrb = {WSTRB_WIDTH{1'b1}}; logic wvalid  = 1'b0; logic wready;
  logic [1:0] bresp; logic bvalid; logic bready  = 1'b0;
  logic [C_S_AXI_ADDR_WIDTH-1:0] araddr  = '0;  logic [2:0] arprot  = '0;  logic arvalid = 1'b0;  logic arready;
  logic [C_S_AXI_DATA_WIDTH-1:0] rdata; logic [1:0] rresp; logic rvalid; logic rready  = 1'b0;

  // ---------------------------------------------------------------------------
  // AXI-Stream
  // ---------------------------------------------------------------------------
  logic [SIMD_WIDTH-1:0] s_axis_tdata; logic s_axis_tvalid; logic s_axis_tready; logic s_axis_tlast;
  logic [SIMD_WIDTH-1:0] m_axis_tdata; logic m_axis_tvalid; logic m_axis_tready; logic m_axis_tlast;
  logic [SIMD_WIDTH/2 -1:0]m_axis_1;
  logic [SIMD_WIDTH/2 -1:0]m_axis_2;

  // ---------------------------------------------------------------------------
  // HDC Busy Signal
  // ---------------------------------------------------------------------------
  logic done_hdc;
  logic rst_status;
  logic axi_is_working;

  // ---------------------------------------------------------------------------
  // HV Arrays
  // ---------------------------------------------------------------------------
  logic [31:0] HV1 [0:HV_CHUNKS-1];
  logic [31:0] HV2 [0:HV_CHUNKS-1];
  logic [31:0] HV_Bundled [0:HV_CHUNKS*COUNTER_BITS-1];
  logic [31:0] HV_Clipped [0:HV_CHUNKS-1];
  logic [31:0] Associative_Memory [0:HVCLASS-1][0:HV_CHUNKS-1];  

  // Result arrays
  logic [31:0] Result_HVBIND   [0:HV_CHUNKS-1];      
  logic [31:0] Result_HVSIM    [0:0];                
  logic [31:0] Result_HVPERM   [0:HV_CHUNKS-1];     
  logic [31:0] Result_HVSEARCH [0:0];               
  logic [31:0] Result_HVBUNDLE [0:HV_CHUNKS*COUNTER_BITS-1];
  logic [31:0] Result_HVCLIP   [0:HV_CHUNKS-1];
  logic [31:0] Result_generic   [0:HV_CHUNKS-1];

  // Golden/reference arrays (modello C)
  logic [31:0] Golden_HVBIND   [0:HV_CHUNKS-1];
  int          Golden_HVSIM;
  logic [31:0] Golden_HVPERM   [0:HV_CHUNKS-1];
  int          Golden_HVSEARCH;
  logic [31:0] Golden_HVBUNDLE [0:HV_CHUNKS*COUNTER_BITS-1];
  logic [31:0] Golden_HVCLIP   [0:HV_CHUNKS-1];

  // ---------------------------------------------------------------------------
  // Flag per stampa risultati operazioni (5–10)
  // ---------------------------------------------------------------------------
  bit PRINT_OP_RESULTS = 1'b1; // default ON; puoi disattivare con +PRINT_OP_RESULTS=0
  bit WRITE_SUMMARY_FILE = 1'b1; // default ON; puoi disattivare con +WRITE_SUMMARY_FILE=0
  
  initial begin
    int tmp;
    if ($value$plusargs("PRINT_OP_RESULTS=%d", tmp)) PRINT_OP_RESULTS = tmp[0];
    if ($value$plusargs("WRITE_SUMMARY_FILE=%d", tmp)) WRITE_SUMMARY_FILE = tmp[0];
  end

  // ---------------------------------------------------------------------------
  // Strutture per tabella riassuntiva e export su file
  // ---------------------------------------------------------------------------
  typedef struct {
    string name;
    int    errors;
    bit    pass;
  } testrec_t;

  testrec_t summary[$];

  task automatic add_test_result(string name, int errors);
    summary.push_back('{name:name, errors:errors, pass:(errors==0)});
  endtask

   // --- SOSTITUISCI CON QUESTE VERSIONI ---

  task automatic print_summary_table();
    int total_err = 0;
    int passed    = 0;

    // Accumuli
    foreach (summary[i]) begin
      total_err += summary[i].errors;
      if (summary[i].pass) passed++;
    end

    // Stampa tabella
    $display("");
    $display("============================================================");
    $display("                     RIEPILOGO TEST                         ");
    $display("============================================================");
    $display("%-4s | %-18s | %-6s | %-6s", "ID", "Operazione", "Stato", "Errori");
    $display("------------------------------------------------------------");
    for (int i = 0; i < summary.size(); i++) begin
      $display("%-4d | %-18s | %-6s | %-6d",
               (i+5), summary[i].name, (summary[i].pass ? "PASS" : "FAIL"), summary[i].errors);
    end
    $display("------------------------------------------------------------");
    $display("Totale errori: %0d  |  Test PASS: %0d/%0d",
             total_err, passed, summary.size());
    $display("============================================================");
  endtask


  task automatic write_summary_to_file(string fname="test_summary.txt");
    int fd;
    int total_err = 0;
    int passed    = 0;

    // Check if file writing is enabled
    if (!WRITE_SUMMARY_FILE) begin
      $display("Scrittura su file disabilitata (WRITE_SUMMARY_FILE=0).");
      return;
    end

    // Accumuli
    foreach (summary[i]) begin
      total_err += summary[i].errors;
      if (summary[i].pass) passed++;
    end

    fd = $fopen(fname, "w");
    if (fd == 0) begin
      $display("ATTENZIONE: impossibile aprire %s per scrittura.", fname);
      return;
    end

    // 1) Sezione parametri di simulazione
    $fdisplay(fd, "HDC HW ACCELERATOR - TEST LOG");
    $fdisplay(fd, "=============================");
    $fdisplay(fd, "");
    $fdisplay(fd, "PARAMETRI DI SIMULAZIONE");
    $fdisplay(fd, "========================");
    $fdisplay(fd, "HV_SIZE_BIT      : %0d", HV_SIZE_BIT);
    $fdisplay(fd, "HV_CHUNKS        : %0d", HV_CHUNKS);
    $fdisplay(fd, "COUNTER_BITS     : %0d", COUNTER_BITS);
    $fdisplay(fd, "COUNTER_NUM      : %0d", COUNTER_NUM);
    $fdisplay(fd, "HVCLASS          : %0d", HVCLASS);
    $fdisplay(fd, "THRESHOLD        : %0d", THRESHOLD);
    $fdisplay(fd, "PERMUTATION      : %0d", PERMUTATION);
    $fdisplay(fd, "DATA_WIDTH       : %0d", DATA_WIDTH);
    $fdisplay(fd, "SIMD             : %0d", SIMD);
    $fdisplay(fd, "");
    $fdisplay(fd, "CONFIGURAZIONE SCRATCHPAD MEMORY");
    $fdisplay(fd, "=================================");
    $fdisplay(fd, "SPM_NUM          : %0d", SPM_NUM);
    $fdisplay(fd, "ADDR_WIDTH       : %0d bit", ADDR_WIDTH);
    $fdisplay(fd, "");
    $fdisplay(fd, "MAPPA INDIRIZZI SPM:");
    $fdisplay(fd, "SPM_A (HV1)      : 0x%08x - 0x%08x (%0d bytes)", SPM_A_START_ADDR, SPM_A_START_ADDR + HVSIZE_BYTES - 1, HVSIZE_BYTES);
    $fdisplay(fd, "SPM_A (Bundled)  : 0x%08x - 0x%08x (%0d bytes)", SPM_A_START_ADDR + HV_CHUNKS*4, SPM_A_START_ADDR + HV_CHUNKS*4 + HVSIZE_BYTES*COUNTER_BITS - 1, HVSIZE_BYTES*COUNTER_BITS);
    $fdisplay(fd, "SPM_B (HV2)      : 0x%08x - 0x%08x (%0d bytes)", SPM_B_START_ADDR, SPM_B_START_ADDR + HVSIZE_BYTES - 1, HVSIZE_BYTES);
    $fdisplay(fd, "SPM_C (AM)       : 0x%08x - 0x%08x (%0d bytes)", SPM_C_START_ADDR, SPM_C_START_ADDR + HVSIZE_BYTES*HVCLASS - 1, HVSIZE_BYTES*HVCLASS);
    $fdisplay(fd, "SPM_D (Results)  : 0x%08x - 0x%08x (%0d bytes)", SPM_D_START_ADDR, SPM_D_START_ADDR + HVSIZE_BYTES*COUNTER_BITS - 1, HVSIZE_BYTES*COUNTER_BITS);
    $fdisplay(fd, "");
    
    // Calculate SPM utilization percentages
    begin
      automatic int spm_total_capacity = (1 << ADDR_WIDTH); // Total capacity per SPM in bytes
      automatic real spm_a_usage = real'(HVSIZE_BYTES) / real'(spm_total_capacity) * 100.0;
      automatic real spm_b_usage = real'(HVSIZE_BYTES) / real'(spm_total_capacity) * 100.0;
      automatic real spm_c_usage = real'(HVSIZE_BYTES*HVCLASS) / real'(spm_total_capacity) * 100.0;
      automatic real spm_d_usage = real'(HVSIZE_BYTES*COUNTER_BITS) / real'(spm_total_capacity) * 100.0;
      
      $fdisplay(fd, "UTILIZZO SPM:");
      $fdisplay(fd, "Capacità totale per SPM: %0d bytes (%0d KB)", spm_total_capacity, spm_total_capacity/1024);
      $fdisplay(fd, "SPM_A (HV1+Bundled): %0d/%0d bytes (%.1f%%) [HV1: %0d bytes, Bundled: %0d bytes]", 
               HVSIZE_BYTES + HVSIZE_BYTES*COUNTER_BITS, spm_total_capacity, 
               real'(HVSIZE_BYTES + HVSIZE_BYTES*COUNTER_BITS) / real'(spm_total_capacity) * 100.0,
               HVSIZE_BYTES, HVSIZE_BYTES*COUNTER_BITS);
      $fdisplay(fd, "SPM_B (HV2)      : %0d/%0d bytes (%.1f%%)", HVSIZE_BYTES, spm_total_capacity, spm_b_usage);
      $fdisplay(fd, "SPM_C (AM)       : %0d/%0d bytes (%.1f%%)", HVSIZE_BYTES*HVCLASS, spm_total_capacity, spm_c_usage);
      $fdisplay(fd, "SPM_D (Results)  : %0d/%0d bytes (%.1f%%)", HVSIZE_BYTES*COUNTER_BITS, spm_total_capacity, spm_d_usage);
    end
    $fdisplay(fd, "");

    // 2) Sezione operandi di ingresso
    $fdisplay(fd, "OPERANDI DI INGRESSO");
    $fdisplay(fd, "====================");
    $fdisplay(fd, "HV1 (Hypervector 1):");
    for (int i = 0; i < HV_CHUNKS; i++) begin
      $fdisplay(fd, "  [%0d] 0x%08x", i, HV1[i]);
    end
    $fdisplay(fd, "");
    $fdisplay(fd, "HV2 (Hypervector 2):");
    for (int i = 0; i < HV_CHUNKS; i++) begin
      $fdisplay(fd, "  [%0d] 0x%08x", i, HV2[i]);
    end
    $fdisplay(fd, "");
    $fdisplay(fd, "HV_Bundled (Bundled Hypervector input):");
    for (int i = 0; i < HV_CHUNKS*COUNTER_BITS; i++) begin
      $fdisplay(fd, "  [%0d] 0x%08x", i, HV_Bundled[i]);
    end
    $fdisplay(fd, "");
    $fdisplay(fd, "Associative Memory:");
    for (int i = 0; i < HVCLASS; i++) begin
      $fwrite(fd, "  AM[%0d]: ", i);
      for (int j = 0; j < HV_CHUNKS; j++) begin
        if (j == 0) $fwrite(fd, "0x%08x", Associative_Memory[i][j]);
        else        $fwrite(fd, "_%08x", Associative_Memory[i][j]);
      end
      $fdisplay(fd, "");
    end
    $fdisplay(fd, "");

    // 3) Sezione risultati test
    $fdisplay(fd, "RIEPILOGO TEST");
    $fdisplay(fd, "==============");
    $fdisplay(fd, "%-4s | %-18s | %-6s | %-6s", "ID", "Operazione", "Stato", "Errori");
    $fdisplay(fd, "------------------------------------------------------------");
    for (int i = 0; i < summary.size(); i++) begin
      $fdisplay(fd, "%-4d | %-18s | %-6s | %-6d",
                (i+5), summary[i].name, (summary[i].pass ? "PASS" : "FAIL"), summary[i].errors);
    end
    $fdisplay(fd, "------------------------------------------------------------");
    $fdisplay(fd, "Totale errori: %0d  |  Test PASS: %0d/%0d",
              total_err, passed, summary.size());
    $fdisplay(fd, "");
    
    // Debug section for failed tests
    if (total_err > 0) begin
      $fdisplay(fd, "DETTAGLI DEBUG PER TEST FALLITI");
      $fdisplay(fd, "================================");
      $fdisplay(fd, "");
      
      for (int i = 0; i < summary.size(); i++) begin
        if (!summary[i].pass) begin
          $fdisplay(fd, "TEST FALLITO: %s (ID: %0d, Errori: %0d)", summary[i].name, i+5, summary[i].errors);
          $fdisplay(fd, "---------------------------------------------");
          
          case (summary[i].name)
            "HVBIND": begin
              $fdisplay(fd, "HVBIND - Confronto HW vs Reference (tutti gli elementi):");
              for (int j = 0; j < HV_CHUNKS; j++) begin
                $fdisplay(fd, "  [%0d] HW=0x%08x  REF=0x%08x  %s", 
                         j, Result_HVBIND[j], Golden_HVBIND[j], 
                         (Result_HVBIND[j] === Golden_HVBIND[j]) ? "OK" : "MISMATCH");
              end
            end
            
            "HVSIM": begin
              $fdisplay(fd, "HVSIM - Confronto HW vs Reference:");
              $fdisplay(fd, "  HW=%0d  REF=%0d  %s", 
                       int'(Result_HVSIM[0]), Golden_HVSIM,
                       (int'(Result_HVSIM[0]) == Golden_HVSIM) ? "OK" : "MISMATCH");
            end
            
            "HVPERM": begin
              $fdisplay(fd, "HVPERM - Confronto HW vs Reference (tutti gli elementi):");
              for (int j = 0; j < HV_CHUNKS; j++) begin
                $fdisplay(fd, "  [%0d] HW=0x%08x  REF=0x%08x  %s", 
                         j, Result_HVPERM[j], Golden_HVPERM[j], 
                         (Result_HVPERM[j] === Golden_HVPERM[j]) ? "OK" : "MISMATCH");
              end
            end
            
            "HVSEARCH": begin
              $fdisplay(fd, "HVSEARCH - Confronto HW vs Reference:");
              $fdisplay(fd, "  HW=%0d  REF=%0d  %s", 
                       int'(Result_HVSEARCH[0]), Golden_HVSEARCH,
                       (int'(Result_HVSEARCH[0]) == Golden_HVSEARCH) ? "OK" : "MISMATCH");
            end
            
            "HVBUNDLE": begin
              $fdisplay(fd, "HVBUNDLE - Confronto HW vs Reference (tutti gli elementi):");
              for (int j = 0; j < HV_CHUNKS*COUNTER_BITS; j++) begin
                $fdisplay(fd, "  [%0d] HW=0x%08x  REF=0x%08x  %s", 
                         j, Result_HVBUNDLE[j], Golden_HVBUNDLE[j], 
                         (Result_HVBUNDLE[j] === Golden_HVBUNDLE[j]) ? "OK" : "MISMATCH");
              end
            end
            
            "HVCLIP": begin
              $fdisplay(fd, "HVCLIP - Confronto HW vs Reference (tutti gli elementi):");
              for (int j = 0; j < HV_CHUNKS; j++) begin
                $fdisplay(fd, "  [%0d] HW=0x%08x  REF=0x%08x  %s", 
                         j, Result_HVCLIP[j], Golden_HVCLIP[j], 
                         (Result_HVCLIP[j] === Golden_HVCLIP[j]) ? "OK" : "MISMATCH");
              end
            end
          endcase
          
          $fdisplay(fd, "");
        end
      end
    end
    $fclose(fd);

    $display("Tabella riassuntiva esportata in '%s'.", fname);
  endtask


  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------
  HDC_HW_Accelerator #(
    .SPM_NUM               (SPM_NUM),
    .ADDR_WIDTH            (ADDR_WIDTH),
    .SIMD                  (SIMD),   
//    .SIMD_BITS             (SIMD_BITS),
//    .SIMD_WIDTH            (SIMD*DATA_WIDTH),                
    .PERFORMANCE_COUNTER              (PERF_CNT),
    .C_S00_AXI_DATA_WIDTH  (C_S_AXI_DATA_WIDTH),
    .C_S00_AXI_ADDR_WIDTH  (C_S_AXI_ADDR_WIDTH)
  ) dut (
    .axis_clk           (clk),
    .rst_ni          (rstn),
    
    // .busy_hdc_o       (busy_hdc),
    
    // .done_hdc_o      (done_hdc),
    // .rst_status      (rst_status),
    // .axi_is_working  (axi_is_working),

    .s_axis_tdata    (s_axis_tdata),
    .s_axis_tvalid   (s_axis_tvalid),
    .s_axis_tready   (s_axis_tready),
    .s_axis_tlast    (s_axis_tlast),
    .s00_axi_aclk    (clk),

    .m_axis_tdata    (m_axis_tdata),
    .m_axis_tvalid   (m_axis_tvalid),
    .m_axis_tready   (m_axis_tready),
    .m_axis_tlast    (m_axis_tlast),    
    .s00_axi_aresetn (rstn),

    .s00_axi_awaddr  (awaddr),
    .s00_axi_awprot  (awprot),
    .s00_axi_awvalid (awvalid),
    .s00_axi_awready (awready),

    .s00_axi_wdata   (wdata),
    .s00_axi_wstrb   (wstrb),
    .s00_axi_wvalid  (wvalid),
    .s00_axi_wready  (wready),

    .s00_axi_bresp   (bresp),
    .s00_axi_bvalid  (bvalid),
    .s00_axi_bready  (bready),

    .s00_axi_araddr  (araddr),
    .s00_axi_arprot  (arprot),
    .s00_axi_arvalid (arvalid),
    .s00_axi_arready (arready),

    .s00_axi_rdata   (rdata),
    .s00_axi_rresp   (rresp),
    .s00_axi_rvalid  (rvalid),
    .s00_axi_rready  (rready)
  );

  // ---------------------------------------------------------------------------
  // Helper: stampa uniforme
  // ---------------------------------------------------------------------------
  task automatic print_header(input string title);
    $display("============================================================");
    $display("%s", title);
    $display("============================================================");
  endtask

  task automatic print_hypervector(input string name,
                                   input logic [31:0] hv[],
                                   input int size_chunks);
    print_header(name);
    for (int i = 0; i < size_chunks; i++) begin
      $display("[%0d] 0x%08x", i, hv[i]);
    end
  endtask

  task automatic print_scalar(input string name, input logic [31:0] value);
    print_header(name);
    $display("0x%08x (%0d)", value, value);
  endtask

  // ---------------------------------------------------------------------------
  // HDC Done Synchronization Tasks
  // ---------------------------------------------------------------------------
  task automatic wait_hdc_done(input int timeout_cycles = 10000);
    int cycle_count = 0;
    logic done_detected = 0;
    
    // Wait for done signal to go high (and stay high)
    while (!done_detected && cycle_count < timeout_cycles) begin
      @(posedge clk);
      if (done_hdc) begin
        done_detected = 1;
        break;
      end
      cycle_count++;
    end
    if (cycle_count >= timeout_cycles) begin
      $error("TIMEOUT: HDC done signal not detected within %0d cycles", timeout_cycles);
    end
    
    // Clear the interrupt by writing 1 to bit 1 of AXI_INTERRUPT
    axi_write(AXI_INTERRUPT, 32'h00000002);  // Set bit 1 to clear interrupt
  endtask

  task automatic hdc_operation_with_sync(input string op_name);
    // Enable interrupt by writing 1 to bit 0 of AXI_INTERRUPT
    axi_write(AXI_INTERRUPT, 32'h00000001);  // Set bit 0 to enable interrupt
    // Wait one cycle for signals to settle
    @(posedge clk);
    if (PRINT_OP_RESULTS) $display("Synchronization: %s operation ready to start (interrupt enabled)", op_name);
  endtask

  // ---------------------------------------------------------------------------
  // Reference model (equivalente al C) + confronto
  // ---------------------------------------------------------------------------
  function automatic void hv_bind_ref(
      input  logic [31:0] a   [0:HV_CHUNKS-1],
      input  logic [31:0] b   [0:HV_CHUNKS-1],
      output logic [31:0] out [0:HV_CHUNKS-1]
  );
    for (int i = 0; i < HV_CHUNKS; i++) begin
      out[i] = a[i] ^ b[i];
    end
  endfunction

  // HDC Similarity reference model (equivalent to C function)
  function automatic int hv_similarity_ref(
      input logic [31:0] hv1 [0:HV_CHUNKS-1],
      input logic [31:0] hv2 [0:HV_CHUNKS-1]
  );
    logic [31:0] xor_hv [0:HV_CHUNKS-1];
    int hamming_distance = 0;
    logic [31:0] x;
    int count;
    for (int i = 0; i < HV_CHUNKS; i++) begin
      xor_hv[i] = hv1[i] ^ hv2[i];
      x = xor_hv[i];
      count = 0;
      while (x != 0) begin
        x = x & (x - 1);
        count++;
      end
      hamming_distance += count;
    end
    return hamming_distance;
  endfunction

  // HDC Permutation reference model (equivalent to C function)
//  function automatic void hv_permutation_ref(
//      input  logic [31:0] hv_in  [0:HV_CHUNKS-1],
//      input  int shift,
//      output logic [31:0] hv_out [0:HV_CHUNKS-1]
//  );
//    logic [31:0] temp [0:HV_CHUNKS-1];
//    int effective_shift;
//    logic [31:0] overflow_bits;
//    logic [31:0] new_overflow_bits;
//    effective_shift = shift % (HV_CHUNKS * 32);
//    if (effective_shift == 0) begin
//      for (int i = 0; i < HV_CHUNKS; i++) hv_out[i] = hv_in[i];
//      return;
//    end
//    for (int i = 0; i < HV_CHUNKS; i++) temp[i] = hv_in[i];
//    overflow_bits = 0;
//    for (int i = 0; i < HV_CHUNKS; i++) begin
//      new_overflow_bits = temp[i] << (32 - effective_shift);
//      hv_out[i] = (temp[i] >> effective_shift) | overflow_bits;
//      overflow_bits = new_overflow_bits;
//    end
//    hv_out[0] = hv_out[0] | overflow_bits;
//  endfunction

function automatic void hv_permutation_ref(
    input  logic [31:0] hv_in  [0:HV_CHUNKS-1],
    input  int          shift,                 // shift in 32-bit blocks
    output logic [31:0] hv_out [0:HV_CHUNKS-1]
);
  int shift_blocks;

  if (HV_CHUNKS == 0) return;

  // Normalize to [0 .. HV_CHUNKS-1] and support negatives/large values
  shift_blocks = ((shift % HV_CHUNKS) + HV_CHUNKS) % HV_CHUNKS;

  // LEFT rotate by 'shift_blocks' blocks
  // Example: shift=2 -> move each element two positions toward lower indices.
  for (int i = 0; i < HV_CHUNKS; i++) begin
    hv_out[i] = hv_in[(i + HV_CHUNKS - shift_blocks) % HV_CHUNKS];
  end
endfunction

  // HDC Search reference model (equivalent to C function)
  function automatic int hv_search_ref(
      input logic [31:0] query_hv [0:HV_CHUNKS-1],
      input logic [31:0] associative_memory [0:HVCLASS-1][0:HV_CHUNKS-1]
  );
    logic [31:0] xor_hv [0:HV_CHUNKS-1];
    int hamming_distance;
    int best_distance;
    int best_index;
    logic [31:0] x;
    int count;
    best_distance = 10000;
    best_index = 0;
    for (int j = 0; j < HVCLASS; j++) begin
      hamming_distance = 0;
      for (int i = 0; i < HV_CHUNKS; i++) begin
        xor_hv[i] = associative_memory[j][i] ^ query_hv[i];
      end
      for (int i = 0; i < HV_CHUNKS; i++) begin
        x = xor_hv[i];
        count = 0;
        while (x != 0) begin
          x = x & (x - 1);
          count++;
        end
        hamming_distance += count;
      end
      $display("hamming distance %d: %h", j, hamming_distance);
      if (hamming_distance < best_distance) begin
        best_distance = hamming_distance;
        best_index = j;
      end
    end
    return best_index;
  endfunction

  // HDC Clipping reference model (equivalent to C function)
  function automatic void hv_clipping_ref(
      input  logic [31:0] bundled_hv [0:HV_CHUNKS*COUNTER_BITS-1],
      input  int hv_bundled_count,
      output logic [31:0] clipped_hv [0:HV_CHUNKS-1]
  );
//    int majority_threshold;
//    int k;
//    int j;
//    int bit_pos;
//    int bits_of_C;
//    majority_threshold = hv_bundled_count / 2;
//    for (int idx = 0; idx < HV_CHUNKS; idx++) clipped_hv[idx] = 32'h0;
//    k = 0;
//    j = 31;
//    for (int i = 0; i < HV_CHUNKS * COUNTER_BITS; i++) begin
//      if ((i % COUNTER_BITS == 0) && (i != 0)) begin
//        k++;
//        j = 31;
//      end
//      for (bit_pos = 32 - COUNTER_BITS; bit_pos >= 0; bit_pos -= COUNTER_BITS) begin
//        bits_of_C = (bundled_hv[i] >> bit_pos) & ((1 << COUNTER_BITS) - 1);
//        if (bits_of_C > majority_threshold) begin
//          clipped_hv[k] |= (1 << j);
//        end
//        j--;
//      end
//    end
    
   	int bundled_idx = 0;
   	int counter_idx = 0;
   	int current_counter = 0;
    $display("==================== Begin Clipping ============================");

    for(int i=0; i<HV_CHUNKS; i++) begin
    
//        $display("Current chunk [%02d]", i);
//        $display("Boundled chunk [%02d]: %h", bundled_idx, bundled_hv[bundled_idx]);
        
    	for(int j=0; j<DATA_WIDTH; j++) begin
    	

    		
    		if (counter_idx == 32) begin
    		  counter_idx = 0;
    		  bundled_idx++;
//			  $display("Boundled chunk [%02d]: %h", bundled_idx, bundled_hv[bundled_idx]);
    		end
    		
    		current_counter = bundled_hv[bundled_idx][counter_idx +: COUNTER_BITS];
//    		$display("Counter: %h", current_counter);

    	
            if(current_counter > hv_bundled_count/2) begin
                clipped_hv[i][j] = 1'b1;
            end else begin
                clipped_hv[i][j] = 1'b0;
            end
    	    		counter_idx += COUNTER_BITS;

    	end
    end
    
    for(int i=0; i< HV_CHUNKS; i++)
    	$display("Clipping ref %2d: %h", i, clipped_hv[i]);
  endfunction

  // HDC Bundling reference model (equivalent to C function)
  function automatic void hv_bundling_ref(
      input  logic [31:0] hv1_bundled [0:HV_CHUNKS*COUNTER_BITS-1],  // BundledHV HV1
      input  logic [31:0] hv2         [0:HV_CHUNKS-1],               // HV HV2
      output logic [31:0] bundled_out [0:HV_CHUNKS*COUNTER_BITS-1]   // BundledHV output
  );
    int j;
    int temp;
    int shift_amount;
    int b;
    int bits_of_A;
    int bit_of_B;
    int result_bits;
    int bit_pos;
    j = HV_CHUNKS - 1;
    for (int i = HV_CHUNKS * COUNTER_BITS - 1; i >= 0; i--) begin
      temp = 0;
      shift_amount = 32 - COUNTER_NUM - COUNTER_NUM * (i % COUNTER_BITS);
      b = (hv2[j] >> shift_amount) & ((1 << COUNTER_NUM) - 1);
      if ((i % COUNTER_BITS == 0) && (i != 0)) j--;
      for (bit_pos = 32 - COUNTER_BITS; bit_pos >= 0; bit_pos -= COUNTER_BITS) begin
        bits_of_A = (hv1_bundled[i] >> bit_pos) & ((1 << COUNTER_BITS) - 1);
        bit_of_B  = (b >> (bit_pos / COUNTER_BITS)) & 1;
        result_bits = bits_of_A + bit_of_B;
        if (result_bits > ((1 << COUNTER_BITS) - 1)) result_bits -= (1 << COUNTER_BITS);
        temp |= (result_bits << bit_pos);
      end
      bundled_out[i] = temp;
    end
    for(int i=0; i<HV_CHUNKS * COUNTER_BITS; i++) begin
    	$display("Bundling [%d]: %h", i, bundled_out[i]);
    end
  endfunction

  function automatic int compare_hv_vectors(
      input string name,
      input logic [31:0] got [0:HV_CHUNKS-1],
      input logic [31:0] exp [0:HV_CHUNKS-1],
      input int max_print
  );
    int errors = 0;
    for (int i = 0; i < HV_CHUNKS; i++) begin
      if (got[i] !== exp[i]) begin
        errors++;
        if (PRINT_OP_RESULTS && errors <= max_print)
          $display("Mismatch %s[%0d]: got=0x%08x exp=0x%08x", name, i, got[i], exp[i]);
        else if (PRINT_OP_RESULTS && errors == max_print + 1)
          $display("... (altri %0d errori non stampati)", HV_CHUNKS - i);
      end
    end
    return errors;
  endfunction

  function automatic int compare_bundled_hv_vectors(
      input string name,
      input logic [31:0] got [0:HV_CHUNKS*COUNTER_BITS-1],
      input logic [31:0] exp [0:HV_CHUNKS*COUNTER_BITS-1],
      input int max_print
  );
    int errors = 0;
    for (int i = 0; i < HV_CHUNKS*COUNTER_BITS; i++) begin
      if (got[i] !== exp[i]) begin
        errors++;
        if (PRINT_OP_RESULTS && errors <= max_print)
          $display("Mismatch %s[%0d]: got=0x%08x exp=0x%08x", name, i, got[i], exp[i]);
        else if (PRINT_OP_RESULTS && errors == max_print + 1)
          $display("... (altri %0d errori non stampati)", HV_CHUNKS*COUNTER_BITS - i);
      end
    end
    return errors;
  endfunction

  // ---------------------------------------------------------------------------
  // Helper tasks (senza print superflui)
  // ---------------------------------------------------------------------------
  task automatic axi_write(input logic [C_S_AXI_ADDR_WIDTH-1:0] addr,
                           input logic [C_S_AXI_DATA_WIDTH-1:0] data);
    @(posedge clk); awaddr<=addr; wdata<=data; awvalid<=1'b1; wvalid<=1'b1; bready<=1'b1;
    do @(posedge clk); while (!(awready && wready));
    awvalid<=1'b0; wvalid<=1'b0; do @(posedge clk); while (!bvalid);
    @(posedge clk); bready<=1'b0;
  endtask

  task automatic axi_read(input logic [C_S_AXI_ADDR_WIDTH-1:0] addr,
                          output logic [C_S_AXI_DATA_WIDTH-1:0] data);
    @(posedge clk); araddr<=addr; arvalid<=1'b1; rready<=1'b1;
    do @(posedge clk); while (!arready); arvalid<=1'b0;
    do @(posedge clk); while (!rvalid); data=rdata; @(posedge clk); rready<=1'b0;
  endtask

  task automatic axis_send_bytes(input logic [31:0] arr[], input int unsigned N_bytes);
    int n_words = N_bytes / (SIMD_WIDTH/8);
    int i = 0; 
    logic[SIMD_WIDTH-1:0] temp = 0;
    
    
    
    while (i < n_words) begin
    	for(int j=0; j<SIMD; j++) begin
    		temp[ DATA_WIDTH*j +: DATA_WIDTH ] = arr[i*SIMD+j];
//	    	$display("temp:%08x\n", temp);
//    		$display("temp:%08x\n", arr[i*SIMD+j]);
    	end
    	@(posedge clk);
    
    	$display("axis_send_bytes data:%08x", temp);
    	s_axis_tdata<=temp;
    
    	s_axis_tvalid<=1'b1;
    
    	if (s_axis_tready) 
    		i++;
    end
    @(posedge clk); 
    s_axis_tvalid<=1'b0;
  endtask

  task automatic simple_spm_write(input logic [31:0] spm_addr,
                                  ref logic [31:0] data_array[0:HV_CHUNKS-1],
                                  input string _unused);
    axi_write(AXI_WSIZE, C_S_AXI_DATA_WIDTH'(HVSIZE_BYTES));
    axi_write(AXI_RS1, spm_addr);
    axi_write(AXI_HDC_INSTR, HVMEMLD);
    
    axis_send_bytes(data_array, HVSIZE_BYTES);
    #(2000);
  endtask

  task automatic simple_spm_bundled_write(input logic [31:0] spm_addr,
                                          ref logic [31:0] data_array[0:HV_CHUNKS*HVCLASS-1],
                                          input string _unused);
    axi_write(AXI_WSIZE, C_S_AXI_DATA_WIDTH'(HVSIZE_BYTES*HVCLASS));
    axi_write(AXI_RS1, spm_addr);
    axi_write(AXI_HDC_INSTR, HVMEMLD);
    axis_send_bytes(data_array, HVSIZE_BYTES*HVCLASS);
  endtask 

  task automatic simple_spm_bundled_hv_write(input logic [31:0] spm_addr,
                                             ref logic [31:0] data_array[0:HV_CHUNKS*COUNTER_BITS-1],
                                             input string _unused);
    axi_write(AXI_WSIZE, C_S_AXI_DATA_WIDTH'(HVSIZE_BYTES*COUNTER_BITS));
    axi_write(AXI_RS1, spm_addr);
    axi_write(AXI_HDC_INSTR, HVMEMLD);
    axis_send_bytes(data_array, HVSIZE_BYTES*COUNTER_BITS);
  endtask 

  task automatic simple_spm_read(input logic [31:0] spm_addr,
                                 ref logic [31:0] read_data[0:HV_CHUNKS-1],
                                 input string _unused);
    int n_words = HV_CHUNKS/(SIMD); int i=0; int timeout=0;
    
    m_axis_tready<=1'b1; @(posedge clk);
    axi_write(AXI_RSIZE, C_S_AXI_DATA_WIDTH'(HVSIZE_BYTES));
    axi_write(AXI_RS1, spm_addr);
    axi_write(AXI_HDC_INSTR, HVMESTR);
    
    while (i < n_words && timeout < 1000) begin
      @(posedge clk);
      if (m_axis_tvalid && m_axis_tready) begin

		for(int j=0; j<SIMD; j++) begin
		   read_data[i*SIMD+j] = m_axis_tdata[ DATA_WIDTH*j +: DATA_WIDTH ]; 
		end     
        i++; 
        timeout=0;
      end else timeout++;
    end
    @(posedge clk); m_axis_tready<=1'b0;
    for (int j=i; j<n_words; j++) read_data[j]=32'hDEADBEEF;
  endtask

  task automatic spm_read_word(input logic [31:0] spm_addr,
                               ref logic [31:0] read_data[0:0]);
    int timeout=0;
    m_axis_tready<=1'b1; @(posedge clk);
    axi_write(AXI_RSIZE, C_S_AXI_DATA_WIDTH'(4));
    axi_write(AXI_RS1, spm_addr);
    axi_write(AXI_HDC_INSTR, HVMESTR);
    while (timeout < 1000) begin
      @(posedge clk);
      if (m_axis_tvalid && m_axis_tready) begin
        read_data[0] = m_axis_tdata; @(posedge clk); m_axis_tready<=1'b0; break; end
      else timeout++;
    end
    if (timeout>=1000) read_data[0]=32'hDEADBEEF;
    if (m_axis_tready) begin @(posedge clk); m_axis_tready<=1'b0; end
  endtask

  task automatic simple_spm_bundled_read(input logic [31:0] spm_addr,
                                         ref logic [31:0] read_data[0:HV_CHUNKS*COUNTER_BITS-1],
                                         input string _unused);
    int n_words = HV_CHUNKS*COUNTER_BITS/SIMD; int i=0; int timeout=0;
    m_axis_tready<=1'b1; @(posedge clk);
    axi_write(AXI_RSIZE, C_S_AXI_DATA_WIDTH'(HVSIZE_BYTES*COUNTER_BITS));
    axi_write(AXI_RS1, spm_addr);
    axi_write(AXI_HDC_INSTR, HVMESTR);
    while (i < n_words && timeout < 2000) begin
      @(posedge clk);
      if (m_axis_tvalid && m_axis_tready) begin 
//      	read_data[i]=m_axis_tdata; 
		for(int j=0; j<SIMD; j++) begin
		   read_data[i*SIMD+j] = m_axis_tdata[ DATA_WIDTH*j +: DATA_WIDTH ]; 
		end
		$display("bundling, read data [%02d]:", i, read_data[i]);
      	i++; 
      	timeout=0; 
    end
      else timeout++;
    end
    @(posedge clk); m_axis_tready<=1'b0;
    for (int j=i; j<n_words; j++) read_data[j]=32'hDEADBEEF;
  endtask

  // ---------------------------------------------------------------------------
  // Test sequence (solo le 10 stampe + verifica binding)
  // ---------------------------------------------------------------------------
  initial begin
    int i;

    // Init
    s_axis_tdata='0; s_axis_tvalid=1'b0; m_axis_tready=1'b1;
    awprot='0; arprot='0; arvalid=1'b0; rready=1'b0;

    // Reset
    rstn=1'b0; repeat(5) @(posedge clk); rstn=1'b1; repeat(5) @(posedge clk);

    // Check initial state of debug signals
    $display("=== Initial State Check ===");
    $display("rst_status: %b", rst_status);
    $display("axi_is_working: %b", axi_is_working);
    $display("done_hdc: %b", done_hdc);
    $display("===========================");

    // Inform HV byte size
    axi_write(AXI_HVSIZE, C_S_AXI_DATA_WIDTH'(HVSIZE_BYTES));

    // Generate data
    generate_random_hv(HV1);
    generate_random_hv(HV2);
    generate_bundled_hv(HV_Bundled);
    for (int hv=0; hv<HVCLASS; hv++) generate_random_hv(Associative_Memory[hv]);

    // 1) HV1
    print_hypervector("1) HV1", HV1, HV_CHUNKS);

    // 2) HV2
    print_hypervector("2) HV2", HV2, HV_CHUNKS);

    // LOAD into SPM
    hdc_operation_with_sync("HVMEMLD");
    simple_spm_write   (SPM_A_START_ADDR, HV1, "");
    wait_hdc_done();

    hdc_operation_with_sync("HVMEMLD");
    simple_spm_write   (SPM_B_START_ADDR, HV2, "");
    wait_hdc_done();
    
    hdc_operation_with_sync("HVMEMLD");
    simple_spm_bundled_hv_write(SPM_A_START_ADDR + HV_CHUNKS*4, HV_Bundled, "");
    wait_hdc_done();
    
    // 3) HV Bundled (input)
    print_hypervector("3) HV Bundled (input)", HV_Bundled, HV_CHUNKS*COUNTER_BITS);

    // (AM) write
    axi_write(AXI_WSIZE, C_S_AXI_DATA_WIDTH'(HVSIZE_BYTES*HVCLASS));
    axi_write(AXI_RS1,   SPM_C_START_ADDR);
    axi_write(AXI_HDC_INSTR, HVMEMLD);
    for (i = 0; i < HVCLASS; i++) begin 
    	axis_send_bytes(Associative_Memory[i], HVSIZE_BYTES);
	end
    // 4) Associative Memory
    print_header("4) Associative Memory");
    for (i=0; i<HVCLASS; i++) begin
      $write("AM[%0d]: ", i);
      for (int j = 0; j < HV_CHUNKS; j++) begin
        if (j == 0) $write("0x%08x", Associative_Memory[i][j]);
        else        $write("_%08x", Associative_Memory[i][j]);
      end
      $display("");
    end

    // OPERATIONS
    // (5) HVBIND: RD=SPMD, RS1=SPMA, RS2=SPMB
    hdc_operation_with_sync("HVBIND");
    axi_write(AXI_RD,  SPM_D_START_ADDR);
    axi_write(AXI_RS1, SPM_A_START_ADDR);
    axi_write(AXI_RS2, SPM_B_START_ADDR);
    axi_write(AXI_HDC_INSTR, HVBIND);
    wait_hdc_done();
    
//    simple_spm_read(SPM_D_START_ADDR + 1, Result_HVBIND, "");
//    print_hypervector("5) Risultato Binding (HV1 XOR HV2)", Result_HVBIND, HV_CHUNKS);
//    #10000;
//    $finish;

    // (6) HVSIM: RD=SPMD+HV_CHUNKS*4
    hdc_operation_with_sync("HVSIM");
    axi_write(AXI_RD,  SPM_D_START_ADDR + HV_CHUNKS*4);
    axi_write(AXI_RS1, SPM_A_START_ADDR);
    axi_write(AXI_RS2, SPM_B_START_ADDR);
    axi_write(AXI_HDC_INSTR, HVSIM);
    wait_hdc_done();

    // (7) HVPERM: RD=SPMD+(HV_CHUNKS+1)*4, RS1=SPMB, RS2=PERMUTATION
    hdc_operation_with_sync("HVPERM");
    axi_write(AXI_RD,  SPM_D_START_ADDR + 4*(HV_CHUNKS+1*SIMD));
    axi_write(AXI_RS1, SPM_B_START_ADDR);
    axi_write(AXI_RS2, C_S_AXI_DATA_WIDTH'(PERMUTATION));
    axi_write(AXI_HDC_INSTR, HVPERM);
    wait_hdc_done();

    // (8) HVSEARCH: write HVCLASS, RD=SPMD+(HV_CHUNKS+1+HV_CHUNKS)*4
    hdc_operation_with_sync("HVSEARCH");
    axi_write(AXI_HVCLASS, C_S_AXI_DATA_WIDTH'(HVCLASS*HVSIZE_BYTES));
    axi_write(AXI_RD,  SPM_D_START_ADDR + 4*(HV_CHUNKS + 1*SIMD + HV_CHUNKS));
    axi_write(AXI_RS1, SPM_A_START_ADDR);
    axi_write(AXI_RS2, SPM_C_START_ADDR);
    axi_write(AXI_HDC_INSTR, HVSEARCH);
    wait_hdc_done();

//    // (9) HVBUNDLE: RD=SPMD+(HV_CHUNKS+1+HV_CHUNKS+1)*4, RS1=SPMA+HV_CHUNKS*4
    hdc_operation_with_sync("HVBUNDLE");
    axi_write(AXI_RD,  SPM_D_START_ADDR + 4*(HV_CHUNKS + 1*SIMD + HV_CHUNKS + 1*SIMD));
    axi_write(AXI_RS1, SPM_A_START_ADDR + HV_CHUNKS*4);
    axi_write(AXI_RS2, SPM_B_START_ADDR);
    axi_write(AXI_HDC_INSTR, HVBUNDLE);
    wait_hdc_done();

//    // (10) HVCLIP: RD=SPMC+HV_CHUNKS*HVCLASS*4, RS1=prev result, RS2=THRESHOLD
    hdc_operation_with_sync("HVCLIP");
    axi_write(AXI_RD,  SPM_C_START_ADDR + HV_CHUNKS*HVCLASS*4);
    axi_write(AXI_RS1, SPM_D_START_ADDR + 4*(HV_CHUNKS + 1*SIMD + HV_CHUNKS + 1*SIMD));
    axi_write(AXI_RS2, C_S_AXI_DATA_WIDTH'(THRESHOLD));
    axi_write(AXI_HDC_INSTR, HVCLIP);
    wait_hdc_done();

    // READBACK + STAMPA (solo le 10 voci richieste)
    // 5) Risultato Binding (HV)
    simple_spm_read(SPM_D_START_ADDR, Result_HVBIND, "");
    if (PRINT_OP_RESULTS) print_hypervector("5) Risultato Binding (HV1 XOR HV2)", Result_HVBIND, HV_CHUNKS);

    // Verifica con modello C (bind XOR)
    hv_bind_ref(HV1, HV2, Golden_HVBIND);
    if (PRINT_OP_RESULTS) print_header("5) Verifica Binding (modello C)");
    begin
      automatic int errs = compare_hv_vectors("Binding", Result_HVBIND, Golden_HVBIND, 5);
      add_test_result("HVBIND", errs);
      if (PRINT_OP_RESULTS) begin
        if (errs == 0) $display("OK (0 errori)");
        else           $display("ERRORI=%0d", errs);
      end
    end

    // 6) Risultato Similarity (word)
    spm_read_word(SPM_D_START_ADDR + (HV_CHUNKS)*4, Result_HVSIM);
    if (PRINT_OP_RESULTS) print_scalar("6) Risultato Similarity (Hamming bits)", Result_HVSIM[0]);

    // Verifica con modello C (similarity Hamming distance)
    Golden_HVSIM = hv_similarity_ref(HV1, HV2);
    if (PRINT_OP_RESULTS) print_header("6) Verifica Similarity (modello C)");
    begin
      automatic int hw_result = int'(Result_HVSIM[0]);
      automatic int ref_result = Golden_HVSIM;
      automatic int errs_s = (hw_result == ref_result) ? 0 : 1;
      add_test_result("HVSIM", errs_s);
      if (PRINT_OP_RESULTS) begin
        if (errs_s == 0) $display("OK: HW=%0d, C=%0d (0 errori)", hw_result, ref_result);
        else             $display("ERRORE: HW=%0d, C=%0d (differenza=%0d)", hw_result, ref_result, hw_result - ref_result);
      end
    end
    //similarity funziona...

    // 7) Risultato Permutation (HV)
    simple_spm_read(SPM_D_START_ADDR + (HV_CHUNKS+1*SIMD)*4, Result_HVPERM, "");
    if (PRINT_OP_RESULTS) print_hypervector("7) Risultato Permutation (HV2 >> 4)", Result_HVPERM, HV_CHUNKS);

    // Verifica con modello C (permutation shift)
    hv_permutation_ref(HV2, PERMUTATION*SIMD, Golden_HVPERM);
    if (PRINT_OP_RESULTS) print_header("7) Verifica Permutation (modello C)");
    begin
      automatic int errs = compare_hv_vectors("Permutation", Result_HVPERM, Golden_HVPERM, 5);
      add_test_result("HVPERM", errs);
      if (PRINT_OP_RESULTS) begin
        if (errs == 0) $display("OK (0 errori)");
        else           $display("ERRORI=%0d", errs);
      end
    end

    // 8) Risultato Search (word = best index)
    spm_read_word(SPM_D_START_ADDR + (HV_CHUNKS + 1*SIMD + HV_CHUNKS)*4, Result_HVSEARCH);
    if (PRINT_OP_RESULTS) print_scalar("8) Risultato Search (best match index)", Result_HVSEARCH[0]);

    // Verifica con modello C (search in associative memory)
    Golden_HVSEARCH = hv_search_ref(HV1, Associative_Memory);
    if (PRINT_OP_RESULTS) print_header("8) Verifica Search (modello C)");
    begin
      automatic int hw_result = int'(Result_HVSEARCH[0]);
      automatic int ref_result = Golden_HVSEARCH;
      automatic int errs_s = (hw_result == ref_result) ? 0 : 1;
      add_test_result("HVSEARCH", errs_s);
      if (PRINT_OP_RESULTS) begin
        if (errs_s == 0) $display("OK: HW=%0d, C=%0d (0 errori)", hw_result, ref_result);
        else             $display("ERRORE: HW=%0d, C=%0d (differenza=%0d)", hw_result, ref_result, hw_result - ref_result);
      end
    end

    // 9) Risultato Bundling (bundled HV)
    simple_spm_bundled_read(SPM_D_START_ADDR + (HV_CHUNKS + 1*SIMD + HV_CHUNKS + 1*SIMD)*4, Result_HVBUNDLE, "");
    if (PRINT_OP_RESULTS) print_hypervector("9) Risultato Bundling", Result_HVBUNDLE, HV_CHUNKS*COUNTER_BITS);

    // Verifica con modello C (bundling operation)
    hv_bundling_ref(HV_Bundled, HV2, Golden_HVBUNDLE);
    if (PRINT_OP_RESULTS) print_header("9) Verifica Bundling (modello C)");
    begin
      automatic int errs = compare_bundled_hv_vectors("Bundling", Result_HVBUNDLE, Golden_HVBUNDLE, 20);
      add_test_result("HVBUNDLE", errs);
      if (PRINT_OP_RESULTS) begin
        if (errs == 0) $display("OK (0 errori)");
        else           $display("ERRORI=%0d su %0d elementi totali", errs, HV_CHUNKS*COUNTER_BITS);
      end
    end

    // 10) Risultato Clipping (HV)
    simple_spm_read(SPM_C_START_ADDR + HV_CHUNKS*HVCLASS*4, Result_HVCLIP, "");
    if (PRINT_OP_RESULTS) print_hypervector("10) Risultato Clipping", Result_HVCLIP, HV_CHUNKS);

    // Verifica con modello C (clipping operation)
    hv_clipping_ref(Golden_HVBUNDLE, THRESHOLD, Golden_HVCLIP);
    if (PRINT_OP_RESULTS) print_header("10) Verifica Clipping (modello C)");
    begin
      automatic int errs = compare_hv_vectors("Clipping", Result_HVCLIP, Golden_HVCLIP, 5);
      add_test_result("HVCLIP", errs);
      if (PRINT_OP_RESULTS) begin
        if (errs == 0) $display("OK (0 errori)");
        else           $display("ERRORI=%0d", errs);
      end
    end

    // =========================================================================
    // Test AXI_TEST removed - focusing on HDC functionality only
    // =========================================================================

    // >>> Stampa tabella riassuntiva + export su file
    print_summary_table();
    write_summary_to_file("test_summary.txt");

    $finish;
  end
endmodule
