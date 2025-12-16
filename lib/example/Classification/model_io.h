#ifndef MODEL_IO_H
#define MODEL_IO_H

#include <stdint.h>
#include "../inc/hv_struct.hpp"

#ifdef __cplusplus
extern "C" {
#endif

// Magic number for model file validation
#define MODEL_MAGIC 0x48444321  // "HDC!"

/**
 * Model file header structure
 * Contains metadata about the trained HDC model
 */
typedef struct {
    uint32_t magic_number;      // Magic number for file validation (0x48444321 = "HDC!")
    uint32_t hv_size_bit;       // Hypervector size in bits
    uint32_t num_features;      // Number of input features
    uint32_t num_levels;        // Number of quantization levels
    uint32_t num_classes;       // Number of output classes
    uint32_t timestamp;         // Training timestamp (Unix epoch)
} ModelHeader;

/**
 * Save a trained HDC model to a binary file
 * 
 * @param filename Output file path
 * @param base_vectors Array of base vectors (one per feature)
 * @param level_vectors Array of level vectors (for quantization)
 * @param class_vectors Array of class vectors (associative memory)
 * @param num_features Number of features in the model
 * @param num_levels Number of quantization levels
 * @param num_classes Number of classes
 * @return 0 on success, -1 on error
 */
int save_model(const char *filename, 
               HV *base_vectors, 
               HV *level_vectors, 
               HV *class_vectors,
               int num_features,
               int num_levels,
               int num_classes);

/**
 * Load a trained HDC model from a binary file
 * 
 * @param filename Input file path
 * @param base_vectors Array to store base vectors (must be pre-allocated)
 * @param level_vectors Array to store level vectors (must be pre-allocated)
 * @param class_vectors Array to store class vectors (must be pre-allocated)
 * @param expected_features Expected number of features (for validation)
 * @param expected_levels Expected number of levels (for validation)
 * @param expected_classes Expected number of classes (for validation)
 * @return 0 on success, -1 on error
 */
int load_model(const char *filename,
               HV *base_vectors,
               HV *level_vectors,
               HV *class_vectors,
               int expected_features,
               int expected_levels,
               int expected_classes);

/**
 * Save a trained HDC model to a text file (human-readable format)
 * 
 * @param filename Output text file path
 * @param base_vectors Array of base vectors (one per feature)
 * @param level_vectors Array of level vectors (for quantization)
 * @param class_vectors Array of class vectors (associative memory)
 * @param num_features Number of features in the model
 * @param num_levels Number of quantization levels
 * @param num_classes Number of classes
 * @return 0 on success, -1 on error
 */
int save_model_txt(const char *filename, 
                   HV *base_vectors, 
                   HV *level_vectors, 
                   HV *class_vectors,
                   int num_features,
                   int num_levels,
                   int num_classes);

#ifdef __cplusplus
}
#endif

#endif // MODEL_IO_H
