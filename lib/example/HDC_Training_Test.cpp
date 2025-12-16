#include <cstdio>
#include <cstdlib>

#include "hdc_class.hpp"

HV base_vectors[DS_FEATURE_SIZE];
HV level_vectors[HD_LV_LEN];
BundledHV ClassVectors[HD_CV_LEN];
BundledHV accl_ClassVectors[HD_CV_LEN];

int main(){

    printf("=========================================\n");
    printf("             Training Test               \n");
    printf("=========================================\n");
    printf("This test verifies HDC training operation:\n");
    printf("1. Generates random input feature vector\n");
    printf("2. Performs training operation in Software\n");
    printf("3. Performs training operation in Hardware\n");
    printf("4. Compares Software and Hardware results\n");
    printf("=========================================\n");
    printf("\n=========================================\n");
    printf("             Configuration              \n");
    printf("=========================================\n");
    printf("HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    printf("HV_CHUNKS: %d\n", HV_CHUNKS);
    printf("HVSIZE_BYTES: %d\n", HVSIZE_BYTES);
    printf("DS_FEATURE_SIZE: %d\n", DS_FEATURE_SIZE);
    printf("HD_LV_LEN: %d\n", HD_LV_LEN);
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

    // Software training
    uint64_t start_time, end_time;
    start_time = hdc.time_ns_monotonic();
    BundledHV sw_trained_hv = hdc.training(quantized_features, base_vectors, level_vectors, ClassVectors, 0);
    end_time = hdc.time_ns_monotonic();
    printf("Software training time: %.2f us\n", (end_time - start_time) / 1000.0);

    while(1);
    #if DEBUG
    printf("Software Trained HV: ");
    sw_trained_hv.print();
    printf("\n");
    #endif

    // Load Base Vectors into SPM-A
    hdc.hvmemld(SPM_A_START_ADDR, (uint32_t*)&base_vectors, sizeof(HV)*DS_FEATURE_SIZE);

    // Load Level Vectors into SPM-B
    hdc.hvmemld(SPM_B_START_ADDR, (uint32_t*)&level_vectors, sizeof(HV)*HD_LV_LEN);

    // Reset SPM-D
    BundledHV zeroHV;
    for(int i = 0; i < HD_CV_LEN; i++){
        hdc.hvmemld(SPM_D_START_ADDR + i*sizeof(BundledHV), (uint32_t*)&zeroHV, sizeof(BundledHV));
    }

    // Load ZeroHV
    BundledHV zero_HV;
    hdc.hvmemld(SPM_D_START_ADDR + sizeof(BundledHV) + (HVCLASS + 1)*sizeof(BundledHV), (uint32_t*)&zero_HV, sizeof(BundledHV));

    // Hardware training
    hdc.accl_training(quantized_features, SPM_A_START_ADDR, SPM_B_START_ADDR, SPM_D_START_ADDR + sizeof(BundledHV),  0);

    // Retrieve trained HV from SPM-D
    BundledHV hw_trained_hv;
    hdc.hvmemstr((uint32_t*)&hw_trained_hv, (SPM_D_START_ADDR + sizeof(BundledHV)*(0+1)), sizeof(BundledHV));

    #if DEBUG
    printf("Hardware Trained HV: ");
    hw_trained_hv.print();
    printf("\n");
    #endif

    //=====================================
    // TEST RESULTS
    //=====================================
    if(hdc.hvcompare((uint32_t*)&sw_trained_hv, (uint32_t*)&hw_trained_hv, sizeof(HV))){
        printf("TEST PASSED\n");
    } else {
        printf("TEST FAILED\n");
    }
}