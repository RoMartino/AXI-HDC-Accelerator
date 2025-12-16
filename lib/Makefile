# Compiler and flags
CXX = g++
CXXFLAGS = -Wall -Wextra -std=c++11 -O2
DEBUGFLAGS = -g -DDEBUG
INCLUDES = -Iinc/
LIBS = 

# Directories
SRC_DIR = src
INC_DIR = inc
TEST_DIR = test
BUILD_DIR = build
BIN_DIR = bin

# Source files
SOURCES = $(wildcard $(SRC_DIR)/*.cpp)
OBJECTS = $(SOURCES:$(SRC_DIR)/%.cpp=$(BUILD_DIR)/%.o)

# Test source files
TEST_SOURCES = $(wildcard $(TEST_DIR)/*.cpp)
TEST_OBJECTS = $(TEST_SOURCES:$(TEST_DIR)/%.cpp=$(BUILD_DIR)/%.o)
TEST_TARGETS = $(TEST_SOURCES:$(TEST_DIR)/%.cpp=$(BIN_DIR)/%)

# Header files (for dependency tracking)
HEADERS = $(wildcard $(INC_DIR)/*.hpp)

# Main library target
LIB_TARGET = $(BUILD_DIR)/libhdc.a

# Default target
.PHONY: all clean debug test help install

all: $(LIB_TARGET) $(TEST_TARGETS)
	@echo "✓ Build complete"

# Create directories if they don't exist
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BIN_DIR):
	@mkdir -p $(BIN_DIR)

# Compile source files to objects
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp $(HEADERS) | $(BUILD_DIR)
	@echo "  CC  $<"
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -MM -MT $@ -c $< > $(@:.o=.d)
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# Compile test files to objects
$(BUILD_DIR)/%.o: $(TEST_DIR)/%.cpp $(HEADERS) | $(BUILD_DIR)
	@echo "  CC  $<"
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -MM -MT $@ -c $< > $(@:.o=.d)
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# Create static library
$(LIB_TARGET): $(OBJECTS) | $(BUILD_DIR)
	@echo "  AR  $@"
	@ar rcs $@ $^

# Build test executables
$(BIN_DIR)/%: $(BUILD_DIR)/%.o $(LIB_TARGET) | $(BIN_DIR)
	@echo "  LD  $@"
	@$(CXX) $(CXXFLAGS) $< -L$(BUILD_DIR) -lhdc $(LIBS) -o $@

# Debug build
debug: CXXFLAGS += $(DEBUGFLAGS)
debug: clean all
	@echo "✓ Debug build complete"

# Build and run tests
test: $(TEST_TARGETS)
	@echo "Running tests..."
	@for test in $(TEST_TARGETS); do \
		echo "  RUN $$test"; \
		sudo $$test || echo "✗ Test failed: $$test"; \
	done

# Individual test targets
.PHONY: test-bind test-bundle test-spm test-perm test-sim test-search test-clip test-encoding test-training test-inference test-hdc

test-bind: $(BIN_DIR)/HDC_Binding_Test
	@echo "Running HDC Binding Test..."
	@sudo $(BIN_DIR)/HDC_Binding_Test

test-bundle: $(BIN_DIR)/HDC_Bundling_Test
	@echo "Running HDC Bundling Test..."
	@sudo $(BIN_DIR)/HDC_Bundling_Test

test-perm: $(BIN_DIR)/HDC_Permutation_Test
	@echo "Running HDC Permutation Test..."
	@sudo $(BIN_DIR)/HDC_Permutation_Test

test-sim: $(BIN_DIR)/HDC_Similarity_Test
	@echo "Running HDC Similarity Test..."
	@sudo $(BIN_DIR)/HDC_Similarity_Test

test-search: $(BIN_DIR)/HDC_Search_Test
	@echo "Running HDC Search Test..."
	@sudo $(BIN_DIR)/HDC_Search_Test

test-clip: $(BIN_DIR)/HDC_Clipping_Test
	@echo "Running HDC Clipping Test..."
	@sudo $(BIN_DIR)/HDC_Clipping_Test

test-encoding: $(BIN_DIR)/HDC_Encoding_Test
	@echo "Running HDC Encoding Test..."
	@sudo $(BIN_DIR)/HDC_Encoding_Test

test-training: $(BIN_DIR)/HDC_Training_Test
	@echo "Running HDC Training Test..."
	@sudo $(BIN_DIR)/HDC_Training_Test

test-inference: $(BIN_DIR)/HDC_Inference_Test
	@echo "Running HDC Inference Test..."
	@sudo $(BIN_DIR)/HDC_Inference_Test

test-spm:
	@$(MAKE) $(BIN_DIR)/$(SPM_TEST)
	@echo "Running SPM Test: $(SPM_TEST)..."
	@sudo $(BIN_DIR)/$(SPM_TEST)

test-hdc: test-bind

# Install targets
install: $(TEST_TARGETS)
	@echo "Installing test executables..."
	@sudo chmod +x $(TEST_TARGETS)
	@echo "✓ Installation complete"

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR) $(BIN_DIR)
	@echo "✓ Clean complete"

# Show project information
info:
	@echo "Project: HDC Hardware Accelerator"
	@echo "Source files: $(SOURCES)"
	@echo "Test files: $(TEST_SOURCES)"
	@echo "Build directory: $(BUILD_DIR)"
	@echo "Binary directory: $(BIN_DIR)"

# Help target
help:
	@echo "HDC Hardware Accelerator - Build targets:"
	@echo "  all                 - Build library and all tests (default)"
	@echo "  debug               - Build with debug flags"
	@echo "  test                - Build and run all tests"
	@echo "  test-bind           - Build and run HDC Binding test"
	@echo "  test-bundle         - Build and run HDC Bundling test"
	@echo "  test-perm           - Build and run HDC Permutation test"
	@echo "  test-sim            - Build and run HDC Similarity test"
	@echo "  test-search         - Build and run HDC Search test"
	@echo "  test-clip           - Build and run HDC Clipping test"
	@echo "  test-encoding       - Build and run HDC Encoding test"
	@echo "  test-training       - Build and run HDC Training test"
	@echo "  test-inference      - Build and run HDC Inference test"
	@echo "  test-spm            - Build and run default SPM test (SPM_TEST=$(SPM_TEST))"
	@echo "  test-spm-1/2/3...   - Esempi di test SPM specifici"
	@echo "     es: make test-spm SPM_TEST=HDC_Load_Store_Test_2"
	@echo "  clean               - Remove build artifacts"
	@echo "  info                - Show project information"

# Dependency tracking
-include $(OBJECTS:.o=.d)
-include $(TEST_OBJECTS:.o=.d)

# Nome del test SPM (senza estensione), usato per i target parametrici
SPM_TEST ?= HDC_Load_Store_Test_1

.PHONY: test-spm-1 test-spm-2 test-spm-3

test-spm-1: SPM_TEST = HDC_Load_Store_Test_1
test-spm-1: test-spm

test-spm-2: SPM_TEST = HDC_Load_Store_Test_2
test-spm-2: test-spm

test-spm-3: SPM_TEST = HDC_Load_Store_Test_3
test-spm-3: test-spm