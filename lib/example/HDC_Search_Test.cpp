#include <cstdio>
#include <cstdlib>
#include <ctime>

#include "hdc_class.hpp"

int main(){

    // Seed the random number generator
    srand((unsigned int)time(NULL));

    printf("=========================================\n");
    printf("          Associative Search Test       \n");
    printf("=========================================\n");
    printf("This test verifies HDC Associative Search operation:\n");
    printf("1. Generates n random Class Vectors\n");
    printf("2. Generates a random Query Vector\n");
    printf("3. Performs Associative Search operation in Software\n");
    printf("4. Performs Associative Search operation in Hardware\n");
    printf("5. Compares Software and Hardware results\n");
    printf("=========================================\n");
    printf("\n=========================================\n");
    printf("             Configuration              \n");
    printf("=========================================\n");
    printf("HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    printf("HV_CHUNKS: %d\n", HV_CHUNKS);
    printf("HVSIZE_BYTES: %d\n", HVSIZE_BYTES);
    printf("NUM_CLASSES: %d\n", HVCLASS);
    printf("=========================================\n");

    // Initialize HDC operator
    HDC_op hdc(HV_SIZE_BIT, DS_FEATURE_SIZE, HD_LV_LEN);
    if(!hdc.is_hardware_initialized()){
        printf("Hardware initialization failed. Exiting test.\n");
        return -1;
    }

    // Generate Associtiative Memory
    HV Associative_Memory[HVCLASS];
    HV Query_Vector;

    // Generate random Class Vectors
    for(int i = 0; i < HVCLASS; i++){
        Associative_Memory[i].randomize();
    }

    // Generate random Query Vector
    Query_Vector.randomize();
    
    #if DEBUG == 1
    printf("Associative Memory Class Vectors:\n");
    for(int i = 0; i < HVCLASS; i++){
        printf("Class %d:\n", i);
        Associative_Memory[i].print();
        printf("\n");
    }
    printf("Query Vector:\n");
    Query_Vector.print();
    printf("\n");
    #endif

    // Perform Associative Search in Softwareù
    uint64_t start_time, end_time;
    start_time = hdc.time_ns_monotonic();
    int SW_result = hdc.search(Query_Vector, Associative_Memory);
    end_time = hdc.time_ns_monotonic();
    printf("Software search time: %.2f us\n", (end_time - start_time) / 1000.0);

    //=====================================
    // HVSEARCH
    //=====================================
    int HW_result;

    // Load Associative Memory into SPM_D
    for(int i = 0; i < HVCLASS; i++){
        hdc.hvmemld(SPM_D_START_ADDR + i * sizeof(HV), (uint32_t*)&Associative_Memory[i], sizeof(HV));
    }

    // Load the Query Vector into SPM_A
    hdc.hvmemld(SPM_A_START_ADDR, (uint32_t*)&Query_Vector, sizeof(HV));

    hdc.hvsearch(SPM_C_START_ADDR, SPM_A_START_ADDR, SPM_D_START_ADDR);
    usleep(1000);
    uint32_t search_cycles = hdc.get_as_cycles();
    double search_time_ns = hdc.get_execution_time_ns(search_cycles);
    double search_time_us = search_time_ns / 1000.0;
    
    printf("Hardware search cycles: %u\n", search_cycles);
    printf("Hardware search time: %.2f us\n", search_time_us);
    printf("Speedup: %.2fx\n", ((end_time - start_time) / 1000.0) / search_time_us);

    hdc.hvmemstr((uint32_t*)&HW_result, SPM_C_START_ADDR, sizeof(uint32_t)*SIMD);
    
    #if DEBUG == 1
    printf("Software Search Result: ");
    printf("%d\n", SW_result);
    printf("Hardware Search Result: ");
    printf("%d\n", HW_result);
    #endif

    //=====================================
    // TEST RESULTS
    //=====================================
    if(hdc.hvcompare((uint32_t*)&SW_result, (uint32_t*)&HW_result, sizeof(int))){
        printf("TEST PASSED\n");
    } else {
        printf("TEST FAILED\n");
    }
}