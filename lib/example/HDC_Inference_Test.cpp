#include <cstdio>
#include <cstdlib>
#include <ctime>
#include "hdc_class.hpp"

HV base_vectors[DS_FEATURE_SIZE];
HV level_vectors[HD_LV_LEN];
HV AssociativeMemory[HD_CV_LEN];

int main(){

    // Set the seed for random number generation
    srand((unsigned)time(NULL));

    printf("=========================================\n");
    printf("             Inference Test               \n");
    printf("=========================================\n");
    printf("This test verifies HDC inference operation:\n");
    printf("1. Generates random input feature vector\n");
    printf("2. Performs inference operation in Software\n");
    printf("3. Performs inference operation in Hardware\n");
    printf("4. Compares Software and Hardware results\n");
    printf("=========================================\n");
    printf("\n=========================================\n");
    printf("             Configuration              \n");
    printf("=========================================\n");
    printf("HV SIZE: %d\n", HV_SIZE_BIT);
    printf("FEATURES: %d\n", DS_FEATURE_SIZE);
    printf("LEVELS: %d\n", HD_LV_LEN);
    printf("CLASSES: %d\n", HD_CV_LEN);
    printf("=========================================\n");

    // Initialize HDC operator
    HDC_op hdc(HV_SIZE_BIT, DS_FEATURE_SIZE, HD_LV_LEN);
    if(!hdc.is_hardware_initialized()){
        printf("Hardware initialization failed. Exiting test.\n");
        return -1;
    }

    // Init Base Vectors
    hdc.generate_BaseVectors(base_vectors);

    // Init Level Vectors
    hdc.generate_LevelVectors(level_vectors);

    // Init a random Associative Memory
    for(int i = 0; i < HD_CV_LEN; i++){
        AssociativeMemory[i].randomize();
    }

    #if DEBUG == 1
    printf("Associative Memory Class Vectors:\n");
    for(int i = 0; i < HD_CV_LEN; i++){
        printf("Class %d:\n", i);
        AssociativeMemory[i].print();
        printf("\n");
    }
    #endif
    
    // Generate random input feature vector
    float input_feature_vector[DS_FEATURE_SIZE];
    hdc.generate_random_feature_vectors(input_feature_vector);

    #if DEBUG == 1
    printf("Input Feature Vector:\n");
    for(int i = 0; i < DS_FEATURE_SIZE; i++){
        printf("%.3f ", input_feature_vector[i]);
    }
    printf("\n");
    #endif

    // Generate the quantization levels
    // FIXED: Changed array size from [HD_LV_LEN] to [HD_LV_LEN + 2]
    float quantization_levels[HD_LV_LEN + 2];
    generate_quantization_levels(0.0, 1.0, quantization_levels);

    // Compute the quantization level of each feature
    uint32_t quantized_features[DS_FEATURE_SIZE];
    for (int i = 0; i < DS_FEATURE_SIZE; i++){
        quantized_features[i] = get_quantized_level(input_feature_vector[i], quantization_levels);
        #if DEBUG
            printf("Feature %d: -> quantized level: %d\n", i, quantized_features[i]);
        #endif
    }  
    
    // Software inference
    uint64_t start_time, end_time;
    start_time = hdc.time_ns_monotonic();
    int sw_inference = hdc.inference(quantized_features, base_vectors, level_vectors, AssociativeMemory);
    end_time = hdc.time_ns_monotonic();
    printf("Software inference time: %.2f us\n", (end_time - start_time) / 1000.0);
    while(1);
    #if DEBUG
    printf("Software Inference predicted label: %d\n", sw_inference);
    #endif

    // Load Base Vectors into SPM-A
    hdc.hvmemld(SPM_A_START_ADDR, (uint32_t*)&base_vectors, sizeof(HV)*DS_FEATURE_SIZE);
    // Load Level Vectors into SPM-B
    hdc.hvmemld(SPM_B_START_ADDR, (uint32_t*)&level_vectors, sizeof(HV)*HD_LV_LEN);
    // Load Associative Memory into SPM-D
    hdc.hvmemld(SPM_D_START_ADDR + sizeof(BundledHV), (uint32_t*)&AssociativeMemory, sizeof(HV)*HD_CV_LEN);
    // Load ZeroHV
    BundledHV zero_HV;
    hdc.hvmemld(SPM_D_START_ADDR + sizeof(BundledHV) + HVCLASS*sizeof(HV), (uint32_t*)&zero_HV, sizeof(BundledHV));

    // Hardware inference
    start_time = hdc.time_ns_monotonic();
    hdc.accl_inference(quantized_features, SPM_A_START_ADDR, SPM_B_START_ADDR, SPM_D_START_ADDR + sizeof(BundledHV));
    end_time = hdc.time_ns_monotonic();
    printf("Hardware inference time: %.2f us\n", (end_time - start_time) / 1000.0);
    
    // Retrieve hardware inference result
    uint32_t hw_inference;
    hdc.hvmemstr((uint32_t*)&hw_inference, SPM_C_START_ADDR, sizeof(uint32_t)*SIMD);

    #if DEBUG
    printf("Hardware Inference predicted label: %d\n", hw_inference);
    #endif

    //=====================================
    // TEST RESULTS
    //=====================================
    if(hdc.hvcompare((uint32_t*)&sw_inference, (uint32_t*)&hw_inference, sizeof(uint32_t))){
        printf("TEST PASSED\n");
    } else {
        printf("TEST FAILED\n");
    }
}