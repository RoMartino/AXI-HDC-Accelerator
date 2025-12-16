// ============================================================================
// CORRECTED VERSION - hdc_class.cpp quantization functions
// ============================================================================
// Replace lines 172-192 in src/hdc_class.cpp with this corrected code
// ============================================================================

/**
 * Generate quantization levels for feature encoding
 * 
 * Creates (levels + 2) quantization thresholds evenly spaced between min and max
 * This matches the Python implementation for compatibility
 * 
 * @param min Minimum feature value (typically 0.0)
 * @param max Maximum feature value (typically 1.0)
 * @param LevelList Output array of size [HD_LV_LEN + 2]
 */
void generate_quantization_levels(float min, float max, float* LevelList) {
    double length = max - min;
    double gap = length / (HD_LV_LEN + 1);  // FIXED: divide by (HD_LV_LEN + 1)
    
    // Generate HD_LV_LEN + 2 levels
    for (int level = 0; level < HD_LV_LEN + 2; ++level) {
        LevelList[level] = min + level * gap;
    }
    
    #ifdef DEBUG_QUANTIZATION
    printf("Quantization levels generated:\n");
    printf("  Min: %.6f, Max: %.6f, Gap: %.6f\n", min, max, gap);
    printf("  Total levels: %d\n", HD_LV_LEN + 2);
    printf("  First 5: ");
    for (int i = 0; i < 5 && i < HD_LV_LEN + 2; i++) {
        printf("%.4f ", LevelList[i]);
    }
    printf("\n  Last 5: ");
    for (int i = (HD_LV_LEN + 2 > 5 ? HD_LV_LEN - 3 : 0); i < HD_LV_LEN + 2; i++) {
        printf("%.4f ", LevelList[i]);
    }
    printf("\n");
    #endif
}

/**
 * Get quantized level for a single feature value
 * 
 * Determines which quantization level a value belongs to by comparing
 * against the quantization thresholds. Matches Python implementation.
 * 
 * @param value The feature value to quantize (typically in [0, 1])
 * @param quantization_levels Array of quantization thresholds [size: HD_LV_LEN + 2]
 * @return Quantized level index (0 to HD_LV_LEN - 1)
 */
int get_quantized_level(float value, float quantization_levels[HD_LV_LEN + 2]) {
    // First check: is value at or below minimum threshold?
    if (value <= quantization_levels[0]) {
        return 0;
    }
    
    // Compare value against each level threshold
    // We iterate HD_LV_LEN + 1 times to check all boundaries
    for (int i = 1; i <= HD_LV_LEN; ++i) {
        if (value <= quantization_levels[i]) {
            return i - 1;  // Return the level before this threshold
        }
    }
    
    // If value is above all thresholds, return highest level
    return HD_LV_LEN - 1;
}

// ============================================================================
// USAGE EXAMPLE in training.cpp:
// ============================================================================
// 
// OLD (WRONG):
//     float quantization_levels[HD_LV_LEN];
//     generate_quantization_levels(0.0, 1.0, quantization_levels);
//
// NEW (CORRECT):
//     float quantization_levels[HD_LV_LEN + 2];
//     generate_quantization_levels(0.0, 1.0, quantization_levels);
//
// ============================================================================
