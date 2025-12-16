#ifndef CONFIG_HPP
#define CONFIG_HPP

// HDC Configuration Parameters
#define HV_SIZE_BIT         1024
#define HV_CHUNKS           (HV_SIZE_BIT / 32) 
#define HVSIZE_BYTES        (HV_SIZE_BIT / 8)  
#define COUNTER_BITS        16
#define COUNTER_NUM         (32/COUNTER_BITS)  
#define SIMD                16
#define HVCLASS             26

/* Dataset Parameters*/
#define DS_FEATURE_SIZE 617	    
#define HD_CV_LEN HVCLASS           

// Encoding Parameters
#define HD_LV_LEN 10	
#define N_GRAM_SIZE 3
#define PRINT_LV 0
#define PRINT_BV 0		     

/* Training Parameters*/
#define EPOCHS 1
#define PRINT_TRAINED_MODEL 0
#define TRAINING_DEBUG 0

// Inference Parameters
#define INFERENCE_WITH_ASS_SEARCH  0

/* Debugging and Optimization Flags*/
#define DEBUG 0	   
#define DEBUG_DMA 0   // If set to 1, the program will print the DMA status

// ======================================================
// AXI HDC ACCL REGISTERS
// ======================================================
#define HDC_ACCL_BASE_ADDR  0x40000000
#define HDC_MAP_SIZE        0x100000
// Register Offsets
#define AXI_HVSIZE          0x00
#define AXI_RS1             0x08
#define AXI_RS2             0x0C
#define AXI_RD              0x10
#define AXI_HDC_INSTR       0x14
#define AXI_HVCLASS         0x18
#define AXI_RSIZE           0x20
#define AXI_WSIZE           0x24
#define AXI_INTERRUPT       0x28
#define AXI_TEST_REG        0x7C

// Performance Counter Offsets
#define PERF_BUNDLE_OFFSET  0x34
#define PERF_BIND_OFFSET    0x38
#define PERF_SIM_OFFSET     0x3C
#define PERF_CLIP_OFFSET    0x40
#define PERF_PERM_OFFSET    0x44
#define PERF_AS_OFFSET      0x48

// Clock Frequency (Hz) - Update based on your system
#define FREQUENCY           110000000  
#define CLOCK_PERIOD_NS     (1000000000.0 / FREQUENCY)  // Period in nanoseconds

// HDC Operation Codes
#define HVBIND              0x00000001
#define HVBUNDLE            0x00000002
#define HVCLIP              0x00000004
#define HVPERM              0x00000008
#define HVSIM               0x00000010
#define HVSEARCH            0x00000020
#define HVMEMLD             0x00000040
#define HVMEMSTR            0x00000080
// SPM Memory Map
#define SPM_A_START_ADDR    0x00000000
#define SPM_B_START_ADDR    0x00010000
#define SPM_C_START_ADDR    0x00020000
#define SPM_D_START_ADDR    0x00030000

// ======================================================
// AXI DMA Base configuration (Direct Register Mode)
// ======================================================
#define DMA_BASE_ADDR 0x40400000
#define DMA_MAP_SIZE  0x100000
// ======================================================
// DDR reserved memory for DMA transfers
// ======================================================
// The total reserved DDR memory is 0x20000 (128 MiB)
// start address: 0x30000000. We reserve two buffers of
// 0x10000 (64 MiB) each. These dimensions can be adjusted
// by modifying the device tree during petalinux build.
#define DMA_SRC_BUFFER          0x30000000  
#define DMA_DST_BUFFER          0x34000000
#define DMA_BUFFERS_MAP_SIZE    0x04000000 

// ======================================================
//  DMA Register Offsets, Flags, and Masks
// ======================================================
#define MM2S_CONTROL_REGISTER       0x00
#define MM2S_STATUS_REGISTER        0x04
#define MM2S_SRC_ADDRESS_REGISTER   0x18
#define MM2S_TRNSFR_LENGTH_REGISTER 0x28

#define S2MM_CONTROL_REGISTER       0x30
#define S2MM_STATUS_REGISTER        0x34
#define S2MM_DST_ADDRESS_REGISTER   0x48
#define S2MM_BUFF_LENGTH_REGISTER   0x58

#define IOC_IRQ_FLAG                1<<12
#define IDLE_FLAG                   1<<1

#define STATUS_HALTED               0x00000001
#define STATUS_IDLE                 0x00000002
#define STATUS_SG_INCLDED           0x00000008
#define STATUS_DMA_INTERNAL_ERR     0x00000010
#define STATUS_DMA_SLAVE_ERR        0x00000020
#define STATUS_DMA_DECODE_ERR       0x00000040
#define STATUS_SG_INTERNAL_ERR      0x00000100
#define STATUS_SG_SLAVE_ERR         0x00000200
#define STATUS_SG_DECODE_ERR        0x00000400
#define STATUS_IOC_IRQ              0x00001000
#define STATUS_DELAY_IRQ            0x00002000
#define STATUS_ERR_IRQ              0x00004000

#define HALT_DMA                    0x00000000
#define RUN_DMA                     0x00000001
#define RESET_DMA                   0x00000004
#define ENABLE_IOC_IRQ              0x00001000
#define ENABLE_DELAY_IRQ            0x00002000
#define ENABLE_ERR_IRQ              0x00004000
#define ENABLE_ALL_IRQ              0x00007000

// ======================================================
// FIFO GPIO base 
// ======================================================
#define GPIO_BASE_ADDR 0x41200000  
#define GPIO_MAP_SIZE  0x100000

// ======================================================
// AXI GPIO Offsets and Masks
// ======================================================
#define GPIO_DATA 0x0
#define GPIO_TRI  0x4
#define FIFO_IN_AE_MASK  (0x1 << 0) // Bit 0 FIFO IN Almost Empty
#define FIFO_IN_AF_MASK  (0x1 << 1) // Bit 1 FIFO IN Almost Full
#define FIFO_OUT_AE_MASK (0x1 << 2) // Bit 2 FIFO OUT Almost Empty
#define FIFO_OUT_AF_MASK (0x1 << 3) // Bit 3 FIFO OUT Almost Full
#define DONE_MASK        (0x1 << 4) // Bit 4 of GPIO_DATA
#define LD_STR_BUSY_MASK (0x1 << 5) // Bit 5 of GPIO_DATA

#define GPIO_DATA_2 0x8
#define GPIO_TRI_2  0xC
#define RESET_MASK  (0x1 << 0)  // Bit 0: Active reset signal

// ======================================================
// Helper macros for register access
// ======================================================
#define REG_WRITE(addr, offset, value) \
    do { \
        static_assert(sizeof(value) <= 4, "Value too large for 32-bit register"); \
        *(volatile uint32_t *)((uintptr_t)(addr) + (offset)) = (uint32_t)(value); \
    } while(0)

#define REG_READ(addr, offset) \
    (*(volatile uint32_t *)((uintptr_t)(addr) + (offset)))

#endif // CONFIG_HPP
