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

// Model output file
#define MODEL_OUTPUT_FILE "model.bin"

/**
 * Print usage information
 */
void print_usage(const char *program_name) {
    printf("Usage: %s <dataset.csv> [OPTIONS]\n", program_name);
    printf("\nArguments:\n");
    printf("  <dataset.csv>    Path to the training dataset CSV file (REQUIRED)\n");
    printf("\nOptions:\n");
    printf("  -accl            Use hardware accelerator (default: CPU-only)\n");
    printf("  -h, --help       Show this help message\n");
    printf("\nExamples:\n");
    printf("  %s Dataset/iris/train.csv\n", program_name);
    printf("  %s Dataset/iris/train.csv -accl\n", program_name);
    printf("\nNote: The dataset argument is mandatory. Use -accl flag for hardware acceleration.\n");
    printf("\n");
}

int main(int argc, char *argv[]) {

    // Seed the random number generator
    srand((unsigned)time(NULL));

    // Parse command line arguments
    const char *training_file = NULL;
    bool use_accelerator = false;
    unsigned int training_time_us = 0;

    // Parse arguments
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-accl") == 0) {
            use_accelerator = true;
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        } else if (argv[i][0] != '-') {
            // Assume it's the dataset file
            training_file = argv[i];
        } else {
            fprintf(stderr, "Error: Unknown option '%s'\n", argv[i]);
            print_usage(argv[0]);
            return 1;
        }
    }
    
    // Dataset file is required
    if (training_file == NULL) {
        fprintf(stderr, "Error: No dataset file specified\n\n");
        print_usage(argv[0]);
        return 1;
    }
    
    int num_epochs = EPOCHS;
    
    printf("=========================================\n");
    printf("    HDC Training on Dataset             \n");
    printf("=========================================\n");
    printf("Configuration:\n");
    printf("  Training mode: %s\n", use_accelerator ? "Hardware Accelerated" : "CPU (Software)");
    printf("  HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    printf("  Features: %d\n", DS_FEATURE_SIZE);
    printf("  Quantization levels: %d\n", HD_LV_LEN);
    printf("  Classes: %d\n", HD_CV_LEN);
    printf("  Training epochs: %d\n", num_epochs);
    printf("  Training file: %s\n", training_file);
    printf("  Output model: %s\n", MODEL_OUTPUT_FILE);
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
        printf("Using CPU-based training (software mode)\n\n");
    }
    
    // Load training dataset
    printf("Loading training dataset...\n");
    DatasetLoadConfig cfg;
    cfg.num_features = DS_FEATURE_SIZE;           
    cfg.num_classes = HD_CV_LEN;
    cfg.delimiter = ',';         
    cfg.label_column = -1;      
    cfg.header_lines = 1;        
    cfg.one_based_labels = 0;    
    
    Dataset train_dataset;
    train_dataset.samples = NULL;
    train_dataset.num_samples = 0;
    if (load_dataset(training_file, &cfg, &train_dataset) != 0) {
        fprintf(stderr, "Error: Failed to load training dataset\n");
        return 1;
    }
    printf("✓ Loaded %d training samples\n\n", train_dataset.num_samples);
    
    // Print dataset stats
    print_dataset_stats_generic(&train_dataset);

    // Generate Base Vectors
    printf("Generating Base Vectors...\n");
    HV base_vectors[DS_FEATURE_SIZE];
    hdc.generate_BaseVectors(base_vectors);
    printf("✓ Generated %d base vectors\n\n", DS_FEATURE_SIZE);
    
    // Print Base Vectors
    #if DEBUG == 1
    printf("Base Vectors:\n");
    for (int i = 0; i < DS_FEATURE_SIZE; i++) {
        printf("Feature %d: ", i);
        base_vectors[i].print();
    }
    printf("\n");
    #endif

    // Generate Level Vectors
    printf("Generating Level Vectors...\n");
    HV level_vectors[HD_LV_LEN];
    hdc.generate_LevelVectors(level_vectors);
    printf("✓ Generated %d level vectors\n\n", HD_LV_LEN);
    
    // Print Level Vectors
    #if DEBUG == 1
    printf("Level Vectors:\n");
    for (int i = 0; i < HD_LV_LEN; i++) {
        printf("Level %d: ", i);
        level_vectors[i].print();
    }
    printf("\n");
    #endif

    // Initialize Class Vectors (Bundled HVs) 
    printf("Initializing Associative Memory...\n");
    BundledHV class_vectors[HD_CV_LEN];
    printf("✓ Initialized %d class vectors\n\n", HD_CV_LEN);
    

    press_enter_to_continue();

    // Hardware-specific initialization
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
                    printf("Debug: Mismatch at base vector %d, chunk %d: expected %08X, got %08X\n", i, j, base_vectors[i].chunk[j], retrieved_base_vectors[i].chunk[j]);
                }
            }
            if(!match){
                printf("Error: Mismatch in base vector %d after loading to SPM-A\n", i);
                return 1;
            }
        }
        printf("✓ Verified base vectors in SPM-A\n\n");
        
        // Load Level Vectors into SPM-B
        printf("Loading Level Vectors to SPM-B...\n");
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
                    printf("Debug: Mismatch at level vector %d, chunk %d: expected %08X, got %08X\n", i, j, level_vectors[i].chunk[j], retrieved_level_vectors[i].chunk[j]);
                }
            }
            if(!match){
                printf("Error: Mismatch in level vector %d after loading to SPM-B\n", i);
                return 1;
            }
        }
        printf("✓ Verified level vectors in SPM-B\n\n");

        // Init with Zero the SPM-D
        BundledHV zero_BundledHV;
        printf("Init SPM-D with zeros...\n");
        for (int i = 0; i < 4*HD_CV_LEN; i++) {
            hdc.hvmemld(SPM_D_START_ADDR + i * sizeof(BundledHV), (uint32_t*)&zero_BundledHV, sizeof(BundledHV));
        }
        printf("✓ Initialized SPM-D with zeros\n\n");
        
        // Check if SPM-D is zeroed correctly
        BundledHV retrieved_class_vectors[HD_CV_LEN];
        for(int i = 0; i < HD_CV_LEN; i++){
            hdc.hvmemstr((uint32_t*)&retrieved_class_vectors[i], SPM_D_START_ADDR + i * sizeof(BundledHV), sizeof(BundledHV));
        }
        
        for(int i = 0; i < HD_CV_LEN; i++){
            bool match = true;
            for(int j = 0; j < HV_CHUNKS * COUNTER_BITS; j++){
                if(retrieved_class_vectors[i].bundled_chunk[j] != class_vectors[i].bundled_chunk[j]){
                    match = false;
                    printf("Debug: Mismatch at class vector %d, bundled_chunk %d: expected %08X, got %08X\n", i, j, class_vectors[i].bundled_chunk[j], retrieved_class_vectors[i].bundled_chunk[j]);
                }
            }
            if(!match){
                printf("Error: Mismatch in class vector %d after loading to SPM-D\n", i);
                return 1;
            }
        }
        printf("✓ Verified class vectors in SPM-D\n\n");
    }
    
    // Allocate memory for quantized features
    uint32_t *quantized_features = new uint32_t[DS_FEATURE_SIZE];

    // Generate quantization levels
    float quantization_levels[HD_LV_LEN + 2];
    generate_quantization_levels(0.0, 1.0, quantization_levels);
    
    // DEBUG: Print quantization levels for comparison with Python
    printf("\n[DEBUG] Quantization Levels Generated:\n");
    printf("  Total levels: %d\n", HD_LV_LEN + 2);
    printf("  First 5 levels: ");
    for(int i = 0; i < 5 && i < HD_LV_LEN + 2; i++) {
        printf("%.6f ", quantization_levels[i]);
    }
    printf("\n  Last 5 levels: ");
    for(int i = (HD_LV_LEN + 2 > 5 ? HD_LV_LEN - 3 : 0); i < HD_LV_LEN + 2; i++) {
        printf("%.6f ", quantization_levels[i]);
    }
    printf("\n  Gap between levels: %.6f\n\n", quantization_levels[1] - quantization_levels[0]);
    
    press_enter_to_continue();

    // Initialize class label counters for clipping
    int *class_counts = new int[HD_CV_LEN](); // dynamically sized counts (zero-initialized)
    
    // Training loop
    printf("=========================================\n");
    printf("       Starting %s Training        \n", use_accelerator ? "Hardware" : "CPU");
    printf("=========================================\n\n");
    
    for (int epoch = 0; epoch < num_epochs; epoch++) {
        printf("\n----------------------------------------\n");
        printf("Epoch %d/%d:\n", epoch + 1, num_epochs);
        printf("----------------------------------------\n");
        
        int samples_processed = 0;
        time_t start_epoch_time = hdc.get_time_us();
        
        // Train on samples 
        for (int i = 0; i < train_dataset.num_samples; i++) {
            DataSample *sample = get_sample(&train_dataset, i);
            if (!sample) continue;
        
            // Get Quantized features
            for(int f = 0; f < DS_FEATURE_SIZE; f++) {
                quantized_features[f] = get_quantized_level(sample->features[f], quantization_levels);
            }
            
            // DEBUG: Print details for first few samples to compare with Python
            if(i < 3){
                printf("\n[DEBUG] Sample %d:\n", i);
                printf("  Raw features: ");
                for(int f = 0; f < DS_FEATURE_SIZE; f++){
                    printf("%.6f ", sample->features[f]);
                }
                printf("\n  Quantized levels: ");
                for(int f = 0; f < DS_FEATURE_SIZE; f++){
                    printf("%u ", quantized_features[f]);
                }
                printf("\n  Label: %d\n", sample->label);
            }

            // Retrieve class index and update counters
            int class_idx;

            if(cfg.one_based_labels)
                class_idx = sample->label - 1; // Convert 1-based to 0-based
            else
                class_idx = sample->label;
                
            class_counts[class_idx]++; 
            
            if (class_idx < 0 || class_idx >= HD_CV_LEN) {
                fprintf(stderr, "Warning: Invalid label %d for sample %d\n", sample->label, i);
                continue;
            }
            
            // Perform training 
            if (use_accelerator) {
                // Hardware training using accelerator
                hdc.accl_training(quantized_features, 
                                SPM_A_START_ADDR, 
                                SPM_B_START_ADDR,
                                SPM_D_START_ADDR + sizeof(BundledHV),
                                class_idx);
            } else {
                // Software training
                hdc.training(quantized_features, 
                             base_vectors, 
                             level_vectors, 
                             class_vectors,
                             class_idx);
            }
            
            samples_processed++;
            
            // Progress indicator
            if ((i + 1) % 100 == 0 || i == train_dataset.num_samples - 1) {
                printf("  Progress: %d/%d samples (%.1f%%)\r", 
                       i + 1, train_dataset.num_samples, 100.0f * (i + 1) / train_dataset.num_samples);
                fflush(stdout);
            }
        }
        
        time_t end_epoch_time = hdc.get_time_us();
        int epoch_time = (int)(end_epoch_time - start_epoch_time);
        training_time_us += epoch_time;

        printf("\n  ✓ Epoch %d complete: %d samples processed in %d us (%.3f samples/sec)\n", 
               epoch + 1, 
               samples_processed, 
               epoch_time,
               epoch_time > 0 ? (float)samples_processed * 1000000 / epoch_time : 0);
    }

    #if TRAINING_DEBUG
    printf("\n============================================\n");
    printf(" Training Complete - Class Vectors \n");
    printf("============================================\n\n");
    if(use_accelerator){
        // Retrieve class vectors from hardware memory
        for (int i = 0; i < HD_CV_LEN; i++) {
            hdc.hvmemstr((uint32_t*)&class_vectors[i], 
                          SPM_D_START_ADDR + sizeof(BundledHV) + i * sizeof(BundledHV), 
                          sizeof(BundledHV));
        }
    }
    printf("Trained Class Vectors (Before Clipping):\n");
    for (int i = 0; i < HD_CV_LEN; i++) {
        printf("Class %d: ", i); 
        class_vectors[i].print();
    }
    #endif

    printf("\n============================================\n");
    printf(" Training Complete - Clipping Class Vectors \n");
    printf("============================================\n\n");
    
    HV *class_vectors_clipped = new HV[HD_CV_LEN];
    
    if (use_accelerator) {
        // Clip bundled class vectors from hardware memory
        for (int i = 0; i < HD_CV_LEN; i++) {
            printf("Clipping class %d. Counted samples: %d\n", i, class_counts[i]);
            
            // Clip the bundled class vector in hardware
            hdc.hvclip(SPM_D_START_ADDR + sizeof(BundledHV) + i * sizeof(HV),
                       SPM_D_START_ADDR + sizeof(BundledHV) + i * sizeof(BundledHV),
                       class_counts[i]);
            
            // Retrieve clipped vector from hardware
            hdc.hvmemstr((uint32_t*)&class_vectors_clipped[i], 
                          SPM_D_START_ADDR + sizeof(BundledHV) + i * sizeof(HV), 
                          sizeof(HV));
        }
    } else {
        // Clip bundled class vectors in software
        for (int i = 0; i < HD_CV_LEN; i++) {
            printf("Clipping class %d. Counted samples: %d\n", i, class_counts[i]);
            
            // Software clipping
            class_vectors_clipped[i] = hdc.clip(class_vectors[i], class_counts[i]);
        }
    }
    printf("\n✓ All class vectors clipped\n\n");
    
    // DEBUG: Print sum of each clipped class vector for comparison
    printf("\n[DEBUG] Clipped Class Vectors Summary:\n");
    for (int i = 0; i < HD_CV_LEN; i++) {
        int sum = 0;
        for(int j = 0; j < HV_CHUNKS; j++) {
            // Count bits set to 1 in each chunk
            sum += __builtin_popcount(class_vectors_clipped[i].chunk[j]);
        }
        printf("  Class %d: sum=%d (trained on %d samples)\n", i, sum, class_counts[i]);
    }
    
    // DEBUG: Print Hamming distances between clipped class vectors
    printf("\n[DEBUG] Hamming Distances Between Clipped Class Vectors:\n");
    for (int i = 0; i < HD_CV_LEN; i++) {
        for (int j = i + 1; j < HD_CV_LEN; j++) {
            uint32_t distance = 0;
            for(int k = 0; k < HV_CHUNKS; k++) {
                uint32_t xor_result = class_vectors_clipped[i].chunk[k] ^ class_vectors_clipped[j].chunk[k];
                distance += __builtin_popcount(xor_result);
            }
            printf("  Class %d <-> Class %d: %u bits\n", i, j, distance);
        }
    }
    printf("\n");
    
    #if PRINT_TRAINED_MODEL
    // Print trained model details
    printf("Trained Class Vectors (Clipped):\n");
    for (int i = 0; i < HD_CV_LEN; i++) {
        printf("Class %d: ", i);
        class_vectors_clipped[i].print();
    }
    #endif
    
    printf("\n=========================================\n");
    printf("        Training Summary                 \n");
    printf("=========================================\n");
    printf("Training samples: %d\n", train_dataset.num_samples);
    printf("Epochs: %d\n", num_epochs);
    printf("Total training iterations: %d\n", train_dataset.num_samples * num_epochs);
    printf("Hardware Accelerator Used: %s\n", use_accelerator ? "Yes" : "No");
    printf("Training time: %u us\n", training_time_us);
    printf("Model file: %s\n", MODEL_OUTPUT_FILE);
    printf("\nAssociative Memory:\n");
    printf("  Base vectors: %d × %d bits (%.2f KB)\n", DS_FEATURE_SIZE, HV_SIZE_BIT, (DS_FEATURE_SIZE * HV_SIZE_BIT / 8.0) / 1024.0);
    printf("  Level vectors: %d × %d bits (%.2f KB)\n", HD_LV_LEN, HV_SIZE_BIT, (HD_LV_LEN * HV_SIZE_BIT / 8.0) / 1024.0);
    printf("  Class vectors: %d × %d bits (%.2f KB)\n", HD_CV_LEN, HV_SIZE_BIT, (HD_CV_LEN * HV_SIZE_BIT / 8.0) / 1024.0);
    printf("\nThe trained model is ready for inference!\n");
    printf("=========================================\n\n");
    
    // Save the trained model
    printf("=========================================\n");
    printf("          Saving Trained Model           \n");
    printf("=========================================\n\n");
    
    // Text model filename
    const char *txt_model_file = "model.txt";
    
    // Save binary model
    if (save_model(MODEL_OUTPUT_FILE,
                   base_vectors,
                   level_vectors,
                   class_vectors_clipped,
                   DS_FEATURE_SIZE,
                   HD_LV_LEN,
                   HD_CV_LEN) != 0) {
        fprintf(stderr, "Error: Failed to save binary model\n");
        goto cleanup;
    }
    printf("✓ Binary model saved to '%s'\n", MODEL_OUTPUT_FILE);
    
    // Save text model
    if (save_model_txt(txt_model_file,
                       base_vectors,
                       level_vectors,
                       class_vectors_clipped,
                       DS_FEATURE_SIZE,
                       HD_LV_LEN,
                       HD_CV_LEN) != 0) {
        fprintf(stderr, "Error: Failed to save text model\n");
        goto cleanup;
    }
    printf("✓ Text model saved to '%s'\n", txt_model_file);
    printf("\n");
    
cleanup:
    // Clean up
    delete[] class_vectors_clipped;
    delete[] quantized_features;
    delete[] class_counts;
    free_dataset(&train_dataset);
    
    return 0;
}
