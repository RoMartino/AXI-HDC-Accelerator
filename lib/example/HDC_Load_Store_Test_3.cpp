#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "hdc_class.hpp"

int main() {

    printf("\n=========================================\n");
    printf("       HVMEMLD and HVMEMSTR Test 2       \n");
    printf("=========================================\n");
    printf("This test verifies HDC memory load/store operations:\n");
    printf("1. Loads 1 random BundledHV data into SPMA using HVMEMLD\n");
    printf("2. Stores BundledHV data from SPMA using HVMEMSTR\n");
    printf("3. Compares original and retrieved data\n");
    printf("=========================================\n");
    printf("\n=========================================\n");
    printf("             Configuration              \n");
    printf("=========================================\n");
    printf("HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    printf("HV_CHUNKS: %d\n", HV_CHUNKS*COUNTER_BITS);
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

    // Declare an BundledHV to use for testing
    BundledHV hv;

    // Initialize BundledHV with random data
    hv.randomize();

    printf("\n=========================================\n");
    printf("          Performance Metrics           \n");
    printf("=========================================\n");

    // Load BundledHV into SPMA via HVMEMLD
    uint64_t start_time, end_time;
    start_time = hdc.time_ns_monotonic();
    hdc.hvmemld(SPM_A_START_ADDR, (uint32_t*)&hv, sizeof(BundledHV));
    end_time = hdc.time_ns_monotonic();
    printf("HVMEMLD time (BundledHV): %.2f us\n", (end_time - start_time) / 1000.0);
    
    //=====================================
    // HVMEMSTR
    //=====================================

    // Declare HV variables to use for testing
    BundledHV hv_out;

    // Store from SPMA into hv_out via HVMEMSTR
    start_time = hdc.time_ns_monotonic();
    hdc.hvmemstr((uint32_t*)&hv_out, SPM_A_START_ADDR, sizeof(BundledHV));
    end_time = hdc.time_ns_monotonic();
    printf("HVMEMSTR time (BundledHV): %.2f us\n", (end_time - start_time) / 1000.0);

    //=====================================
    // TEST RESULTS
    //=====================================
    printf("=========================================\n");
    if(hdc.hvcompare((uint32_t*)&hv, (uint32_t*)&hv_out, sizeof(BundledHV))){
        printf("TEST PASSED\n");
    } else {
        printf("TEST FAILED\n");
    }
    printf("=========================================\n");
    
}