#ifndef HDC_OP_HPP
#define HDC_OP_HPP

#include <cstdint>
#include <cstdlib>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

#include "config.hpp"
#include "hv_struct.hpp"

///--------------------------- Auxiliary Functions: --------------------------- 
void generate_quantization_levels(float min, float max, float LevelList[HD_LV_LEN + 2]);
int  get_quantized_level(float value, float quantization_levels[HD_LV_LEN + 2]);
void press_enter_to_continue();
// --------------------------- HDC Class: ------------------------------------- 
class HDC_op {

    private:
        // Hardware Memory Mapping
        int mem_fd;
        void *dma_base;
        void *gpio_base;
        void *dma_src_buffer;
        void *dma_dst_buffer;
        void *hdc_base;
        
        // Hardware initialization method
        bool initialize_hardware();
        void reset_hardware();
        void cleanup_hardware();

    public:

        int HV_SIZE;           // HV size
        int HV_type;           // HV type: binary or bipolar
        int num_levels;        // Number of levels used in the model
        int num_features;      // Number of features used in the model
        int lv_technique;      // Level vector technique: 0: linear, 1: approximately linear, 2: thermometer encoding
        int density;           // Density of the HV (dense or sparse)
        float sparsity_factor; // Sparsity factor of the HV (used only for sparse HVs)
        int HV_similarity;     // HV similarity: 0: Hamming distance, 1: Cosine similarity
        int quant_min;
        int quant_max;
        int base_value;        // Base value of the HV (used only for bipolar HVs)

        // ===================================================
        // Constructor
        // ===================================================
        HDC_op(int dimensionality, int features, int levels);
        
        // ===================================================
        // Destructor
        // ===================================================
        ~HDC_op();

        // ===================================================
        // Hardware Access Methods
        // ===================================================
        void* get_dma_base() const { return dma_base; }
        void* get_gpio_base() const { return gpio_base; }
        void* get_dma_src_buffer() const { return dma_src_buffer; }
        void* get_dma_dst_buffer() const { return dma_dst_buffer; }
        void* get_hdc_base() const { return hdc_base; }
        bool is_hardware_initialized() const { return (mem_fd >= 0); }

        // ===================================================
        // Hardware Utility Methods
        // ===================================================
        void dma_s2mm_status();
        void dma_mm2s_status();
        int dma_mm2s_sync();
        int dma_s2mm_sync();
        void hdc_status();
        void read_fifo_in_flags(const char *label);
        void read_fifo_out_flags(const char *label);

        uint32_t get_fifo_status(const char *label = NULL); 
        uint64_t time_ns_monotonic();

        // ===================================================
        // Performance Counter Methods
        // ===================================================
        uint32_t get_bundle_cycles();
        uint32_t get_bind_cycles();
        uint32_t get_sim_cycles();
        uint32_t get_clip_cycles();
        uint32_t get_perm_cycles();
        uint32_t get_as_cycles();
        double get_execution_time_ns(uint32_t cycles);

        // ===================================================
        // HV Generation
        // ===================================================
        void generate_BaseVectors(HV(&baseVectors)[DS_FEATURE_SIZE]);
        void generate_LevelVectors(HV(&LevelVectors)[HD_LV_LEN]);
        void generate_random_feature_vectors(float* feature_vector);

        // ===================================================
        // HDC Operations using Software
        // ===================================================
        uint32_t similarity(const HV(&HV1), const HV(&HV2));
        uint8_t search(HV query, HV (&ClassVectors)[HD_CV_LEN]);
        HV bind(const HV (&HV1), const HV(&HV2));
        HV permutation(HV hv, int shift);
        BundledHV bundle(const BundledHV (&HV1), const HV (&HV2)) const;
        HV clip(const BundledHV (&bundled_hv), int HV_BUNDLED);

        // ===================================================
        // HDC Composite Operations using Software
        // ===================================================
        HV encoding(uint32_t* quantized_features, HV (&BaseVectors)[DS_FEATURE_SIZE], HV (&LevelVectors)[HD_LV_LEN]);
        BundledHV training(uint32_t quantized_features[DS_FEATURE_SIZE], HV (&BaseVectors)[DS_FEATURE_SIZE], HV (&LevelVectors)[HD_LV_LEN], BundledHV (&ClassVectors)[HD_CV_LEN], int class_label);
        uint32_t inference(uint32_t quantized_features[DS_FEATURE_SIZE], HV (&BaseVectors)[DS_FEATURE_SIZE], HV (&LevelVectors)[HD_LV_LEN], HV (&AssociativeMemory)[HD_CV_LEN]);
        
        // ===================================================
        // HDC Operations using Hardware Accelerator
        // ===================================================
        void hvmemld(uint32_t spm_addr, uint32_t* hv_ptr, size_t size);
        void hvmemstr(uint32_t* hv_ptr,uint32_t spm_addr, size_t size);
        void hvbind(uint32_t rd, uint32_t rs1, uint32_t rs2);
        void hvperm(uint32_t rd, uint32_t hv, uint32_t shift);
        void hvbundle(uint32_t rd, uint32_t hv1, uint32_t hv2);
        void hvclip(uint32_t rd, uint32_t rs1, uint32_t HV_BUNDLED);
        void hvsearch(uint32_t rd, uint32_t rs1, uint32_t rs2);
        void hvsim(uint32_t result, uint32_t hv1, uint32_t hv2);
        bool hvcompare(uint32_t *hv1, uint32_t *hv2, size_t size);
     
        // ===================================================
        // HDC Composite Operations using Hardware Accelerator
        // ===================================================
        void accl_encoding(uint32_t quantized_features[DS_FEATURE_SIZE], uint32_t bv_start_addr, uint32_t lv_start_addr);
        void accl_training(uint32_t quantized_features[DS_FEATURE_SIZE], uint32_t bv_start_addr, uint32_t lv_start_addr, uint32_t associativeMemory_start_addr, int class_label);
        void accl_inference(uint32_t quantized_features[DS_FEATURE_SIZE], uint32_t bv_start_addr, uint32_t lv_start_addr, uint32_t associativeMemory_start_addr);
};

#endif // HDC_OP_HPP


