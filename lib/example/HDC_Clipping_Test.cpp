#include <cstdio>
#include <cstdlib>

#include "hdc_class.hpp"

#define THRESHOLD 4

int main(){

    printf("=========================================\n");
    printf("              Clipping Test               \n");
    printf("=========================================\n");
    printf("This test verifies HDC Clipping operation:\n");
    printf("1. Generates three random HVs\n");
    printf("2. Performs Clipping operation in Software\n");
    printf("3. Performs Clipping operation in Hardware\n");
    printf("4. Compares Software and Hardware results\n");
    printf("=========================================\n");
    printf("\n=========================================\n");
    printf("             Configuration              \n");
    printf("=========================================\n");
    printf("HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    printf("HV_CHUNKS: %d\n", HV_CHUNKS);
    printf("HV_BUNDLED_CHUNKS: %d\n", HV_CHUNKS * COUNTER_BITS);
    printf("HVSIZE_BYTES: %d\n", HVSIZE_BYTES);
    printf("THRESHOLD (MAJORITY): %d\n", THRESHOLD);
    printf("=========================================\n");

    // Initialize HDC operator
    HDC_op hdc(HV_SIZE_BIT, DS_FEATURE_SIZE, HD_LV_LEN);
    if(!hdc.is_hardware_initialized()){
        printf("Hardware initialization failed. Exiting test.\n");
        return -1;
    }

    // Generate random BundledHVs
    BundledHV bundled;

    // Initialize the HV
    bundled.randomize();

    #if DEBUG == 1
    printf("Bundled HV:\n");
    bundled.print();
    printf("\n");
    #endif
    
    // Perform Clipping in Software
    HV SW_result;
    uint64_t start_time, end_time;
    start_time = hdc.time_ns_monotonic();
    SW_result = hdc.clip(bundled, THRESHOLD);
    end_time = hdc.time_ns_monotonic();
    printf("Software clipping time: %.2f us\n", (end_time - start_time) / 1000.0);
        
    #if DEBUG == 1
    printf("Software Clipping Result:\n");
    SW_result.print();
    printf("\n\n");
    #endif

    // =====================================
    // HVCLIP
    // =====================================

    // Load Bundled HV into SPM_A
    hdc.hvmemld(SPM_A_START_ADDR, (uint32_t*)&bundled, sizeof(BundledHV));
    usleep(1000);

    // Perform Clipping in Hardware
    hdc.hvclip(SPM_D_START_ADDR, SPM_A_START_ADDR, THRESHOLD);
    usleep(10000);
    
    uint32_t clip_cycles = hdc.get_clip_cycles();
    double clip_time_ns = hdc.get_execution_time_ns(clip_cycles);
    double clip_time_us = clip_time_ns / 1000.0;
    
    printf("Hardware clipping cycles: %u\n", clip_cycles);
    printf("Hardware clipping time: %.2f us\n", clip_time_us);
    printf("Speedup: %.2fx\n", (end_time - start_time) / clip_time_us);

    // Retrieve result from SPM_A
    HV HW_result;
    hdc.hvmemstr((uint32_t*)&HW_result, SPM_D_START_ADDR, sizeof(HV));
    usleep(1000);

    #if DEBUG == 1
    printf("Hardware Clipping Result:\n");
    HW_result.print();
    printf("\n");
    #endif

    //=====================================
    // TEST RESULTS
    //=====================================
    if(hdc.hvcompare((uint32_t*)&SW_result, (uint32_t*)&HW_result, sizeof(HV))){
        printf("TEST PASSED\n");
    } else {
        printf("TEST FAILED\n");
    }
}