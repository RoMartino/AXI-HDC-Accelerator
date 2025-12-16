#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "hdc_class.hpp"

#define NUM_HVS 100

int main() {

    printf("\n=========================================\n");
    printf("       HVMEMLD and HVMEMSTR Test 2       \n");
    printf("=========================================\n");
    printf("This test verifies HDC memory load/store operations:\n");
    printf("1. Loads n random HVs data into SPMA using HVMEMLD\n");
    printf("2. Stores HVs data from SPMA using HVMEMSTR\n");
    printf("3. Compares original and retrieved data\n");
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

    //=====================================
    // HVMEMLD
    //=====================================

    // Declare an HVs array to use for testing
    HV hv[NUM_HVS];

    // Initialize HVs with random data
    for(int i = 0; i < NUM_HVS; i++){
        hv[i].randomize();
    }

    printf("\n=========================================\n");
    printf("          Performance Metrics           \n");
    printf("=========================================\n");

    // Load HVs into SPMA via HVMEMLD
    uint64_t start_time, end_time;
    start_time = hdc.time_ns_monotonic();
    for(int i = 0; i < NUM_HVS; i++){
        hdc.hvmemld(SPM_A_START_ADDR + i * sizeof(HV), (uint32_t*)&hv[i], sizeof(HV));
    }
    end_time = hdc.time_ns_monotonic();
    printf("HVMEMLD time (%d HVs): %.2f us (avg: %.2f us/HV)\n", 
           NUM_HVS, (end_time - start_time) / 1000.0, ((end_time - start_time) / 1000.0) / NUM_HVS);
    
    //=====================================
    // HVMEMSTR
    //=====================================

    // Declare HV variables to use for testing
    HV hv_out[NUM_HVS];

    // Store from SPMA into hv1_out and hv2_out via HVMEMSTR
    start_time = hdc.time_ns_monotonic();
    for(int i = 0; i < NUM_HVS; i++){
        hdc.hvmemstr((uint32_t*)&hv_out[i], SPM_A_START_ADDR + i * sizeof(HV), sizeof(HV));
    }
    end_time = hdc.time_ns_monotonic();
    printf("HVMEMSTR time (%d HVs): %.2f us (avg: %.2f us/HV)\n", 
           NUM_HVS, (end_time - start_time) / 1000.0, ((end_time - start_time) / 1000.0) / NUM_HVS);

    // Compare Software and Hardware results
    printf("=========================================\n");
    printf("              Test Results               \n");
    printf("=========================================\n");
    bool test_passed = true;
    
    for(int j = 0; j < NUM_HVS; j++){
        for(int i = 0; i < HV_CHUNKS; i++){
            if(hv[j].chunk[i] != hv_out[j].chunk[i]){
                printf("ERROR: Mismatch at chunk %d for hv%d - SW: 0x%08X, HW: 0x%08X\n", 
                       i, j, hv[j].chunk[i], hv_out[j].chunk[i]);
                test_passed = false;
            }
        }
    }

    if (test_passed) {
        printf("Test PASSED\n\n");
        return 0;
    } else {
        printf("Test FAILED\n\n");
        return -1;
    }
}