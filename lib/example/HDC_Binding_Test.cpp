#include <cstdio>
#include <cstdlib>

#include "hdc_class.hpp"

int main(){

    printf("=========================================\n");
    printf("              Binding Test               \n");
    printf("=========================================\n");
    printf("This test verifies HDC Binding operation:\n");
    printf("1. Generates two random HVs\n");
    printf("2. Performs Binding operation in Software\n");
    printf("3. Performs Binding operation in Hardware\n");
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
    printf("\n");
    #endif

    // Perform Binding in Software
    uint64_t start_time, end_time;
    start_time = hdc.time_ns_monotonic();
    HV SW_result = hdc.bind(HV1, HV2);
    end_time = hdc.time_ns_monotonic();
    printf("Software binding time: %.2f us\n", (end_time - start_time) / 1000.0);

    //=====================================
    // HVBIND
    //=====================================
    HV HW_result;

    // Load HV1 into SPM_A and HV2 into SPM_B
    HV check_HV1, check_HV2;
    hdc.hvmemld(SPM_A_START_ADDR + sizeof(HV), (uint32_t*)&HV1, sizeof(HV));
    hdc.hvmemld(SPM_B_START_ADDR + sizeof(HV), (uint32_t*)&HV2, sizeof(HV));

    uint64_t start_bind_time = hdc.time_ns_monotonic();
    hdc.hvbind(SPM_D_START_ADDR, SPM_A_START_ADDR + sizeof(HV), SPM_B_START_ADDR + sizeof(HV));
    uint64_t end_bind_time = hdc.time_ns_monotonic();

    uint32_t bind_cycles = hdc.get_bind_cycles();
    double bind_time_ns = hdc.get_execution_time_ns(bind_cycles);
    double bind_time_us = bind_time_ns / 1000.0;
    
    printf("Hardware binding time (measured): %.2f us\n", (end_bind_time - start_bind_time) / 1000.0);
    printf("Hardware binding cycles: %u\n", bind_cycles);
    printf("Hardware binding time: %.2f us\n", bind_time_us);
    printf("Speedup: %.2fx\n", ((end_time - start_time) / 1000.0) / bind_time_us);
    
    hdc.hvmemstr((uint32_t*)&HW_result, SPM_D_START_ADDR, sizeof(HV));
    
    #if DEBUG == 1
    printf("Software Binding Result:\n");
    SW_result.print();
    printf("Hardware Binding Result:\n");
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