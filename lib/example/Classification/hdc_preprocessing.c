#include "hdc_preprocessing.h"
#include <stdio.h>

/**
 * Normalize a value from [-1, 1] range to [0, 1] range
 */
float normalize_to_unit_range(float value) {
    // Convert from [-1, 1] to [0, 1]
    // formula: (value + 1) / 2
    float normalized = (value + 1.0f) / 2.0f;
    
    // Clamp to [0, 1] range to handle any edge cases
    if (normalized < 0.0f) normalized = 0.0f;
    if (normalized > 1.0f) normalized = 1.0f;
    
    return normalized;
}

/**
 * Quantize a normalized value to discrete levels
 */
uint32_t quantize_value(float normalized_value, int num_levels) {
    // Scale to [0, num_levels)
    int level = (int)(normalized_value * num_levels);
    
    // Ensure we don't exceed the maximum level
    if (level >= num_levels) {
        level = num_levels - 1;
    }
    
    // Ensure non-negative
    if (level < 0) {
        level = 0;
    }
    
    return (uint32_t)level;
}

/**
 * Quantize an entire feature vector
 */
void quantize_feature_vector(const float *features, int num_features, 
                             int num_levels, uint32_t *quantized_output) {
    for (int i = 0; i < num_features; i++) {
        // Normalize from [-1, 1] to [0, 1]
        float normalized = normalize_to_unit_range(features[i]);
        
        // Quantize to discrete levels
        quantized_output[i] = quantize_value(normalized, num_levels);
    }
}

/**
 * Print quantized feature vector (for debugging)
 */
void print_quantized_features(const uint32_t *quantized, int num_features, int max_print) {
    int print_count = (max_print > 0 && max_print < num_features) ? max_print : num_features;
    
    printf("Quantized features [showing %d of %d]: ", print_count, num_features);
    for (int i = 0; i < print_count; i++) {
        printf("%u ", quantized[i]);
        if ((i + 1) % 20 == 0 && i < print_count - 1) {
            printf("\n                                        ");
        }
    }
    if (print_count < num_features) {
        printf("...");
    }
    printf("\n");
}
