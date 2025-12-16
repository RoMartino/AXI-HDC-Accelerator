#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <time.h>

#include "hdc_class.hpp"

int main() {

    // Set the seed for reproducibility
    srand((unsigned)time(NULL));

    printf("\n=========================================\n");
    printf("       HVMEMLD and HVMEMSTR Test 1       \n");
    printf("=========================================\n");
    printf("This test verifies HDC memory load/store operations:\n");
    printf("1. Loads random HV data into SPMA using HVMEMLD\n");
    printf("2. Stores HV data from SPMA using HVMEMSTR\n");
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

    // Declare an HV variable to use for testing
    HV hv;

    // Initialize hv with random data
    hv.randomize();
    for(int i=0; i< HV_CHUNKS; i++){
        printf("HV Chunk %d: %08X\n", i, hv.chunk[i]);
    }
    printf("\n");

    printf("\n=========================================\n");
    printf("          Performance Metrics           \n");
    printf("=========================================\n");
    
    // Load hv into SPM via HVMEMLD
    uint64_t start_time, end_time;
    start_time = hdc.time_ns_monotonic();
    hdc.hvmemld(SPM_A_START_ADDR, (uint32_t*)&hv, sizeof(HV));
    usleep(1000);
    end_time = hdc.time_ns_monotonic();
    printf("HVMEMLD time: %.2f us\n", (end_time - start_time) / 1000.0);
    
    //=====================================
    // HVMEMSTR
    //=====================================

    // Declare an HV variable to use for testing
    HV hv_out;

    // Store from SPM into hv_out via HVMEMSTR
    start_time = hdc.time_ns_monotonic();
    hdc.hvmemstr((uint32_t*)&hv_out, SPM_A_START_ADDR, sizeof(HV));
    usleep(1000);
    end_time = hdc.time_ns_monotonic();
    printf("HVMEMSTR time: %.2f us\n", (end_time - start_time) / 1000.0);
    //=====================================
    // TEST RESULTS
    //=====================================
    printf("=========================================\n");
    if(hdc.hvcompare((uint32_t*)&hv, (uint32_t*)&hv_out, sizeof(HV))){
        printf("TEST PASSED\n");
    } else {
        printf("TEST FAILED\n");
    }
    printf("=========================================\n");
}