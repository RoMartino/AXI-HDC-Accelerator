#include <cstdio>
#include <cstdlib>

#include "hdc_class.hpp"

int main(){

    printf("=========================================\n");
    printf("              Bundling Test               \n");
    printf("=========================================\n");
    printf("This test verifies HDC Bundling operation:\n");
    printf("1. Generates three random HVs\n");
    printf("2. Performs Bundling operation in Software\n");
    printf("3. Performs Bundling operation in Hardware\n");
    printf("4. Compares Software and Hardware results\n");
    printf("=========================================\n");
    printf("\n=========================================\n");
    printf("             Configuration              \n");
    printf("=========================================\n");
    printf("HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    printf("HV_CHUNKS: %d\n", HV_CHUNKS);
    printf("HV_BUNDLED_CHUNKS: %d\n", HV_CHUNKS * COUNTER_BITS);
    printf("HVSIZE_BYTES: %d\n", HVSIZE_BYTES);
    printf("=========================================\n");

    // Initialize HDC operator
    HDC_op hdc(HV_SIZE_BIT, DS_FEATURE_SIZE, HD_LV_LEN);
    if(!hdc.is_hardware_initialized()){
        printf("Hardware initialization failed. Exiting test.\n");
        return -1;
    }

    // Generate three random HVs
    HV HV1, HV2;

    HV1.randomize();
    HV2.randomize();

    BundledHV zeroHV;

    #if DEBUG == 1
    printf("HV1:\n");
    HV1.print();
    printf("HV2:\n");
    HV2.print();
    printf("\n");
    #endif

    uint64_t start_time, end_time;

    // Perform Bundling in Software
    start_time = hdc.time_ns_monotonic();
    BundledHV SW_result = hdc.bundle(zeroHV, HV1);
    end_time = hdc.time_ns_monotonic();
    printf("Software Bundling Time: %.2f us\n", (end_time - start_time) / 1000.0);
    
    #if DEBUG == 1
    printf("Software Bundling Result:\n");
    SW_result.print();
    printf("\n\n");
    #endif

    //=====================================
    // HVBUNDLE
    //=====================================

    // Init Accumulation location 
    hdc.hvmemld(SPM_A_START_ADDR, (uint32_t*)&zeroHV, sizeof(BundledHV));

    // Load HV1 and HV2 into SPM_B
    hdc.hvmemld(SPM_B_START_ADDR, (uint32_t*)&HV1, sizeof(HV));

    hdc.hvmemld(SPM_B_START_ADDR + sizeof(HV), (uint32_t*)&HV2, sizeof(HV));

    for(int i = 0; i < 1; i++){
        hdc.hvbundle(SPM_A_START_ADDR, SPM_A_START_ADDR, SPM_B_START_ADDR + i * sizeof(HV));
        usleep(1000);
    }

    uint32_t bundle_cycles = hdc.get_bundle_cycles();
    double bundle_time_ns = hdc.get_execution_time_ns(bundle_cycles);
    double bundle_time_us = bundle_time_ns / 1000.0;
    
    printf("Hardware bundling cycles: %u\n", bundle_cycles);
    printf("Hardware bundling time: %.2f us\n", bundle_time_us);
    printf("Speedup: %.2fx\n", (end_time - start_time) / bundle_time_us);

    // Retrieve result from SPM_A
    BundledHV HW_result;

    hdc.hvmemstr((uint32_t*)&HW_result, SPM_A_START_ADDR, sizeof(BundledHV));
    usleep(1000);

    //=====================================
    // TEST RESULTS
    //=====================================
    if(hdc.hvcompare((uint32_t*)&SW_result, (uint32_t*)&HW_result, sizeof(BundledHV))){
        printf("TEST PASSED\n");
    } else {
        printf("TEST FAILED\n");
    }
}