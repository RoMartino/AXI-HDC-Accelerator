
#include "dataset_loader.h"

static int count_nonempty_lines(FILE *file, int header_lines) {
    int count = 0;
    char line[65536];
    int line_no = 0;
    while (fgets(line, sizeof(line), file)) {
        if (line_no++ < header_lines) continue;
        if (strlen(line) > 1) count++;
    }
    return count;
}

int load_dataset(const char *filename, const DatasetLoadConfig *cfg, Dataset *dataset) {
    if (!filename || !cfg || !dataset || cfg->num_features <= 0) {
        fprintf(stderr, "Error: load_dataset invalid arguments\n");
        return -1;
    }

    FILE *file = fopen(filename, "r");
    if (!file) {
        fprintf(stderr, "Error: Cannot open file %s\n", filename);
        return -1;
    }

    // Determine dataset size
    int num_samples = count_nonempty_lines(file, cfg->header_lines);
    if (num_samples <= 0) {
        fprintf(stderr, "Error: No samples found in %s\n", filename);
        fclose(file);
        return -1;
    }

    // Allocate dataset
    dataset->samples = (DataSample*)calloc((size_t)num_samples, sizeof(DataSample));
    if (!dataset->samples) {
        fprintf(stderr, "Error: Memory allocation failed for samples\n");
        fclose(file);
        return -1;
    }
    dataset->num_samples = num_samples;
    dataset->num_features = cfg->num_features;
    dataset->num_classes = cfg->num_classes;

    // Prepare parsing
    rewind(file);
    char line[65536];
    int line_no = 0;
    int sample_idx = 0;
    const char delim = cfg->delimiter ? cfg->delimiter : ',';

    while (fgets(line, sizeof(line), file) && sample_idx < num_samples) {
        if (line_no++ < cfg->header_lines) continue;
        if (strlen(line) <= 1) continue;

        // Allocate features for this sample
        float *features = (float*)malloc((size_t)cfg->num_features * sizeof(float));
        if (!features) {
            fprintf(stderr, "Error: Memory allocation failed for features (sample %d)\n", sample_idx);
            fclose(file);
            // free partial allocations
            for (int i = 0; i < sample_idx; i++) free(dataset->samples[i].features);
            free(dataset->samples);
            dataset->samples = NULL;
            dataset->num_samples = 0;
            return -1;
        }

        int token_idx = 0;
        int feat_written = 0;
        int label_set = 0;
        int label_col = cfg->label_column;

        // Manual scan over the line buffer
        char *p = line;
        while (*p) {
            // find token bounds
            char *start = p;
            while (*p && *p != delim && *p != '\n' && *p != '\r') p++;
            char saved = *p;
            *p = '\0';

            // Decide where to place this token
            if (label_col >= 0) {
                if (token_idx == label_col) {
                    dataset->samples[sample_idx].label = atoi(start);
                    label_set = 1;
                } else if (feat_written < cfg->num_features) {
                    features[feat_written++] = (float)atof(start);
                }
            } else {
                // label in last column: fill features first, then label
                if (feat_written < cfg->num_features) {
                    features[feat_written++] = (float)atof(start);
                } else {
                    dataset->samples[sample_idx].label = atoi(start);
                    label_set = 1;
                }
            }

            token_idx++;
            if (saved == '\0') break;
            *p = saved;
            if (saved == delim) p++; else if (saved == '\n' || saved == '\r') break; else p++;
        }

        if (feat_written != cfg->num_features) {
            fprintf(stderr, "Warning: Sample %d has %d/%d features\n", sample_idx, feat_written, cfg->num_features);
        }
        if (!label_set) {
            if (label_col >= 0)
                fprintf(stderr, "Warning: Sample %d missing label (expected at column %d)\n", sample_idx, label_col);
            else
                fprintf(stderr, "Warning: Sample %d missing label in last column\n", sample_idx);
            dataset->samples[sample_idx].label = 0;
        }

        dataset->samples[sample_idx].features = features;
        sample_idx++;
    }

    fclose(file);
    if (sample_idx != num_samples) {
        // Adjust if short read
        dataset->num_samples = sample_idx;
    }
    printf("Successfully loaded %d samples (generic)\n", dataset->num_samples);
    return 0;
}

void free_dataset(Dataset *dataset) {
    if (!dataset) return;
    if (dataset->samples) {
        for (int i = 0; i < dataset->num_samples; i++) {
            free(dataset->samples[i].features);
            dataset->samples[i].features = NULL;
        }
        free(dataset->samples);
        dataset->samples = NULL;
    }
    dataset->num_samples = 0;
    dataset->num_features = 0;
    dataset->num_classes = 0;
}

void print_dataset_stats_generic(const Dataset *dataset) {
    if (!dataset || !dataset->samples) {
        printf("Dataset is empty\n");
        return;
    }
    printf("\n=== Dataset Statistics (generic) ===\n");
    printf("Total samples: %d\n", dataset->num_samples);
    printf("Features per sample: %d\n", dataset->num_features);
    if (dataset->num_classes > 0) {
        printf("Number of classes (declared): %d\n", dataset->num_classes);
        // Compute simple histogram if classes are in [0..K] or [1..K]
        int K = dataset->num_classes;
        int *counts0 = (int*)calloc((size_t)K, sizeof(int));
        int *counts1 = (int*)calloc((size_t)K, sizeof(int));
        if (counts0 && counts1) {
            int zero_based_ok = 1, one_based_ok = 1;
            for (int i = 0; i < dataset->num_samples; i++) {
                int y = dataset->samples[i].label;
                if (y >= 0 && y < K) counts0[y]++; else zero_based_ok = 0;
                if (y >= 1 && y <= K) counts1[y-1]++; else one_based_ok = 0;
            }
            if (zero_based_ok) {
                printf("\nSamples per class (0-based):\n");
                for (int c = 0; c < K; c++) {
                    printf("  %2d: %4d\n", c, counts0[c]);
                }
            } else if (one_based_ok) {
                printf("\nSamples per class (1-based):\n");
                for (int c = 0; c < K; c++) {
                    printf("  %2d: %4d\n", c + 1, counts1[c]);
                }
            } else {
                printf("\nLabel distribution (mixed/invalid range):\n");
                printf("  Expected 0-based [0-%d] or 1-based [1-%d]\n", K-1, K);
            }
        }
        free(counts0); free(counts1);
    }
    // Preview
    printf("\nFirst sample preview:\n");
    printf("  Label: %d\n", dataset->samples[0].label);
    printf("  Values : ");
    for (int f = 0; f < dataset->num_features; f++) {
        printf("%.4f ", dataset->samples[0].features[f]);
    }
    printf("\n");
    printf("===============================\n\n");
}

DataSample* get_sample(Dataset *dataset, int index) {
    if (!dataset || !dataset->samples) return NULL;
    if (index < 0 || index >= dataset->num_samples) {
        fprintf(stderr, "Error: Sample index %d out of bounds [0, %d)\n", index, dataset->num_samples);
        return NULL;
    }
    return &dataset->samples[index];
}
