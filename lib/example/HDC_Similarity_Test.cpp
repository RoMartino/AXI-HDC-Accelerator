#include <cstdio>
#include <cstdlib>

#include "hdc_class.hpp"

int main(){

    printf("=========================================\n");
    printf("              Similarity Test               \n");
    printf("=========================================\n");
    printf("This test verifies HDC Similarity operation:\n");
    printf("1. Generates two random HVs\n");
    printf("2. Performs Similarity operation in Software\n");
    printf("3. Performs Similarity operation in Hardware\n");
    printf("4. Compares Software and Hardware results\n");
    printf("=========================================\n");
    printf("\n=========================================\n");
    printf("             Configuration              \n");
    printf("=========================================\n");
    printf("HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    printf("HV_CHUNKS: %d\n", HV_CHUNKS);
    printf("HVSIZE_BYTES: %d\n", HVSIZE_BYTES);
    printf("=========================================\n");

    // Initialize HDC operator
    HDC_op hdc(HV_SIZE_BIT, DS_FEATURE_SIZE, HD_LV_LEN);
    if(!hdc.is_hardware_initialized()){
        printf("Hardware initialization failed. Exiting test.\n");
        return -1;
    }

    // Generate two random HVs
    HV HV1, HV2;
    HV1.randomize();
    HV2.randomize();
    
    #if DEBUG == 1
    printf("HV1:\n");
    for(int i = 0; i < HV_CHUNKS; i++){
        printf("0x%08X ", HV1.chunk[i]);
    }
    printf("\n\n");
    printf("HV2:\n");
    for(int i = 0; i < HV_CHUNKS; i++){
        printf("0x%08X ", HV2.chunk[i]);
    }
    printf("\n\n");
    #endif

    // Perform Similarity in Software
    uint64_t start_time, end_time;
    printf("\n=========================================\n");
    printf("          Performance Metrics           \n");
    printf("=========================================\n");
    start_time = hdc.time_ns_monotonic();
    int SW_result = hdc.similarity(HV1, HV2);
    end_time = hdc.time_ns_monotonic();
    printf("Software similarity time: %.2f us\n", (end_time - start_time) / 1000.0);

    //=====================================
    // HVSIM
    //=====================================
    uint32_t HW_result[SIMD];

    // Load HV1 into SPM_A and HV2 into SPM_B
    hdc.hvmemld(SPM_A_START_ADDR + sizeof(HV), (uint32_t*)&HV1, sizeof(HV));
    hdc.hvmemld(SPM_B_START_ADDR + sizeof(HV), (uint32_t*)&HV2, sizeof(HV));

    hdc.hvsim(SPM_D_START_ADDR, SPM_A_START_ADDR + sizeof(HV), SPM_B_START_ADDR + sizeof(HV));
    
    uint32_t sim_cycles = hdc.get_sim_cycles();
    double sim_time_ns = hdc.get_execution_time_ns(sim_cycles);
    double sim_time_us = sim_time_ns / 1000.0;
    
    printf("Hardware similarity cycles: %u\n", sim_cycles);
    printf("Hardware similarity time: %.2f us\n", sim_time_us);
    printf("Speedup: %.2fx\n", (end_time - start_time) / sim_time_us);

    hdc.hvmemstr((uint32_t*)&HW_result, SPM_D_START_ADDR, sizeof(uint32_t)*SIMD);
    
    #if DEBUG 
    printf("Software Similarity Result: ");
    printf("%d\n", SW_result);
    printf("Hardware Similarity Result: ");
    printf("%d\n", HW_result[0]);
    #endif
    
    // =====================================
    // TEST RESULTS
    // =====================================
    printf("=========================================\n");
    if(hdc.hvcompare((uint32_t*)&SW_result, (uint32_t*)&HW_result, sizeof(int))){
        printf("TEST PASSED\n");
    } else {
        printf("TEST FAILED\n");
    }
    printf("=========================================\n");
}