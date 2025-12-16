#ifndef DATASET_LOADER_H
#define DATASET_LOADER_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Generic sample: dynamic number of features
typedef struct {
    float *features;   // length: Dataset.num_features
    int label;         // dataset-defined (can be 0-based or 1-based)
} DataSample;

// Generic dataset container
typedef struct {
    DataSample *samples;  // length: num_samples
    int num_samples;
    int num_features;     // per-sample feature count
    int num_classes;      // optional (>=0 if known)
} Dataset;

// Configuration for generic CSV/TSV loaders
typedef struct {
    int num_features;      // required: number of feature columns per row
    int num_classes;       // optional: for stats; set <=0 if unknown
    char delimiter;        // e.g., ',' or '\t'; default ',' if 0
    int label_column;      // -1: last column; otherwise 0-based column index for label
    int header_lines;      // number of header lines to skip
    int one_based_labels;  // non-zero if labels in file are 1..K (left as-is)
} DatasetLoadConfig;

/**
 * Load a generic dataset from a delimited text file.
 * Each row must contain exactly num_features feature values and one label
 * (at label_column or the last column if label_column == -1).
 *
 * Memory ownership: the function allocates Dataset.samples and each
 * DataSample.features; caller must free with free_dataset().
 */
int load_dataset(const char *filename, const DatasetLoadConfig *cfg, Dataset *dataset);

/** Free memory allocated by load_dataset */
void free_dataset(Dataset *dataset);

/** Print basic statistics for a generic dataset */
void print_dataset_stats_generic(const Dataset *dataset);

/** Get a specific sample from a generic dataset */
DataSample* get_sample(Dataset *dataset, int index);

#endif // DATASET_LOADER_H
