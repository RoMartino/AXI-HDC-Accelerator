#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>

extern "C" {
    #include "dataset_loader.h"
    #include "hdc_preprocessing.h"
    #include "model_io.h"
}

#include "../inc/hdc_class.hpp"

// Model input file (must match training output)
#define MODEL_INPUT_FILE "model.bin"

/**
 * Print usage information
 */
void print_usage(const char *program_name) {
    printf("Usage: %s <test_dataset.csv> [OPTIONS]\n", program_name);
    printf("\nArguments:\n");
    printf("  <test_dataset.csv>    Path to the test dataset CSV file (REQUIRED)\n");
    printf("\nOptions:\n");
    printf("  -accl                 Use hardware accelerator (default: CPU-only)\n");
    printf("  -h, --help            Show this help message\n");
    printf("\nExamples:\n");
    printf("  %s Dataset/iris/test.csv\n", program_name);
    printf("  %s Dataset/iris/test.csv -accl\n", program_name);
    printf("\nNote: The dataset argument is mandatory. The model file '%s' must exist.\n", MODEL_INPUT_FILE);
    printf("\n");
}

int main(int argc, char *argv[]) {
    
    // Parse command line arguments
    const char *test_file = NULL;
    bool use_accelerator = false;
    
    // Parse arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-accl") == 0) {
            use_accelerator = true;
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        } else if (argv[i][0] != '-') {
            // Assume it's the dataset file
            test_file = argv[i];
        } else {
            fprintf(stderr, "Error: Unknown option '%s'\n", argv[i]);
            print_usage(argv[0]);
            return 1;
        }
    }
    
    // Dataset file is required
    if (test_file == NULL) {
        fprintf(stderr, "Error: No test dataset file specified\n\n");
        print_usage(argv[0]);
        return 1;
    }
    
    const char *model_file = MODEL_INPUT_FILE;
    
    printf("=========================================\n");
    printf("         HDC Inference on Dataset        \n");
    printf("=========================================\n");
    printf("Configuration:\n");
    printf("  Inference mode: %s\n", use_accelerator ? "Hardware Accelerated" : "CPU (Software)");
    printf("  HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    printf("  Features: %d\n", DS_FEATURE_SIZE);
    printf("  Quantization levels: %d\n", HD_LV_LEN);
    printf("  Classes: %d\n", HD_CV_LEN);
    printf("  Test file: %s\n", test_file);
    printf("  Model file: %s\n", model_file);
    printf("=========================================\n\n");
    
    // Initialize HDC operator
    HDC_op hdc(HV_SIZE_BIT, DS_FEATURE_SIZE, HD_LV_LEN);
    
    if (use_accelerator) {
        printf("Initializing HDC hardware accelerator...\n");
        if (!hdc.is_hardware_initialized()) {
            fprintf(stderr, "Error: Hardware initialization failed\n");
            return 1;
        }
        printf("✓ Hardware initialized\n\n");
    } else {
        printf("Using CPU-based inference (software mode)\n\n");
    }
    
    // Load test dataset
    printf("Loading test dataset...\n");
    DatasetLoadConfig cfg;
    cfg.num_features = DS_FEATURE_SIZE;
    cfg.num_classes = HD_CV_LEN;
    cfg.delimiter = ',';
    cfg.label_column = -1;
    cfg.header_lines = 1;
    cfg.one_based_labels = 0;
    
    Dataset test_dataset;
    test_dataset.samples = NULL;
    test_dataset.num_samples = 0;
    if (load_dataset(test_file, &cfg, &test_dataset) != 0) {
        fprintf(stderr, "Error: Failed to load test dataset\n");
        return 1;
    }
    printf("✓ Loaded %d test samples\n\n", test_dataset.num_samples);
    
    // Load trained model
    printf("Loading trained model...\n");
    HV base_vectors[DS_FEATURE_SIZE];
    HV level_vectors[HD_LV_LEN];
    HV class_vectors[HD_CV_LEN];
    
    if (load_model(model_file,
                   base_vectors,
                   level_vectors,
                   class_vectors,
                   DS_FEATURE_SIZE,
                   HD_LV_LEN,
                   HD_CV_LEN) != 0) {
        fprintf(stderr, "Error: Failed to load model\n");
        return 1;
    }
    printf("✓ Model loaded\n\n");
    
    // Print loaded model vectors
    printf("=========================================\n");
    printf("          Loaded Model Vectors           \n");
    printf("=========================================\n\n");
    
    printf("BASE VECTORS:\n");
    for (int i = 0; i < DS_FEATURE_SIZE; i++) {
        printf("  Feature %d: ", i);
        base_vectors[i].print();
    }
    printf("\n");
    
    printf("LEVEL VECTORS:\n");
    for (int i = 0; i < HD_LV_LEN; i++) {
        printf("  Level %d: ", i);
        level_vectors[i].print();
    }
    printf("\n");
    
    printf("CLASS VECTORS (Associative Memory):\n");
    for (int i = 0; i < HD_CV_LEN; i++) {
        printf("  Class %d: ", i);
        class_vectors[i].print();
        
        // Print statistics for each class vector
        int sum = 0;
        for (int j = 0; j < HV_CHUNKS; j++) {
            sum += __builtin_popcount(class_vectors[i].chunk[j]);
        }
        printf("    → Bits set to 1: %d/%d (%.2f%%)\n", sum, HV_SIZE_BIT, (sum * 100.0) / HV_SIZE_BIT);
    }
    printf("\n");
    
    // Print Hamming distances between class vectors
    printf("HAMMING DISTANCES BETWEEN CLASS VECTORS:\n");
    for (int i = 0; i < HD_CV_LEN; i++) {
        for (int j = i + 1; j < HD_CV_LEN; j++) {
            uint32_t distance = 0;
            for (int k = 0; k < HV_CHUNKS; k++) {
                uint32_t xor_result = class_vectors[i].chunk[k] ^ class_vectors[j].chunk[k];
                distance += __builtin_popcount(xor_result);
            }
            printf("  Class %d <-> Class %d: %u bits (%.2f%%)\n", 
                   i, j, distance, (distance * 100.0) / HV_SIZE_BIT);
        }
    }
    printf("\n=========================================\n\n");
    
    press_enter_to_continue();
    
    // Hardware-specific initialization (only if using accelerator)
    if (use_accelerator) {
        // Load Base Vectors into SPM-A
    printf("Loading Base Vectors to hardware (SPM-A)...\n");
    for (int i = 0; i < DS_FEATURE_SIZE; i++) {
        hdc.hvmemld(SPM_A_START_ADDR + i * sizeof(HV), (uint32_t*)&base_vectors[i], sizeof(HV));
    }
    printf("✓ Base vectors loaded to SPM-A\n\n");

    // Retrieve the base vector from spm to check if they are loaded correctly
    HV retrieved_base_vectors[DS_FEATURE_SIZE];
    for(int i=0; i<DS_FEATURE_SIZE; i++){
        hdc.hvmemstr((uint32_t*)&retrieved_base_vectors[i], SPM_A_START_ADDR + i * sizeof(HV), sizeof(HV));
    }

    for(int i=0; i<DS_FEATURE_SIZE; i++){
        bool match = true;
        for(int j=0; j<HV_CHUNKS; j++){
            if(retrieved_base_vectors[i].chunk[j] != base_vectors[i].chunk[j]){
                match = false;
                printf("Debug: Mismatch at base vector %d, chunk %d: expected %X, got %X\n", i, j, base_vectors[i].chunk[j], retrieved_base_vectors[i].chunk[j]);
            }
        }
        if(!match){
            printf("Error: Mismatch in base vector %d after loading to SPM-A\n", i);
            return 1;
        }
    }
    printf("✓ Verified base vectors in SPM-A\n\n");
    
    // Load Level Vectors into SPM-B
    printf("Loading Level Vectors to hardware (SPM-B)...\n");
    for (int i = 0; i < HD_LV_LEN; i++) {
        hdc.hvmemld(SPM_B_START_ADDR + i * sizeof(HV), (uint32_t*)&level_vectors[i], sizeof(HV));
    }
    printf("✓ Level vectors loaded to SPM-B\n\n");
    
    // Retrieve the level vectors from SPM-B to check if they are loaded correctly
    HV retrieved_level_vectors[HD_LV_LEN];
    for(int i=0; i<HD_LV_LEN; i++){
        hdc.hvmemstr((uint32_t*)&retrieved_level_vectors[i], SPM_B_START_ADDR + i * sizeof(HV), sizeof(HV));
    }

    for(int i=0; i<HD_LV_LEN; i++){
        bool match = true;
        for(int j=0; j<HV_CHUNKS; j++){
            if(retrieved_level_vectors[i].chunk[j] != level_vectors[i].chunk[j]){
                match = false;
                printf("Debug: Mismatch at level vector %d, chunk %d: expected %X, got %X\n", i, j, level_vectors[i].chunk[j], retrieved_level_vectors[i].chunk[j]);
            }
        }
        if(!match){
            printf("Error: Mismatch in level vector %d after loading to SPM-B\n", i);
            return 1;
        }
    }
    printf("✓ Verified level vectors in SPM-B\n\n");

    // Load initial Class Vectors into SPM-D (starting after first BundledHV slot)
    printf("Loading Class Vectors to hardware (SPM-D)...\n");
    for (int i = 0; i < HD_CV_LEN; i++) {
        hdc.hvmemld(SPM_D_START_ADDR + sizeof(BundledHV) + i * sizeof(HV), (uint32_t*)&class_vectors[i], sizeof(HV));
    }
    printf("✓ Class vectors loaded to SPM-D\n\n");
    
    // Retrieve the class vectors from SPM-D to check if they are loaded correctly
    HV retrieved_class_vectors[HD_CV_LEN];
    for(int i = 0; i < HD_CV_LEN; i++){
        hdc.hvmemstr((uint32_t*)&retrieved_class_vectors[i], SPM_D_START_ADDR + sizeof(BundledHV) + i * sizeof(HV), sizeof(HV));
    }
    
    for(int i = 0; i < HD_CV_LEN; i++){
        bool match = true;
        for(int j = 0; j < HV_CHUNKS; j++){
            if(retrieved_class_vectors[i].chunk[j] != class_vectors[i].chunk[j]){
                match = false;
                printf("Debug: Mismatch at class vector %d, chunk %d: expected %X, got %X\n", i, j, class_vectors[i].chunk[j], retrieved_class_vectors[i].chunk[j]);
            }
        }
        if(!match){
            printf("Error: Mismatch in class vector %d after loading to SPM-D\n", i);
            return 1;
        }
    }
        printf("✓ Verified class vectors in SPM-D\n\n");
    }
    // Init a specific cell that we need to mantain it to zero
    BundledHV ZeroHV;
    hdc.hvmemld(SPM_D_START_ADDR + sizeof(BundledHV) + (HVCLASS + 1)*sizeof(BundledHV), (uint32_t*)&ZeroHV, sizeof(BundledHV));

    // Allocate memory for quantized features
    uint32_t *quantized_features = new uint32_t[DS_FEATURE_SIZE];

    // Generate quantization levels
    float quantization_levels[HD_LV_LEN + 2];
    generate_quantization_levels(0.0, 1.0, quantization_levels);

    press_enter_to_continue();
    
    // Inference loop
    printf("=========================================\n");
    printf("       Starting %s Inference       \n", use_accelerator ? "Hardware" : "CPU");
    printf("=========================================\n\n");
    
    int correct_predictions = 0;
    int total_predictions = 0;
    
    // Confusion matrix
    int confusion_matrix[HD_CV_LEN][HD_CV_LEN] = {0};
    
    time_t start_time = hdc.get_time_us();
    
    for (int i = 0; i < test_dataset.num_samples; i++) {
        DataSample *sample = get_sample(&test_dataset, i);
        if (!sample) continue;
        
        // Print sample info
        printf("Sample %d: [", i);
        for (int f = 0; f < DS_FEATURE_SIZE; f++) {
            printf("%.3f", sample->features[f]);
            if (f < DS_FEATURE_SIZE - 1) printf(", ");
        }
        printf("]\n");

        // Quantize features
        for(int f = 0; f < DS_FEATURE_SIZE; f++) {
            quantized_features[f] = get_quantized_level(sample->features[f], quantization_levels);
        }
        
        // Print quantized features
        printf("  Quantized Features: [");
        for (int f = 0; f < DS_FEATURE_SIZE; f++) {
            printf("%d", quantized_features[f]);
            if (f < DS_FEATURE_SIZE - 1) printf(", ");
        }
        printf("]\n");
        
        press_enter_to_continue();

        // Retrieve true label
        uint32_t true_label;
        if(cfg.one_based_labels)
            true_label = sample->label - 1;
        else
            true_label = sample->label;
            
        if (true_label >= HD_CV_LEN) {
            fprintf(stderr, "Warning: Invalid label %d for sample %d\n", sample->label, i);
            continue;
        }
        
        printf("  True Label: %d\n", true_label);
        press_enter_to_continue();

        // Perform inference (hardware or software)
        uint32_t predicted_label = 0;
        if (use_accelerator) {
            // Hardware inference using accelerator
            hdc.accl_inference(quantized_features,
                               SPM_A_START_ADDR,
                               SPM_B_START_ADDR,
                               SPM_D_START_ADDR + sizeof(BundledHV));
            
            // Retrieve hardware inference result
            hdc.hvmemstr((uint32_t*)&predicted_label, SPM_C_START_ADDR, sizeof(uint32_t)*SIMD);
        } else {
            // Software inference
            predicted_label = hdc.inference(quantized_features, 
                                            base_vectors, 
                                            level_vectors, 
                                            class_vectors);
        }
        printf("  Predicted Label: %d\n", predicted_label);
        press_enter_to_continue();
        // Update statistics
        total_predictions++;
        if (predicted_label == true_label) {
            correct_predictions++;
        }
        press_enter_to_continue();  
        // Update confusion matrix
        confusion_matrix[true_label][predicted_label]++;
        
        // Progress indicator
        if ((i + 1) % 100 == 0 || i == test_dataset.num_samples - 1) {
            float progress = 100.0f * (i + 1) / test_dataset.num_samples;
            float accuracy = 100.0f * correct_predictions / total_predictions;
            printf("  Progress: %d/%d samples (%.1f%%) - Accuracy: %.2f%%\r",
                   i + 1, test_dataset.num_samples, progress, accuracy);
            fflush(stdout);
        }

        press_enter_to_continue();
    }
    
    time_t end_time = hdc.get_time_us();
    int elapsed_us = (int)(end_time - start_time);
    
    printf("\n\n");
    
    // Calculate per-class accuracy
    printf("=========================================\n");
    printf("          Per-Class Accuracy             \n");
    printf("=========================================\n");
    
    int class_correct[HD_CV_LEN] = {0};
    int class_total[HD_CV_LEN] = {0};
    
    for (int i = 0; i < HD_CV_LEN; i++) {
        for (int j = 0; j < HD_CV_LEN; j++) {
            class_total[i] += confusion_matrix[i][j];
        }
        class_correct[i] = confusion_matrix[i][i];
        
        float class_accuracy = class_total[i] > 0 ? 
            100.0f * class_correct[i] / class_total[i] : 0.0f;
        
        printf("  Class %d: %3d/%3d correct (%.2f%%)\n",
               i, class_correct[i], class_total[i], class_accuracy);
    }
    
    printf("\n=========================================\n");
    printf("          Inference Summary              \n");
    printf("=========================================\n");
    printf("Test samples: %d\n", total_predictions);
    printf("Correct predictions: %d\n", correct_predictions);
    printf("Incorrect predictions: %d\n", total_predictions - correct_predictions);
    printf("\n** Overall Accuracy: %.2f%% **\n\n",
           100.0f * correct_predictions / total_predictions);
    printf("Inference time: %d us (%.3f samples/sec)\n",
           elapsed_us, elapsed_us > 0 ? (float)total_predictions * 1000000 / elapsed_us : 0);
    printf("=========================================\n\n");
    
    // Optionally save confusion matrix to file
    FILE *conf_file = fopen("confusion_matrix.txt", "w");
    if (conf_file) {
        fprintf(conf_file, "Confusion Matrix (rows=true, cols=predicted):\n\n");
        fprintf(conf_file, "     ");
        for (int j = 0; j < HD_CV_LEN; j++) {
            fprintf(conf_file, "%2d ", j);
        }
        fprintf(conf_file, "\n");
        
        for (int i = 0; i < HD_CV_LEN; i++) {
            fprintf(conf_file, "%2d: ", i);
            for (int j = 0; j < HD_CV_LEN; j++) {
                fprintf(conf_file, "%2d ", confusion_matrix[i][j]);
            }
            fprintf(conf_file, "\n");
        }
        fclose(conf_file);
        printf("Confusion matrix saved to confusion_matrix.txt\n\n");
    }
    
    // Clean up
    delete[] quantized_features;
    free_dataset(&test_dataset);
    
    return 0;
}
