#ifndef MAATAA_HAL_HPP
#define MAATAA_HAL_HPP

#include <cstdint>
#include <cstddef>
#include <memory>
#include <system_error>

namespace maataa::hal {

// Siddham Edge NPU Register Offsets (MMIO)
constexpr uintptr_t NPU_BASE_ADDR        = 0xA0000000;
constexpr size_t    NPU_REG_MAP_SIZE     = 0x00010000; // 64 KB

constexpr uint32_t  REG_CONTROL          = 0x00; // Bit 0: Start, Bit 1: Reset, Bit 2: Interrupt Enable
constexpr uint32_t  REG_STATUS           = 0x04; // Bit 0: Idle, Bit 1: Done, Bit 2: Error
constexpr uint32_t  REG_SRC_ADDR_LOW     = 0x08;
constexpr uint32_t  REG_SRC_ADDR_HIGH    = 0x0C;
constexpr uint32_t  REG_DEST_ADDR_LOW    = 0x10;
constexpr uint32_t  REG_DEST_ADDR_HIGH   = 0x14;
constexpr uint32_t  REG_VECTOR_LEN       = 0x18;
constexpr uint32_t  REG_CYCLE_COUNT      = 0x1C;

// Control Register Flags
constexpr uint32_t  CTRL_START_MASK      = 0x01;
constexpr uint32_t  CTRL_RESET_MASK      = 0x02;
constexpr uint32_t  CTRL_IRQ_EN_MASK     = 0x04;

// Status Register Flags
constexpr uint32_t  STAT_IDLE_MASK       = 0x01;
constexpr uint32_t  STAT_DONE_MASK       = 0x02;
constexpr uint32_t  STAT_ERROR_MASK      = 0x04;

struct HardwareStats {
    uint32_t execution_cycles;
    float    latency_ms;
    bool     error_flag;
};

enum class HalError {
    Success = 0,
    MmapFailed,
    HardwareTimeout,
    InvalidBuffer,
    DeviceBusy
};

class SiddhamNpuDevice {
public:
    explicit SiddhamNpuDevice(uintptr_t base_addr = NPU_BASE_ADDR);
    ~SiddhamNpuDevice();

    HalError initialize();
    HalError reset();
    HalError dispatch_vector_execution(
        const float* input_vec, 
        float* output_vec, 
        size_t dimension, 
        HardwareStats& stats
    );

private:
    uintptr_t base_address_;
    int       mem_fd_;
    volatile uint32_t* reg_map_;
    bool      initialized_;

    void write_reg(uint32_t offset, uint32_t val) volatile;
    uint32_t read_reg(uint32_t offset) volatile;
    HalError wait_for_completion(uint32_t timeout_ms);
};

} // namespace maataa::hal

#endif // MAATAA_HAL_HPP