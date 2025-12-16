# Makefile for HDC Classification
# Date: 28 November 2025
# Dataset-agnostic: dataset paths are specified in the source code

# Compiler settings
CC = gcc
CXX = g++
CFLAGS = -Wall -Wextra -O2 -I. -I../inc
CXXFLAGS = -Wall -Wextra -O2 -I. -I../inc -std=c++11
LDFLAGS = -lm

# Directories
SRC_DIR = .
OBJ_DIR = obj
BIN_DIR = bin

# Source files
LOADER_SOURCES = test_dataset_loader.c dataset_loader.c
LOADER_OBJECTS = $(LOADER_SOURCES:%.c=$(OBJ_DIR)/%.o)

PREPROC_SOURCES = test_preprocessing.c dataset_loader.c hdc_preprocessing.c
PREPROC_OBJECTS = $(PREPROC_SOURCES:%.c=$(OBJ_DIR)/%.o)

# Training program (C++)
TRAINING_CPP_SOURCES = training.cpp model_io.cpp
TRAINING_C_SOURCES = dataset_loader.c hdc_preprocessing.c
TRAINING_HDC_SOURCES = ../src/hdc_class.cpp ../src/hv_struct.cpp
TRAINING_OBJECTS = $(TRAINING_CPP_SOURCES:%.cpp=$(OBJ_DIR)/%.o) \
                   $(TRAINING_C_SOURCES:%.c=$(OBJ_DIR)/train_%.o) \
                   $(patsubst ../src/%.cpp,$(OBJ_DIR)/%.o,$(TRAINING_HDC_SOURCES))

# Inference program (C++)
INFERENCE_CPP_SOURCES = inference.cpp model_io.cpp
INFERENCE_C_SOURCES = dataset_loader.c hdc_preprocessing.c
INFERENCE_HDC_SOURCES = ../src/hdc_class.cpp ../src/hv_struct.cpp
INFERENCE_OBJECTS = $(INFERENCE_CPP_SOURCES:%.cpp=$(OBJ_DIR)/%.o) \
                    $(INFERENCE_C_SOURCES:%.c=$(OBJ_DIR)/infer_%.o) \
                    $(patsubst ../src/%.cpp,$(OBJ_DIR)/%.o,$(INFERENCE_HDC_SOURCES))

# Target executables
TARGET_LOADER = $(BIN_DIR)/test_dataset_loader
TARGET_PREPROC = $(BIN_DIR)/test_preprocessing
TARGET_TRAINING = $(BIN_DIR)/training
TARGET_INFERENCE = $(BIN_DIR)/inference

# All targets
TARGETS = $(TARGET_LOADER) $(TARGET_PREPROC) $(TARGET_TRAINING) $(TARGET_INFERENCE)

# Default target
all: $(TARGETS)

# Create directories if they don't exist
$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Compile C source files to object files
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Compile C++ source files to object files
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile HDC library C++ files
$(OBJ_DIR)/%.o: ../src/%.cpp | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile training C sources with different prefix to avoid conflicts
$(OBJ_DIR)/train_%.o: $(SRC_DIR)/%.c | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Compile inference C sources with different prefix to avoid conflicts
$(OBJ_DIR)/infer_%.o: $(SRC_DIR)/%.c | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Link object files to create executables
$(TARGET_LOADER): $(LOADER_OBJECTS) | $(BIN_DIR)
	$(CC) $(LOADER_OBJECTS) -o $(TARGET_LOADER) $(LDFLAGS)
	@echo "Build complete: $(TARGET_LOADER)"

$(TARGET_PREPROC): $(PREPROC_OBJECTS) | $(BIN_DIR)
	$(CC) $(PREPROC_OBJECTS) -o $(TARGET_PREPROC) $(LDFLAGS)
	@echo "Build complete: $(TARGET_PREPROC)"

$(TARGET_TRAINING): $(TRAINING_OBJECTS) | $(BIN_DIR)
	$(CXX) $(TRAINING_OBJECTS) -o $(TARGET_TRAINING) $(LDFLAGS)
	@echo "Build complete: $(TARGET_TRAINING)"

$(TARGET_INFERENCE): $(INFERENCE_OBJECTS) | $(BIN_DIR)
	$(CXX) $(INFERENCE_OBJECTS) -o $(TARGET_INFERENCE) $(LDFLAGS)
	@echo "Build complete: $(TARGET_INFERENCE)"

# Run the dataset loader test with training data
run-loader-train: $(TARGET_LOADER)
	@if [ -f Dataset/isolet/isolet1+2+3+4.data ]; then \
		$(TARGET_LOADER) Dataset/isolet/isolet1+2+3+4.data; \
	else \
		echo "Error: Dataset file not found. Please decompress isolet1+2+3+4.data.Z first."; \
		echo "Run: uncompress Dataset/isolet/isolet1+2+3+4.data.Z"; \
	fi

# Run the dataset loader test with test data
run-loader-test: $(TARGET_LOADER)
	@if [ -f Dataset/isolet/isolet5.data ]; then \
		$(TARGET_LOADER) Dataset/isolet/isolet5.data; \
	else \
		echo "Error: Dataset file not found. Please decompress isolet5.data.Z first."; \
		echo "Run: uncompress Dataset/isolet/isolet5.data.Z"; \
	fi

# Run the preprocessing test with training data
run-preproc-train: $(TARGET_PREPROC)
	@if [ -f Dataset/isolet/isolet1+2+3+4.data ]; then \
		$(TARGET_PREPROC) Dataset/isolet/isolet1+2+3+4.data; \
	else \
		echo "Error: Dataset file not found. Please decompress isolet1+2+3+4.data.Z first."; \
		echo "Run: uncompress Dataset/isolet/isolet1+2+3+4.data.Z"; \
	fi

# Run the preprocessing test with test data
run-preproc-test: $(TARGET_PREPROC)
	@if [ -f Dataset/isolet/isolet5.data ]; then \
		$(TARGET_PREPROC) Dataset/isolet/isolet5.data; \
	else \
		echo "Error: Dataset file not found. Please decompress isolet5.data.Z first."; \
		echo "Run: uncompress Dataset/isolet/isolet5.data.Z"; \
	fi

# Run HDC training
# Usage: make training DATASET=path/to/dataset.csv [ACCL=1]
# The DATASET parameter is REQUIRED
# Examples:
#   make training DATASET=Dataset/iris/train.csv             # CPU mode
#   make training DATASET=Dataset/iris/train.csv ACCL=1      # Hardware accelerated
training: $(TARGET_TRAINING)
	@if [ -z "$(DATASET)" ]; then \
		echo "Error: DATASET parameter is required"; \
		echo "Usage: make training DATASET=path/to/dataset.csv [ACCL=1]"; \
		echo "Example: make training DATASET=Dataset/iris/train.csv"; \
		exit 1; \
	fi
	@if [ "$(ACCL)" = "1" ]; then \
		echo "Running HDC training on $(DATASET) (hardware accelerated)..."; \
		sudo $(TARGET_TRAINING) $(DATASET) -accl; \
	else \
		echo "Running HDC training on $(DATASET) (CPU mode)..."; \
		$(TARGET_TRAINING) $(DATASET); \
	fi

# Run HDC inference
# Usage: make inference DATASET=path/to/test_dataset.csv [ACCL=1]
# The DATASET parameter is REQUIRED
# Examples:
#   make inference DATASET=Dataset/iris/test.csv             # CPU mode
#   make inference DATASET=Dataset/iris/test.csv ACCL=1      # Hardware accelerated
inference: $(TARGET_INFERENCE)
	@if [ -z "$(DATASET)" ]; then \
		echo "Error: DATASET parameter is required"; \
		echo "Usage: make inference DATASET=path/to/test_dataset.csv [ACCL=1]"; \
		echo "Example: make inference DATASET=Dataset/iris/test.csv"; \
		exit 1; \
	fi
	@if [ "$(ACCL)" = "1" ]; then \
		echo "Running HDC inference on $(DATASET) (hardware accelerated)..."; \
		sudo $(TARGET_INFERENCE) $(DATASET) -accl; \
	else \
		echo "Running HDC inference on $(DATASET) (CPU mode)..."; \
		$(TARGET_INFERENCE) $(DATASET); \
	fi

# Convenience targets (backward compatibility)
run-train: run-loader-train
run-test: run-loader-test

# Decompress dataset files (if .Z files exist)
decompress:
	@echo "Decompressing ISOLET dataset files..."
	@if [ -f Dataset/isolet/isolet1+2+3+4.data.Z ]; then \
		uncompress Dataset/isolet/isolet1+2+3+4.data.Z && \
		echo "Training data decompressed"; \
	else \
		echo "Training data already decompressed or not found"; \
	fi
	@if [ -f Dataset/isolet/isolet5.data.Z ]; then \
		uncompress Dataset/isolet/isolet5.data.Z && \
		echo "Test data decompressed"; \
	else \
		echo "Test data already decompressed or not found"; \
	fi

# Clean build artifacts
clean:
	rm -rf $(OBJ_DIR) $(BIN_DIR)
	@echo "Cleaned build artifacts"

# Clean and rebuild
rebuild: clean all

# Help message
help:
	@echo "HDC Classification - Makefile Help"
	@echo "==================================="
	@echo ""
	@echo "Build targets:"
	@echo "  make                    - Build all programs"
	@echo "  make all                - Same as 'make'"
	@echo "  make clean              - Remove build artifacts"
	@echo "  make rebuild            - Clean and rebuild"
	@echo ""
	@echo "HDC Training and Inference:"
	@echo "  make training DATASET=<file.csv>                - Train HDC model (CPU mode, DATASET required)"
	@echo "  make training DATASET=<file.csv> ACCL=1         - Train with hardware acceleration"
	@echo "  make inference DATASET=<file.csv>               - Run inference (CPU mode, DATASET required)"
	@echo "  make inference DATASET=<file.csv> ACCL=1        - Inference with hardware acceleration"
	@echo ""
	@echo "  Note: DATASET parameter is mandatory for both training and inference"
	@echo ""
	@echo "Built executables:"
	@echo "  ./bin/test_dataset_loader  - Dataset loading test"
	@echo "  ./bin/test_preprocessing   - Preprocessing and quantization test"
	@echo "  ./bin/training             - HDC training program (hardware accelerated)"
	@echo "  ./bin/inference            - HDC inference program (hardware accelerated)"
	@echo ""
	@echo "Complete workflow:"
	@echo "  1. make                    # Build all programs"
	@echo "  2. make training           # Train HDC model"
	@echo "  3. make inference          # Test model"

# Phony targets
.PHONY: all clean rebuild decompress help
.PHONY: run-train run-test run-loader-train run-loader-test run-preproc-train run-preproc-test
.PHONY: training inference
