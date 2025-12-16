#include "hdc_class.hpp"
#include <sys/time.h>
#include <time.h>
#include <stdint.h>

// ==================================================
// Constructor
// ==================================================
HDC_op::HDC_op(int dimensionality, int features, int levels) {
    HV_SIZE = dimensionality;
    num_features = features;
    num_levels = levels;
    
    // Initialize hardware memory mapping
    if (!initialize_hardware()) {
        printf("ERROR: Failed to initialize hardware\n");
        // You might want to throw an exception here
    }
}

// ==================================================
// Destructor
// ==================================================
HDC_op::~HDC_op() {
    cleanup_hardware();
}

// ==================================================
// Hardware Initialization
// ==================================================
bool HDC_op::initialize_hardware() {
    // Open memory device
    mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd < 0) { 
        perror("open");
        return false; 
    }

    // Memory mapping for hardware components
    dma_src_buffer  = mmap(NULL, DMA_BUFFERS_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, DMA_SRC_BUFFER);
    dma_dst_buffer  = mmap(NULL, DMA_BUFFERS_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, DMA_DST_BUFFER);
    hdc_base  = mmap(NULL, HDC_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, HDC_ACCL_BASE_ADDR);
    dma_base  = mmap(NULL, DMA_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, DMA_BASE_ADDR);
    gpio_base = mmap(NULL, GPIO_MAP_SIZE, PROT_READ| PROT_WRITE, MAP_SHARED, mem_fd, GPIO_BASE_ADDR);

    if (dma_base == MAP_FAILED || gpio_base == MAP_FAILED || dma_src_buffer == MAP_FAILED || dma_dst_buffer == MAP_FAILED || hdc_base == MAP_FAILED) {
        perror("mmap");
        cleanup_hardware();
        return false;
    }

    // Reset the HDC accelerator
    REG_WRITE(gpio_base, GPIO_DATA_2, ~RESET_MASK);
    usleep(100);
    REG_WRITE(gpio_base, GPIO_DATA_2, RESET_MASK);

    // Write the HV size to the HDC hardware
    REG_WRITE(hdc_base, AXI_HVSIZE, HVSIZE_BYTES);
    usleep(1000);

    #if DEBUG == 1
    printf("\n=========================================\n");
    printf("       Memory Mapping Information        \n");
    printf("=========================================\n");
    printf("DMA SRC BUFFER  @ 0x%08X → %p\n", DMA_SRC_BUFFER, dma_src_buffer);
    printf("DMA DST BUFFER  @ 0x%08X → %p\n", DMA_DST_BUFFER, dma_dst_buffer);
    printf("HDC             @ 0x%08X → %p\n", HDC_ACCL_BASE_ADDR, hdc_base);
    printf("DMA BASE        @ 0x%08X → %p\n", DMA_BASE_ADDR, dma_base);
    printf("GPIO            @ 0x%08X → %p\n", GPIO_BASE_ADDR, gpio_base);
    printf("=========================================\n\n");
    #endif

    return true;
}

// ==================================================
// Hardware Cleanup
// ==================================================
void HDC_op::cleanup_hardware() {
    if (dma_base != MAP_FAILED) {
        munmap(dma_base, DMA_MAP_SIZE);
    }
    if (gpio_base != MAP_FAILED) {
        munmap(gpio_base, GPIO_MAP_SIZE);
    }
    if (dma_src_buffer != MAP_FAILED) {
        munmap(dma_src_buffer, DMA_BUFFERS_MAP_SIZE);
    }
    if (dma_dst_buffer != MAP_FAILED) {
        munmap(dma_dst_buffer, DMA_BUFFERS_MAP_SIZE);
    }
    if (hdc_base != MAP_FAILED) {
        munmap(hdc_base, HDC_MAP_SIZE);
    }
    if (mem_fd >= 0) {
        close(mem_fd);
    }
}

// ===================================================
// Hardware Reset
// ===================================================
void HDC_op::reset_hardware() {
    // Reset the HDC accelerator
    REG_WRITE(gpio_base, GPIO_DATA, ~RESET_MASK);
    usleep(1000);
    REG_WRITE(gpio_base, GPIO_DATA, RESET_MASK);
    usleep(100);
}

// ===================================================
// HV Generation
// ===================================================
void HDC_op::generate_random_feature_vectors(float* feature_vector){
    for (int i = 0; i < DS_FEATURE_SIZE; i++) {
        feature_vector[i] = static_cast<float>(rand()) / static_cast<float>(RAND_MAX);
    }
}

void HDC_op::generate_LevelVectors(HV(&LevelVectors)[HD_LV_LEN])
{                   
    // Linear encoding
    // the first level vector is randomly initialized 
    int change_ratio;
    change_ratio = HV_SIZE_BIT / 2;   
    int indexVector[HV_SIZE_BIT];
    for (int i = 0; i < HV_SIZE_BIT; i++)
        indexVector[i] = 1;

    // Flipping random change_ratio bits
    LevelVectors[0].randomize();

    // The other level vectors are obtained flipping a number of bits equal to int(HD_DIM / (2 * totalLevel))
    // starting from the previous level vector. However, the same element can not be flipped 2 times
    change_ratio = HV_SIZE_BIT / (2 * num_levels);
    for (int level = 1; level < num_levels; level++)
    {
        LevelVectors[level] = LevelVectors[level - 1];
        int i=0;
        while (i < change_ratio)
        {
            int index = rand() % HV_SIZE_BIT;
            if (indexVector[index] == 1)
            {                
                indexVector[index] = 0;
                i++;

                if (LevelVectors[level - 1].chunk[index / 32] & (1 << (index % 32))) {
                    // If the bit is 1, set it to 0
                    LevelVectors[level].chunk[index / 32] &= ~(1 << (index % 32));
                } else {
                    // If the bit is 0, set it to 1
                    LevelVectors[level].chunk[index / 32] |= 1 << (index % 32);
                }
            }
        }
    }

    #if PRINT_LV
    printf("Level Vector Similarities:\n");
    for (int level = 1; level < num_levels; level++) {
        int hamming_distance = this->similarity(LevelVectors[0], LevelVectors[level]);
        printf("Similarity between LV[0] and LV[%d]: %d\n", level, hamming_distance);
    }
    printf("\n");
    #endif
} 

void HDC_op::generate_BaseVectors(HV(&baseVectors)[DS_FEATURE_SIZE]) {  
    for (int vec = 0; vec < DS_FEATURE_SIZE; vec++)
        baseVectors[vec].randomize();
    
    #if PRINT_BV
    printf("\nBase Vector Similarities:\n");
    for (int i = 0; i < DS_FEATURE_SIZE; i++) {
        for (int j = i + 1; j < DS_FEATURE_SIZE; j++) {
            int hamming_distance = this->similarity(baseVectors[i], baseVectors[j]);
            printf("Similarity between BV[%d] and BV[%d]: %d\n", i, j, hamming_distance);
        }
    }
    printf("\n");
    #endif
}

void generate_quantization_levels(float min, float max, float* LevelList) {
    double length = max - min;
    double gap = length / (HD_LV_LEN + 1);  // FIXED: divide by (HD_LV_LEN + 1)
    
    // Generate HD_LV_LEN + 2 levels
    for (int level = 0; level < HD_LV_LEN + 2; ++level) {
        LevelList[level] = min + level * gap;
    }
}

int get_quantized_level(float value, float quantization_levels[HD_LV_LEN + 2]) {
    // First check: is value at or below minimum threshold?
    if (value <= quantization_levels[0]) {
        return 0;
    }
    
    // Compare value against each level threshold
    // We iterate HD_LV_LEN + 1 times to check all boundaries
    for (int i = 1; i <= HD_LV_LEN; ++i) {
        if (value <= quantization_levels[i]) {
            return i - 1;  // Return the level before this threshold
        }
    }
    
    // If value is above all thresholds, return highest level
    return HD_LV_LEN - 1;
}

// ===================================================
// HDC Fundamentals Operations using Software
// ===================================================
uint32_t HDC_op::similarity(const HV(&HV1), const HV(&HV2)) {
    HV xor_HV;
    uint32_t hammingDistance = 0;

    for (int i = 0; i < HV_CHUNKS; i++){
        xor_HV.chunk[i] = HV1.chunk[i] ^ HV2.chunk[i];
        int x = xor_HV.chunk[i];
        int count = 0;
        for (count = 0; x; count++){
            x &= x - 1;
        }
        hammingDistance += count;
    }
    return hammingDistance;
}

HV HDC_op::bind(const HV(&HV1), const HV(&HV2)) {
    HV Binded_HV;
    for (int i = 0; i < HV_CHUNKS; i++) {
        Binded_HV.chunk[i] = HV1.chunk[i] ^ HV2.chunk[i];
    }
    return Binded_HV;
}

HV HDC_op::permutation(HV hv, int shift) {
    // The number of bits to shift within the bounds of the HV size
    int effective_shift = 32*SIMD*shift % (HV_CHUNKS * 32);

    if (effective_shift == 0) return hv;

    // Temporary array to store the original values of HV chunks
    uint32_t temp[HV_CHUNKS];

    // Copy the HV chunks into the temporary array
    for (int i = 0; i < HV_CHUNKS; i++) {
        temp[i] = hv.chunk[i];
    }

    // Shift bits within each chunk and carry over the overflow bits
    uint32_t overflow_bits = 0;
    uint32_t new_overflow_bits;
    for (int i = 0; i< HV_CHUNKS; i++) {
        new_overflow_bits = temp[i] << (32 - effective_shift);
        hv.chunk[i] = (temp[i] >> effective_shift) | overflow_bits;
        overflow_bits = new_overflow_bits;
    }

    // Integrate the last shifted bits into the first chunk
    hv.chunk[0] |= overflow_bits;

    return hv;
}

BundledHV HDC_op::bundle(const BundledHV (&HV1), const HV (&HV2)) const{
    int j = HV_CHUNKS - 1;
    BundledHV Bundled_HV;
    for (int i = HV_CHUNKS * COUNTER_BITS - 1; i >= 0; i--) {
        int temp = 0;
        int shift_amount = 32 - COUNTER_NUM - COUNTER_NUM * (i % COUNTER_BITS);
        int b = (HV2.chunk[j] >> shift_amount) & ((1 << COUNTER_NUM) - 1);
        if (i % COUNTER_BITS == 0 && i != 0) j--;
        
        for (int bit = 32 - COUNTER_BITS; bit >= 0; bit -= COUNTER_BITS) {
            int bits_of_A = (HV1.bundled_chunk[i] >> bit) & ((1 << COUNTER_BITS) - 1);
            int bit_of_B = (b >> (bit / COUNTER_BITS)) & 1;
            int result_bits = bits_of_A + bit_of_B;
            if (result_bits > (1 << COUNTER_BITS) - 1) result_bits -= 1 << COUNTER_BITS;
            temp |= (result_bits << bit);
        }
        Bundled_HV.bundled_chunk[i] = temp;
    }
    return Bundled_HV;
}

HV HDC_op::clip(const BundledHV &bundled_hv, int hv_bundled_count) {
    HV D_SW;

    int bundled_idx    = 0;
    int counter_idx    = 0;
    int current_counter = 0;
    int majority_threshold = hv_bundled_count / 2;

    // Inizializza l'iper-vettore di output a zero
    for (int i = 0; i < HV_CHUNKS; i++) {
        D_SW.chunk[i] = 0;
    }

    // Per ogni chunk dell'HV
    for (int i = 0; i < HV_CHUNKS; i++) {
        // Per ogni bit del chunk (DATA_WIDTH deve corrispondere a 32 in SV)
        for (int j = 0; j < 32; j++) {

            // Ogni volta che abbiamo esaurito i 32 bit della word, passiamo alla successiva
            if (counter_idx == 32) {
                counter_idx = 0;
                bundled_idx++;
            }

            // Estrai COUNTER_BITS a partire da counter_idx (equivalente a [counter_idx +: COUNTER_BITS])
            uint32_t word = bundled_hv.bundled_chunk[bundled_idx];
            current_counter = (word >> counter_idx) & ((1u << COUNTER_BITS) - 1u);

            // Majority: se il contatore supera hv_bundled_count/2, setti il bit a 1
            if (current_counter > majority_threshold) {
                D_SW.chunk[i] |= (1u << j);  // j è il bit index, LSB-first come in SV
            }
            // else: il bit rimane 0 perché D_SW è stato azzerato

            // Passa al contatore successivo
            counter_idx += COUNTER_BITS;
        }
    }

    return D_SW;
}

uint8_t HDC_op::search(HV QueryHV, HV (&associativeMemory)[HD_CV_LEN]) {
    
    uint8_t bestIndex = 0;
    uint32_t bestDistance = HV_SIZE_BIT;

    for (int j = 0; j < HD_CV_LEN; j++) {
        
        uint32_t hammingDistance = this->similarity(QueryHV, associativeMemory[j]);
        
        #if DEBUG == 1
        printf("Hamming distance for class %d = %d\n", j, hammingDistance);
        #endif

        if(j == 0){
            bestDistance = hammingDistance;
            bestIndex = j;
        }
        else if (hammingDistance < bestDistance) {
            bestDistance = hammingDistance;
            bestIndex = j;
        }
        else{
            bestDistance = bestDistance;
            bestIndex = bestIndex;
        }
    }
    return bestIndex;
}

// ===================================================
// HDC Composite Operations using Software
// ===================================================
HV HDC_op::encoding(uint32_t* quantized_features, HV (&BaseVectors)[DS_FEATURE_SIZE], HV (&LevelVectors)[HD_LV_LEN]) {
    
    BundledHV Encoded_HV; 
    
    #if DEBUG
    printf("SW Encoding...\n");
    #endif

    for (int i = 0; i < DS_FEATURE_SIZE; i++) {
        HV tmp = this->bind(LevelVectors[quantized_features[i]], BaseVectors[i]);
        
        #if DEBUG
            printf("Binding...\n");
            printf("Level vector %d: ", quantized_features[i]);
            LevelVectors[quantized_features[i]].print();
            printf("\n");
            printf("Base vector %d: ", i);
            BaseVectors[i].print();
            printf("\n");
            printf("Binded level vector %d with base vector %d: ", quantized_features[i], i);
            tmp.print();
            printf("\n");
        #endif

        Encoded_HV = this->bundle(Encoded_HV, tmp);

        #if DEBUG
            printf("Accumulated FeatureHV %d through bundling\n", i);
        #endif
    }

    #if DEBUG
        printf("Encoded HV: ");
        Encoded_HV.print();
    #endif

    HV Clipped_HV = this->clip(Encoded_HV, DS_FEATURE_SIZE);

    return Clipped_HV;
}

BundledHV HDC_op::training(uint32_t quantized_features[DS_FEATURE_SIZE], HV (&BaseVectors)[DS_FEATURE_SIZE], HV (&LevelVectors)[HD_LV_LEN], BundledHV (&ClassVectors)[HD_CV_LEN], int class_label)
{
    // Encoding
    HV Encoded_HV = this->encoding(quantized_features, BaseVectors, LevelVectors);
    
    // Bundling the Encoded HV with the corresponding class vector
    ClassVectors[class_label] = this->bundle(ClassVectors[class_label], Encoded_HV);
    
    #if DEBUG
        printf("Class vector %d: ", class_label);
        ClassVectors[class_label].print();
        printf("\n");
    #endif

    return ClassVectors[class_label];
}

uint32_t HDC_op::inference(uint32_t quantized_features[DS_FEATURE_SIZE], HV (&BaseVectors)[DS_FEATURE_SIZE], HV (&LevelVectors)[HD_LV_LEN], HV (&AssociativeMemory)[HD_CV_LEN])
{
    // Encoding
    HV Encoded_HV = this->encoding(quantized_features, BaseVectors, LevelVectors);

    #if DEBUG
        printf("Encoded HV (Clipped): ");
        Encoded_HV.print();
    #endif

    // Compute the Hamming distance between the Encoded HV and each class vector inside the associative memory
    // int predicted_class = 0;
    // int temp_best_distance = HV_SIZE_BIT;
    // for (int i = 0; i < HD_CV_LEN; i++){
    //     int hamming_distance = this->similarity(Encoded_HV, ClassVectors[i]);
    //     #if DEBUG == 1
    //     printf("Hamming distance for class %i = %X\n", i, hamming_distance);
    //     #endif
    //     if (hamming_distance < temp_best_distance){
    //         temp_best_distance = hamming_distance;
    //         predicted_class = i;
    //     }
    // }
    
    int predicted_class = this->search(Encoded_HV, AssociativeMemory);

    return predicted_class;
}

// ======================================================
// HDC Fundamentals Operations using Hardware Accelerator
// ======================================================
void HDC_op::hvmemld(uint32_t spm_addr, uint32_t* hv_ptr, size_t size) {

    #if DEBUG
    printf("HDC HVMEMLD Instruction Executing...\n\n");
    #endif

    // 1. Fill the TX buffer with the HV we want to load into SPM
    volatile uint32_t *TX_buf = (volatile uint32_t *)dma_src_buffer;
    size_t num_words = size / sizeof(uint32_t);
    #if DEBUG
    printf("=========================================\n");
    printf("                TX Buffer               \n");
    printf("=========================================\n");
    #endif
    for (size_t i = 0; i < num_words; i++) {
        TX_buf[i] = hv_ptr[i];
        #if DEBUG
        printf("TX_buf[%zu] = 0x%08X\n", i, TX_buf[i]);
        if(i == num_words -1){
            printf("=========================================\n\n");
        }
        #endif
    }

    // 2. Reset the DMA
    REG_WRITE(dma_base, MM2S_CONTROL_REGISTER, RESET_DMA);
    #if DEBUG_DMA
    printf("DMA Resetted.\n");
    dma_mm2s_status();
    #endif

    // 3. Halt the DMA
    REG_WRITE(dma_base, MM2S_CONTROL_REGISTER, HALT_DMA);
    #if DEBUG_DMA 
    printf("DMA Halted\n");
    dma_mm2s_status();
    #endif

    // 4. Enable all interrupts
    REG_WRITE(dma_base, MM2S_CONTROL_REGISTER, ENABLE_ALL_IRQ);
    #if DEBUG_DMA 
    printf("DMA Interrupts Enabled.\n");
    dma_mm2s_status();
    #endif

    // 5. Write the source address
    REG_WRITE(dma_base, MM2S_SRC_ADDRESS_REGISTER, DMA_SRC_BUFFER);
    #if DEBUG_DMA
    printf("DMA Source Address Written.\n");
    dma_mm2s_status();
    #endif

    // 6. Run the DMA
    REG_WRITE(dma_base, MM2S_CONTROL_REGISTER, RUN_DMA);
    #if DEBUG_DMA
    printf("DMA Running.\n");
    dma_mm2s_status();
    #endif

    // 7. Write the length of the transfer
    REG_WRITE(dma_base, MM2S_TRNSFR_LENGTH_REGISTER, static_cast<uint32_t>(size));
    #if DEBUG_DMA
    printf("DMA Transfer Length Written.\n");
    dma_mm2s_status();
    #endif

    // 8. Wait for completion
    dma_mm2s_sync();

    // Configure HDC for SPM load
    REG_WRITE(hdc_base, AXI_WSIZE, static_cast<uint32_t>(size));
    REG_WRITE(hdc_base, AXI_RS1, spm_addr);
    REG_WRITE(hdc_base, AXI_HDC_INSTR, HVMEMLD);
    usleep(1000);

    // Wait for completion and clear done flag
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x2);
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x1);
    
    #if DEBUG
    printf("HDC HVMEMLD Instruction Executed.\n\n");
    #endif

    reset_hardware();
}

void HDC_op::hvmemstr(uint32_t* hv_ptr, uint32_t spm_addr, size_t size) {
    
    #if DEBUG 
    printf("HDC HVMEMSTR Instruction Executing...\n\n");
    #endif

    // 1. Clear the RX buffer
    memset(dma_dst_buffer, 0, DMA_BUFFERS_MAP_SIZE);
    #if DEBUG_DMA 
    printf("\nDMA RX Buffer Cleared.\n");
    #endif

    // 2. Reset the DMA
    REG_WRITE(dma_base, S2MM_CONTROL_REGISTER, RESET_DMA);
    #if DEBUG_DMA 
    printf("DMA Resetted.\n");
    dma_s2mm_status();
    #endif

    // 3. Halt the DMA
    REG_WRITE(dma_base, S2MM_CONTROL_REGISTER, HALT_DMA);
    #if DEBUG_DMA   
    printf("DMA Halted\n");
    dma_s2mm_status();
    #endif

    // 4. Enable all interrupts
    REG_WRITE(dma_base, S2MM_CONTROL_REGISTER, ENABLE_ALL_IRQ);
    #if DEBUG_DMA 
    printf("DMA Interrupts Enabled.\n");
    dma_s2mm_status();
    #endif

    // 5. Configure HDC for SPM store
    REG_WRITE(hdc_base, AXI_RSIZE, static_cast<uint32_t>(size));
    REG_WRITE(hdc_base, AXI_RS1, spm_addr);
    REG_WRITE(hdc_base, AXI_HDC_INSTR, HVMEMSTR);
   
    // 6. Write the destination address
    REG_WRITE(dma_base, S2MM_DST_ADDRESS_REGISTER, DMA_DST_BUFFER);
    #if DEBUG_DMA 
    printf("DMA Destination Address Written.\n");
    dma_s2mm_status();
    #endif

    // 7. Run the DMA
    REG_WRITE(dma_base, S2MM_CONTROL_REGISTER, RUN_DMA);
    #if DEBUG_DMA 
    printf("DMA Running.\n");
    dma_s2mm_status();
    #endif

    // 8. Write the length of the transfer
    REG_WRITE(dma_base, S2MM_BUFF_LENGTH_REGISTER, static_cast<uint32_t>(size));
    #if DEBUG_DMA 
    printf("DMA Transfer Length Written.\n");
    dma_s2mm_status();
    #endif
    
    // 9. Wait for completion
    dma_s2mm_sync();

    // 10. Copy DDR buffer data back to user space
    volatile uint32_t *RX_buf = (volatile uint32_t *)dma_dst_buffer;
    size_t num_words = size / sizeof(uint32_t);
    #if DEBUG 
    printf("\n=========================================\n");
    printf("                RX Buffer               \n");
    printf("=========================================\n");
    #endif
    for (size_t i = 0; i < num_words; i++) {
        hv_ptr[i] = RX_buf[i];
        #if DEBUG 
        printf("RX_buf[%zu] = 0x%08X\n", i, hv_ptr[i]);
        if(i == num_words -1){
            printf("=========================================\n\n");
        }
        #endif
    }
    usleep(1000);
    
    #if DEBUG 
    printf("HDC HVMEMSTR Instruction Executed.\n");
    #endif

    reset_hardware();
}

void HDC_op::hvbind(uint32_t rd, uint32_t rs1, uint32_t rs2) {
    
    // Set up HDC accelerator registers
    REG_WRITE(hdc_base, AXI_RD, rd);
    REG_WRITE(hdc_base, AXI_RS1, rs1);
    REG_WRITE(hdc_base, AXI_RS2, rs2);
    
    // Execute HVBIND instruction
    REG_WRITE(hdc_base, AXI_HDC_INSTR, HVBIND);
    
    // Clear done flag and re-enable interrupts
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x2);
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x1);
}

void HDC_op::hvbundle(uint32_t rd, uint32_t rs1, uint32_t rs2) {
    
    // Set up HDC accelerator registers
    REG_WRITE(hdc_base, AXI_RD, rd);
    REG_WRITE(hdc_base, AXI_RS1, rs1);
    REG_WRITE(hdc_base, AXI_RS2, rs2);
    
    // Execute HVBUNDLE instruction
    REG_WRITE(hdc_base, AXI_HDC_INSTR, HVBUNDLE);

    // Clear done flag and re-enable interrupts
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x2);
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x1);

}

void HDC_op::hvperm(uint32_t rd, uint32_t rs1, uint32_t shift) {
    
    // Set up HDC accelerator registers
    REG_WRITE(hdc_base, AXI_RD, rd);
    REG_WRITE(hdc_base, AXI_RS1, rs1);
    REG_WRITE(hdc_base, AXI_RS2, shift);
    
    // Execute HVPERM instruction
    REG_WRITE(hdc_base, AXI_HDC_INSTR, HVPERM);

    // Clear done flag and re-enable interrupts
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x2);
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x1);
}

void HDC_op::hvsim(uint32_t rd, uint32_t rs1, uint32_t rs2) {
    
    // Set up HDC accelerator registers
    REG_WRITE(hdc_base, AXI_RD, rd);
    REG_WRITE(hdc_base, AXI_RS1, rs1);
    REG_WRITE(hdc_base, AXI_RS2, rs2);
    
    // Execute HVSIM instruction
    REG_WRITE(hdc_base, AXI_HDC_INSTR, HVSIM);

    // Clear done flag and re-enable interrupts
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x2);
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x1);
}

void HDC_op::hvsearch(uint32_t rd, uint32_t rs1, uint32_t rs2) {
    
    // Inform the HDC accelerator about the num of classes;
    REG_WRITE(hdc_base, AXI_HVCLASS, HVSIZE_BYTES*HVCLASS);
    
    // Set up HDC accelerator registers
    REG_WRITE(hdc_base, AXI_RD, rd);
    REG_WRITE(hdc_base, AXI_RS1, rs1);
    REG_WRITE(hdc_base, AXI_RS2, rs2);
    
    // Execute HVSEARCH instruction
    REG_WRITE(hdc_base, AXI_HDC_INSTR, HVSEARCH);
    
    // Clear done flag and re-enable interrupts
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x2);
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x1);
}

void HDC_op::hvclip(uint32_t rd, uint32_t rs1, uint32_t THRESHOLD) {
    
    // Set up HDC accelerator registers
    REG_WRITE(hdc_base, AXI_RD, rd);
    REG_WRITE(hdc_base, AXI_RS1, rs1);
    REG_WRITE(hdc_base, AXI_RS2, THRESHOLD);
    
    // Execute HVCLIP instruction
    REG_WRITE(hdc_base, AXI_HDC_INSTR, HVCLIP);
    usleep(10000);
    
    // Clear done flag and re-enable interrupts
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x2);
    REG_WRITE(hdc_base, AXI_INTERRUPT, 0x1);
}

bool HDC_op::hvcompare(uint32_t *hv1,  uint32_t *hv2, size_t size) {

    // Compare Software and Hardware results
    printf("\n=========================================\n");
    printf("            Comparison Results               \n");
    printf("=========================================\n");

    bool test_passed = true;
    size_t num_chunks = size / sizeof(uint32_t);
    for(size_t i = 0; i < num_chunks; i++){
        if(hv1[i] != hv2[i]){
            printf("ERROR: Mismatch at chunk %zu - SW: 0x%08X, HW: 0x%08X\n", 
                    i, hv1[i], hv2[i]);
            test_passed = false;
        }
    }
    return test_passed;
}

// ===================================================
// HDC Composite Operations using Hardware Accelerator
// ===================================================
void HDC_op::accl_encoding(uint32_t quantized_features[DS_FEATURE_SIZE], uint32_t bv_start_addr, uint32_t lv_start_addr){

    printf("Encoding Start...\n");

    for (int i = 0; i < DS_FEATURE_SIZE; i++){
        #if DEBUG
            printf("Base  Vector Addr: %X\n", (bv_start_addr+i*sizeof(HV)));
            printf("Level Vector Addr: %X\n", (lv_start_addr+quantized_features[i]*sizeof(HV)));
            printf("\n");
        #endif
        
        // BIND the level vector with the corresponding base vector
        this->hvbind(SPM_C_START_ADDR, lv_start_addr + quantized_features[i]*sizeof(HV), bv_start_addr + i*sizeof(HV));
        
        HV appoggio;
        printf("Binding...\n");
        printf("Level vector %d: ", quantized_features[i]);
        this->hvmemstr((uint32_t*)&appoggio, (uint32_t)(lv_start_addr+quantized_features[i]*sizeof(HV)), sizeof(HV));
        appoggio.print();
        printf("\n");
        printf("Base vector %d: ", i);
        this->hvmemstr((uint32_t*)&appoggio, (uint32_t)(bv_start_addr+i*sizeof(HV)), sizeof(HV));
        appoggio.print();
        printf("\n");
        printf("Binded level vector %d with base vector %d: ", quantized_features[i], i);
        this->hvmemstr((uint32_t*)&appoggio,SPM_C_START_ADDR, sizeof(HV));
        appoggio.print();
        printf("\n-----------------\n");
        
        
        // BUNDLE the binded vector with the accumulated result
        if(i==0){
            this->hvbundle(SPM_D_START_ADDR, SPM_D_START_ADDR + sizeof(BundledHV) + (HVCLASS + 1)*sizeof(BundledHV), SPM_C_START_ADDR); // First time, bundle with zero_HV
            BundledHV appoggio_bundled;
            printf("Accumulated FeatureHV %d through bundling.\n", i);
            this->hvmemstr((uint32_t*)&appoggio_bundled, SPM_D_START_ADDR, sizeof(BundledHV));
            appoggio_bundled.print();
            printf("\n-----------------\n");
        
        } else {
            this->hvbundle(SPM_D_START_ADDR, SPM_D_START_ADDR, SPM_C_START_ADDR);
        
            BundledHV appoggio_bundled;
            printf("Accumulated FeatureHV %d through bundling.\n", i);
            this->hvmemstr((uint32_t*)&appoggio_bundled, SPM_D_START_ADDR, sizeof(BundledHV));
            appoggio_bundled.print();
            printf("\n-----------------\n");
        }
    }
    
    BundledHV Encoded_HV;
    this->hvmemstr((uint32_t*)&Encoded_HV.bundled_chunk[0], SPM_D_START_ADDR, sizeof(BundledHV));
    printf("Encoded HV before Clipping: \n");
    Encoded_HV.print();
    printf("\n");

    // CLIP the HDC vector
    this->hvclip(SPM_C_START_ADDR, SPM_D_START_ADDR, DS_FEATURE_SIZE);
    
    HV Clipped_HV;
    this->hvmemstr((uint32_t*)&Clipped_HV, SPM_C_START_ADDR, sizeof(HV));
    printf("Encoded HV After Clipping: ");
    Clipped_HV.print();
    printf("\n");
   
    printf("Encoding End.\n\n");
}

void HDC_op::accl_training(uint32_t quantized_features[DS_FEATURE_SIZE], uint32_t bv_start_addr, uint32_t lv_start_addr, uint32_t associativeMemory_start_addr, int class_label){
    
    // Encoding
    this->accl_encoding(quantized_features, bv_start_addr, lv_start_addr);
    
    // Bundling the Encoded HV with the corresponding class vector
    this->hvbundle((associativeMemory_start_addr + sizeof(BundledHV)*class_label), (associativeMemory_start_addr + sizeof(BundledHV)*class_label), SPM_C_START_ADDR); 
    
    #if DEBUG == 1
    BundledHV ClassVectors[HD_CV_LEN];
    this->hvmemstr((uint32_t*)&ClassVectors[class_label], (associativeMemory_start_addr + sizeof(BundledHV)*class_label), sizeof(BundledHV));
    printf("Class vector %d: ", class_label);
    ClassVectors[class_label].print();
    printf("\n");
    #endif
}

void HDC_op::accl_inference(uint32_t quantized_features[DS_FEATURE_SIZE], uint32_t bv_start_addr, uint32_t lv_start_addr, uint32_t associativeMemory_start_addr){
 
    this->accl_encoding(quantized_features, bv_start_addr, lv_start_addr); 
    #if DEBUG
    printf("\nStarting HW Search...\n");
    #endif

    #if INFERENCE_WITH_ASS_SEARCH
    this->hvsearch(SPM_C_START_ADDR, SPM_C_START_ADDR, associativeMemory_start_addr);
    #else
    
    uint32_t predicted_class = 0;
    uint32_t hamming_distance_buffer[SIMD];
    uint32_t temp_best_distance = HV_SIZE_BIT;

    for(int i = 0; i < HD_CV_LEN; i++) {
        // Compute the Hamming distance between the Encoded HV and each class vector inside the associative memory (SPM-D)
        this->hvsim(SPM_C_START_ADDR, SPM_C_START_ADDR, (associativeMemory_start_addr + i * sizeof(HV)));
        this->hvmemstr(hamming_distance_buffer, SPM_C_START_ADDR, sizeof(uint32_t)*SIMD);
        uint32_t hamming_distance = hamming_distance_buffer[0];
        if(hamming_distance < temp_best_distance) {
            temp_best_distance = hamming_distance;
            predicted_class = i;
        }
        printf("Hamming distance for class %d: %u\n", i, hamming_distance);
    }

    printf("Predicted class: %u\n", predicted_class);
    fflush(stdout);
    #endif
}

// ======================================================
// DMA Utilities
// ======================================================
void HDC_op::dma_s2mm_status()
{
    unsigned int status = REG_READ(dma_base, S2MM_STATUS_REGISTER);

    printf("Stream to memory-mapped status (0x%08x@0x%02x):", status, S2MM_STATUS_REGISTER);

    if (status & STATUS_HALTED) {
		printf(" Halted.\n");
	} else {
		printf(" Running.\n");
	}

    if (status & STATUS_IDLE) {
		printf(" Idle.\n");
	}

    if (status & STATUS_SG_INCLDED) {
		printf(" SG is included.\n");
	}

    if (status & STATUS_DMA_INTERNAL_ERR) {
		printf(" DMA internal error.\n");
	}

    if (status & STATUS_DMA_SLAVE_ERR) {
		printf(" DMA slave error.\n");
	}

    if (status & STATUS_DMA_DECODE_ERR) {
		printf(" DMA decode error.\n");
	}

    if (status & STATUS_SG_INTERNAL_ERR) {
		printf(" SG internal error.\n");
	}

    if (status & STATUS_SG_SLAVE_ERR) {
		printf(" SG slave error.\n");
	}

    if (status & STATUS_SG_DECODE_ERR) {
		printf(" SG decode error.\n");
	}

    if (status & STATUS_IOC_IRQ) {
		printf(" IOC interrupt occurred.\n");
	}

    if (status & STATUS_DELAY_IRQ) {
		printf(" Interrupt on delay occurred.\n");
	}

    if (status & STATUS_ERR_IRQ) {
		printf(" Error interrupt occurred.\n");
	}
}

void HDC_op::dma_mm2s_status()
{
    unsigned int status = REG_READ(dma_base, MM2S_STATUS_REGISTER);

    printf("Memory-mapped to stream status (0x%08x@0x%02x):", status, MM2S_STATUS_REGISTER);

    if (status & STATUS_HALTED) {
		printf(" Halted.\n");
	} else {
		printf(" Running.\n");
	}

    if (status & STATUS_IDLE) {
		printf(" Idle.\n");
	}

    if (status & STATUS_SG_INCLDED) {
		printf(" SG is included.\n");
	}

    if (status & STATUS_DMA_INTERNAL_ERR) {
		printf(" DMA internal error.\n");
	}

    if (status & STATUS_DMA_SLAVE_ERR) {
		printf(" DMA slave error.\n");
	}

    if (status & STATUS_DMA_DECODE_ERR) {
		printf(" DMA decode error.\n");
	}

    if (status & STATUS_SG_INTERNAL_ERR) {
		printf(" SG internal error.\n");
	}

    if (status & STATUS_SG_SLAVE_ERR) {
		printf(" SG slave error.\n");
	}

    if (status & STATUS_SG_DECODE_ERR) {
		printf(" SG decode error.\n");
	}

    if (status & STATUS_IOC_IRQ) {
		printf(" IOC interrupt occurred.\n");
	}

    if (status & STATUS_DELAY_IRQ) {
		printf(" Interrupt on delay occurred.\n");
	}

    if (status & STATUS_ERR_IRQ) {
		printf(" Error interrupt occurred.\n");
	}
}

int HDC_op::dma_mm2s_sync()
{
    unsigned int mm2s_status =  REG_READ(dma_base, MM2S_STATUS_REGISTER);

	// sit in this while loop as long as the status does not read back 0x00001002 (4098)
	// 0x00001002 = IOC interrupt has occured and DMA is idle
	while(!(mm2s_status & IOC_IRQ_FLAG) || !(mm2s_status & IDLE_FLAG))
	{
        #if DEBUG_DMA == 1
        dma_s2mm_status();
        dma_mm2s_status();
        #endif

        mm2s_status =  REG_READ(dma_base, MM2S_STATUS_REGISTER);
    }

	return 0;
}

int HDC_op::dma_s2mm_sync()
{
    unsigned int s2mm_status = REG_READ(dma_base, S2MM_STATUS_REGISTER);
	// sit in this while loop as long as the status does not read back 0x00001002 (4098)
	// 0x00001002 = IOC interrupt has occured and DMA is idle
	while(!(s2mm_status & IOC_IRQ_FLAG) || !(s2mm_status & IDLE_FLAG))
	{
        #if DEBUG_DMA == 1
        dma_s2mm_status();
        dma_mm2s_status();
        #endif  
        s2mm_status = REG_READ(dma_base, S2MM_STATUS_REGISTER);
    }

	return 0;
}

void HDC_op::hdc_status() {
    unsigned int AXI_HVSIZE_reg = REG_READ(hdc_base, AXI_HVSIZE);
    unsigned int AXI_RS1_reg = REG_READ(hdc_base, AXI_RS1);
    unsigned int AXI_RS2_reg = REG_READ(hdc_base, AXI_RS2);
    unsigned int AXI_RD_reg = REG_READ(hdc_base, AXI_RD);
    unsigned int AXI_HDC_INSTR_reg = REG_READ(hdc_base, AXI_HDC_INSTR);
    unsigned int AXI_HVCLASS_reg = REG_READ(hdc_base, AXI_HVCLASS);
    unsigned int AXI_RSIZE_reg = REG_READ(hdc_base, AXI_RSIZE);
    unsigned int AXI_WSIZE_reg = REG_READ(hdc_base, AXI_WSIZE);
    unsigned int AXI_INTERRUPT_reg = REG_READ(hdc_base, AXI_INTERRUPT);
    unsigned int AXI_TEST_REG_reg = REG_READ(hdc_base, AXI_TEST_REG);
    printf("============= HDC Status Registers ==============\n");
    printf("AXI_HVSIZE:     0x%08X\n", AXI_HVSIZE_reg);
    printf("AXI_RS1:        0x%08X\n", AXI_RS1_reg);
    printf("AXI_RS2:        0x%08X\n", AXI_RS2_reg);
    printf("AXI_RD:         0x%08X\n", AXI_RD_reg);
    printf("AXI_HDC_INSTR:  0x%08X\n", AXI_HDC_INSTR_reg);
    printf("AXI_HVCLASS:    0x%08X\n", AXI_HVCLASS_reg);
    printf("AXI_RSIZE:      0x%08X\n", AXI_RSIZE_reg);
    printf("AXI_WSIZE:      0x%08X\n", AXI_WSIZE_reg);
    printf("AXI_INTERRUPT:  0x%08X\n", AXI_INTERRUPT_reg);
    printf("AXI_TEST_REG:   0x%08X\n", AXI_TEST_REG_reg);
    printf("===============================================\n\n");
}
// ======================================================
// FIFO Utilities
// ======================================================
uint32_t HDC_op::get_fifo_status(const char *label) {
    uint32_t status = REG_READ(gpio_base, GPIO_DATA);
    if (label && DEBUG) {
        printf("[%s] GPIO_DATA=0x%08X | FIFO_IN: %s %s | FIFO_OUT: %s %s | DONE: %s\n",
            label, status,
            (status & FIFO_IN_AE_MASK)  ? "AE" : "--",
            (status & FIFO_IN_AF_MASK)  ? "AF" : "--",
            (status & FIFO_OUT_AE_MASK) ? "AE" : "--",
            (status & FIFO_OUT_AF_MASK) ? "AF" : "--",
            (status & DONE_MASK) ? "DONE" : "busy"
        );
    }
    return status;
}

// ======================================================
// MISC Utilities
// ======================================================
void press_enter_to_continue() {
    printf("Press Enter to continue...");
    fflush(stdout);
    
    // Clear any pending input
    int c;
    while ((c = getchar()) != '\n' && c != EOF);
}

uint64_t HDC_op::time_ns_monotonic() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}   

// ===================================================
// Performance Counter Methods
// ===================================================
uint32_t HDC_op::get_bundle_cycles() {
    return REG_READ(hdc_base, PERF_BUNDLE_OFFSET);
}

uint32_t HDC_op::get_bind_cycles() {
    return REG_READ(hdc_base, PERF_BIND_OFFSET);
}

uint32_t HDC_op::get_sim_cycles() {
    return REG_READ(hdc_base, PERF_SIM_OFFSET);
}

uint32_t HDC_op::get_clip_cycles() {
    return REG_READ(hdc_base, PERF_CLIP_OFFSET);
}

uint32_t HDC_op::get_perm_cycles() {
    return REG_READ(hdc_base, PERF_PERM_OFFSET);
}

uint32_t HDC_op::get_as_cycles() {
    return REG_READ(hdc_base, PERF_AS_OFFSET);
}

double HDC_op::get_execution_time_ns(uint32_t cycles) {
    return cycles * CLOCK_PERIOD_NS;
}

// --------------------End HDC Class----------------------

