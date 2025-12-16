#include "model_io.h"
#include <cstdio>
#include <cstring>
#include <ctime>
#include <sys/stat.h>

/**
 * Save a trained HDC model to a binary file
 */
int save_model(const char *filename, 
               HV *base_vectors, 
               HV *level_vectors, 
               HV *class_vectors,
               int num_features,
               int num_levels,
               int num_classes) {
    
    FILE *file = fopen(filename, "wb");
    if (!file) {
        fprintf(stderr, "Error: Cannot create model file %s\n", filename);
        return -1;
    }
    
    // Write header
    ModelHeader header;
    header.magic_number = MODEL_MAGIC;
    header.hv_size_bit = HV_SIZE_BIT;
    header.num_features = num_features;
    header.num_levels = num_levels;
    header.num_classes = num_classes;
    header.timestamp = (uint32_t)time(NULL);
    
    if (fwrite(&header, sizeof(ModelHeader), 1, file) != 1) {
        fprintf(stderr, "Error: Failed to write model header\n");
        fclose(file);
        return -1;
    }
    
    // Write base vectors
    if (fwrite(base_vectors, sizeof(HV), num_features, file) != (size_t)num_features) {
        fprintf(stderr, "Error: Failed to write base vectors\n");
        fclose(file);
        return -1;
    }
    
    // Write level vectors
    if (fwrite(level_vectors, sizeof(HV), num_levels, file) != (size_t)num_levels) {
        fprintf(stderr, "Error: Failed to write level vectors\n");
        fclose(file);
        return -1;
    }
    
    // Write class vectors (Associative memory)
    if (fwrite(class_vectors, sizeof(HV), num_classes, file) != (size_t)num_classes) {
        fprintf(stderr, "Error: Failed to write class vectors\n");
        fclose(file);
        return -1;
    }
    
    fclose(file);
    
    // Get file size and print confirmation
    struct stat st;
    if (stat(filename, &st) == 0) {
        printf("Model saved successfully to %s (%.2f KB)\n", 
               filename, st.st_size / 1024.0);
    }
    
    return 0;
}

/**
 * Load a trained HDC model from a binary file
 */
int load_model(const char *filename,
               HV *base_vectors,
               HV *level_vectors,
               HV *class_vectors,
               int expected_features,
               int expected_levels,
               int expected_classes) {
    
    FILE *file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "Error: Cannot open model file %s\n", filename);
        return -1;
    }
    
    // Read header
    ModelHeader header;
    if (fread(&header, sizeof(ModelHeader), 1, file) != 1) {
        fprintf(stderr, "Error: Failed to read model header\n");
        fclose(file);
        return -1;
    }
    
    // Validate magic number
    if (header.magic_number != MODEL_MAGIC) {
        fprintf(stderr, "Error: Invalid model file (magic number mismatch)\n");
        fclose(file);
        return -1;
    }
    
    // Validate configuration
    if (header.hv_size_bit != (uint32_t)HV_SIZE_BIT) {
        fprintf(stderr, "Error: Model HV size (%u) doesn't match current configuration (%d)\n",
                header.hv_size_bit, HV_SIZE_BIT);
        fclose(file);
        return -1;
    }
    
    if (header.num_features != (uint32_t)expected_features) {
        fprintf(stderr, "Error: Model features (%u) doesn't match expected (%d)\n",
                header.num_features, expected_features);
        fclose(file);
        return -1;
    }
    
    if (header.num_levels != (uint32_t)expected_levels) {
        fprintf(stderr, "Error: Model levels (%u) doesn't match expected (%d)\n",
                header.num_levels, expected_levels);
        fclose(file);
        return -1;
    }
    
    if (header.num_classes != (uint32_t)expected_classes) {
        fprintf(stderr, "Error: Model classes (%u) doesn't match expected (%d)\n",
                header.num_classes, expected_classes);
        fclose(file);
        return -1;
    }
    
    // Read base vectors
    if (fread(base_vectors, sizeof(HV), expected_features, file) != (size_t)expected_features) {
        fprintf(stderr, "Error: Failed to read base vectors\n");
        fclose(file);
        return -1;
    }
    
    // Read level vectors
    if (fread(level_vectors, sizeof(HV), expected_levels, file) != (size_t)expected_levels) {
        fprintf(stderr, "Error: Failed to read level vectors\n");
        fclose(file);
        return -1;
    }
    
    // Read class vectors (associative memory)
    if (fread(class_vectors, sizeof(HV), expected_classes, file) != (size_t)expected_classes) {
        fprintf(stderr, "Error: Failed to read class vectors\n");
        fclose(file);
        return -1;
    }
    
    fclose(file);
    
    // Print model info
    time_t timestamp = header.timestamp;
    printf("Model loaded successfully:\n");
    printf("  Trained on: %s", ctime(&timestamp));
    printf("  HV size: %u bits\n", header.hv_size_bit);
    printf("  Features: %u\n", header.num_features);
    printf("  Levels: %u\n", header.num_levels);
    printf("  Classes: %u\n", header.num_classes);
    
    return 0;
}

/**
 * Save a trained HDC model to a text file (human-readable format)
 */
int save_model_txt(const char *filename, 
                   HV *base_vectors, 
                   HV *level_vectors, 
                   HV *class_vectors,
                   int num_features,
                   int num_levels,
                   int num_classes) {
    
    FILE *file = fopen(filename, "w");
    if (!file) {
        fprintf(stderr, "Error: Cannot create text model file %s\n", filename);
        return -1;
    }
    
    // Write header information
    time_t now = time(NULL);
    fprintf(file, "# HDC Model (Text Format)\n");
    fprintf(file, "# Generated: %s", ctime(&now));
    fprintf(file, "# HV_SIZE_BIT: %d\n", HV_SIZE_BIT);
    fprintf(file, "# NUM_FEATURES: %d\n", num_features);
    fprintf(file, "# NUM_LEVELS: %d\n", num_levels);
    fprintf(file, "# NUM_CLASSES: %d\n", num_classes);
    fprintf(file, "\n");
    
    // Write base vectors
    fprintf(file, "# BASE VECTORS\n");
    for (int i = 0; i < num_features; i++) {
        fprintf(file, "BaseVector %d: [", i);
        // Print chunks in reverse order (MSB chunks first) to match HV::print()
        for (int j = HV_CHUNKS - 1; j >= 0; j--) {
            // Print each chunk as 32-bit binary
            for (int bit = 31; bit >= 0; bit--) {
                fprintf(file, "%d", (base_vectors[i].chunk[j] >> bit) & 1);
            }
        }
        fprintf(file, "]\n");
    }
    fprintf(file, "\n");
    
    // Write level vectors
    fprintf(file, "# LEVEL VECTORS\n");
    for (int i = 0; i < num_levels; i++) {
        fprintf(file, "LevelVector %d: [", i);
        // Print chunks in reverse order (MSB chunks first) to match HV::print()
        for (int j = HV_CHUNKS - 1; j >= 0; j--) {
            // Print each chunk as 32-bit binary
            for (int bit = 31; bit >= 0; bit--) {
                fprintf(file, "%d", (level_vectors[i].chunk[j] >> bit) & 1);
            }
        }
        fprintf(file, "]\n");
    }
    fprintf(file, "\n");
    
    // Write class vectors (associative memory)
    fprintf(file, "# CLASS VECTORS (Associative Memory)\n");
    for (int i = 0; i < num_classes; i++) {
        fprintf(file, "Class %d: [", i);
        // Print chunks in reverse order (MSB chunks first) to match HV::print()
        for (int j = HV_CHUNKS - 1; j >= 0; j--) {
            // Print each chunk as 32-bit binary
            for (int bit = 31; bit >= 0; bit--) {
                fprintf(file, "%d", (class_vectors[i].chunk[j] >> bit) & 1);
            }
        }
        fprintf(file, "]\n");
        
        // Add statistics for class vector
        int sum = 0;
        for (int j = 0; j < HV_CHUNKS; j++) {
            sum += __builtin_popcount(class_vectors[i].chunk[j]);
        }
        fprintf(file, "#   Bits set to 1: %d out of %d (%.2f%%)\n", 
                sum, HV_SIZE_BIT, (sum * 100.0) / HV_SIZE_BIT);
    }
    fprintf(file, "\n");
    
    // Write Hamming distances between class vectors
    fprintf(file, "# HAMMING DISTANCES BETWEEN CLASS VECTORS\n");
    for (int i = 0; i < num_classes; i++) {
        for (int j = i + 1; j < num_classes; j++) {
            uint32_t distance = 0;
            for (int k = 0; k < HV_CHUNKS; k++) {
                uint32_t xor_result = class_vectors[i].chunk[k] ^ class_vectors[j].chunk[k];
                distance += __builtin_popcount(xor_result);
            }
            fprintf(file, "# Class %d <-> Class %d: %u bits (%.2f%%)\n", 
                    i, j, distance, (distance * 100.0) / HV_SIZE_BIT);
        }
    }
    
    fclose(file);
    
    // Get file size and print confirmation
    struct stat st;
    if (stat(filename, &st) == 0) {
        printf("Text model saved successfully to %s (%.2f KB)\n", 
               filename, st.st_size / 1024.0);
    }
    
    return 0;
}
