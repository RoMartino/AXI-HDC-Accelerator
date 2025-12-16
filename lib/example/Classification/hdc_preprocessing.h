#ifndef HDC_PREPROCESSING_H
#define HDC_PREPROCESSING_H

#include <stdint.h>

/**
 * Normalize a value from [-1, 1] range to [0, 1] range
 * 
 * @param value Input value (typically between -1 and 1)
 * @return Normalized value between 0 and 1
 */
float normalize_to_unit_range(float value);

/**
 * Quantize a normalized value to discrete levels
 * 
 * @param normalized_value Value in [0, 1] range
 * @param num_levels Number of quantization levels (e.g., 10)
 * @return Quantized level (0 to num_levels-1)
 */
uint32_t quantize_value(float normalized_value, int num_levels);

/**
 * Quantize an entire feature vector
 * 
 * @param features Input feature array
 * @param num_features Number of features
 * @param num_levels Number of quantization levels
 * @param quantized_output Output array for quantized values
 */
void quantize_feature_vector(const float *features, int num_features, 
                             int num_levels, uint32_t *quantized_output);

/**
 * Print quantized feature vector (for debugging)
 * 
 * @param quantized Quantized feature array
 * @param num_features Number of features
 * @param max_print Maximum number of features to print (0 = print all)
 */
void print_quantized_features(const uint32_t *quantized, int num_features, int max_print);

#endif // HDC_PREPROCESSING_H
