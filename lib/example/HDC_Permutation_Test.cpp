#include <cstdio>
#include <cstdlib>

#include "hdc_class.hpp"

#define PERMUTATION_SHIFTS 1

int main(){

    printf("=========================================\n");
    printf("              Permutation Test               \n");
    printf("=========================================\n");
    printf("This test verifies HDC Permutation operation:\n");
    printf("1. Generates one random HV\n");
    printf("2. Performs Permutation operation in Software\n");
    printf("3. Performs Permutation operation in Hardware\n");
    printf("4. Compares Software and Hardware results\n");
    printf("=========================================\n");
    printf("\n=========================================\n");
    printf("             Configuration              \n");
    printf("=========================================\n");
    printf("HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    printf("HV_CHUNKS: %d\n", HV_CHUNKS);
    printf("HVSIZE_BYTES: %d\n", HVSIZE_BYTES);
    printf("PERMUTATION_SHIFTS: %d\n", PERMUTATION_SHIFTS);
    printf("=========================================\n\n");

    // Initialize HDC operator
    HDC_op hdc(HV_SIZE_BIT, DS_FEATURE_SIZE, HD_LV_LEN);
    if(!hdc.is_hardware_initialized()){
        printf("Hardware initialization failed. Exiting test.\n");
        return -1;
    }

    // Generate two random HVs
    HV HV1;
    HV1.randomize();
    
    #if DEBUG == 1
    printf("HV1:\n");
    HV1.print();
    printf("\n\n");
    #endif

    // Perform Permutation in Software
    HV SW_result;
    uint64_t start_time, end_time;
    start_time = hdc.time_ns_monotonic();
    SW_result = hdc.permutation(HV1, PERMUTATION_SHIFTS);
    end_time = hdc.time_ns_monotonic();
    printf("Software permutation time: %.2f us\n", (end_time - start_time) / 1000.0);

    //=====================================
    // HVPERMUTE
    //=====================================
    HV HW_result;

    // Load HV1 into SPM_A
    hdc.hvmemld(SPM_A_START_ADDR, (uint32_t*)&HV1, sizeof(HV));

    hdc.hvperm(SPM_D_START_ADDR, SPM_A_START_ADDR, PERMUTATION_SHIFTS);
    
    uint32_t perm_cycles = hdc.get_perm_cycles();
    double perm_time_ns = hdc.get_execution_time_ns(perm_cycles);
    double perm_time_us = perm_time_ns / 1000.0;
    
    printf("Hardware permutation cycles: %u\n", perm_cycles);
    printf("Hardware permutation time: %.2f us\n", perm_time_us);
    printf("Speedup: %.2fx\n", (end_time - start_time) / perm_time_us);
    
    hdc.hvmemstr((uint32_t*)&HW_result, SPM_D_START_ADDR, sizeof(HV));
    
    #if DEBUG == 1
    printf("Software Permutation Result:\n");
    SW_result.print();
    printf("Hardware Permutation Result:\n");
    HW_result.print();
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