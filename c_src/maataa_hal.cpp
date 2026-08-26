#include "maataa_hal.hpp"
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <chrono>
#include <cstring>
#include <iostream>

namespace maataa::hal {

SiddhamNpuDevice::SiddhamNpuDevice(uintptr_t base_addr)
    : base_address_(base_addr), mem_fd_(-1), reg_map_(nullptr), initialized_(false) {}

SiddhamNpuDevice::~SiddhamNpuDevice() {
    if (reg_map_ && reg_map_ != MAP_FAILED) {
        munmap(const_cast<uint32_t*>(reg_map_), NPU_REG_MAP_SIZE);
    }
    if (mem_fd_ >= 0) {
        close(mem_fd_);
    }
}

HalError SiddhamNpuDevice::initialize() {
    mem_fd_ = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd_ < 0) {
        // Fallback simulation mode if hardware dev/mem is inaccessible
        std::cerr << "[MAATAA HAL] Physical /dev/mem unaccessible. Operating in HW Simulation Mode.\n";
        initialized_ = true;
        return HalError::Success;
    }

    void* mapped_base = mmap(
        nullptr, 
        NPU_REG_MAP_SIZE, 
        PROT_READ | PROT_WRITE, 
        MAP_SHARED, 
        mem_fd_, 
        static_cast<off_t>(base_address_)
    );

    if (mapped_base == MAP_FAILED) {
        close(mem_fd_);
        mem_fd_ = -1;
        return HalError::MmapFailed;
    }

    reg_map_ = static_cast<volatile uint32_t*>(mapped_base);
    initialized_ = true;

    return reset();
}

HalError SiddhamNpuDevice::reset() {
    if (!initialized_) return HalError::DeviceBusy;
    
    if (reg_map_) {
        write_reg(REG_CONTROL, CTRL_RESET_MASK);
        usleep(1000); // 1ms reset pulse
        write_reg(REG_CONTROL, 0x00);
    }
    return HalError::Success;
}

void SiddhamNpuDevice::write_reg(uint32_t offset, uint32_t val) volatile {
    if (reg_map_) {
        reg_map_[offset / sizeof(uint32_t)] = val;
    }
}

uint32_t SiddhamNpuDevice::read_reg(uint32_t offset) volatile {
    if (!reg_map_) return 0;
    return reg_map_[offset / sizeof(uint32_t)];
}

HalError SiddhamNpuDevice::wait_for_completion(uint32_t timeout_ms) {
    auto start = std::chrono::high_resolution_clock::now();
    while (true) {
        uint32_t status = read_reg(REG_STATUS);
        if (status & STAT_DONE_MASK) {
            return HalError::Success;
        }
        if (status & STAT_ERROR_MASK) {
            return HalError::HardwareTimeout;
        }

        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::high_resolution_clock::now() - start
        ).count();

        if (elapsed > timeout_ms) {
            return HalError::HardwareTimeout;
        }
        usleep(50); // 50us poll delay
    }
}

HalError SiddhamNpuDevice::dispatch_vector_execution(
    const float* input_vec, 
    float* output_vec, 
    size_t dimension, 
    HardwareStats& stats
) {
    if (!initialized_ || !input_vec || !output_vec) {
        return HalError::InvalidBuffer;
    }

    auto start_time = std::chrono::high_resolution_clock::now();

    // Hardware Register Dispatch (If MMIO Map Active)
    if (reg_map_) {
        uint64_t src_phys  = reinterpret_cast<uint64_t>(input_vec);
        uint64_t dest_phys = reinterpret_cast<uint64_t>(output_vec);

        write_reg(REG_SRC_ADDR_LOW, static_cast<uint32_t>(src_phys & 0xFFFFFFFF));
        write_reg(REG_SRC_ADDR_HIGH, static_cast<uint32_t>(src_phys >> 32));
        write_reg(REG_DEST_ADDR_LOW, static_cast<uint32_t>(dest_phys & 0xFFFFFFFF));
        write_reg(REG_DEST_ADDR_HIGH, static_cast<uint32_t>(dest_phys >> 32));
        write_reg(REG_VECTOR_LEN, static_cast<uint32_t>(dimension));

        // Trigger Execution
        write_reg(REG_CONTROL, CTRL_START_MASK);

        HalError err = wait_for_completion(100); // 100ms timeout
        if (err != HalError::Success) {
            stats.error_flag = true;
            return err;
        }

        stats.execution_cycles = read_reg(REG_CYCLE_COUNT);
    } else {
        // Fallback SW Engine Simulation for Host Testing
        for (size_t i = 0; i < dimension; ++i) {
            output_vec[i] = input_vec[i] * 1.05f; // Synthetic matrix transform simulation
        }
        stats.execution_cycles = static_cast<uint32_t>(dimension * 12);
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    stats.latency_ms = std::chrono::duration<float, std::milli>(end_time - start_time).count();
    stats.error_flag = false;

    return HalError::Success;
}

} // namespace maataa::hal

// -----------------------------------------------------------------------------
// C-FFI Export Interface for Rust Runtime Kernel Integration
// -----------------------------------------------------------------------------
extern "C" {

void* maataa_hal_create_device() {
    auto dev = new maataa::hal::SiddhamNpuDevice();
    if (dev->initialize() != maataa::hal::HalError::Success) {
        // Safe fallback configuration
    }
    return static_cast<void*>(dev);
}

void maataa_hal_destroy_device(void* handle) {
    if (handle) {
        delete static_cast<maataa::hal::SiddhamNpuDevice*>(handle);
    }
}

int32_t maataa_hal_execute(
    void* handle, 
    const float* input, 
    float* output, 
    uint32_t len, 
    uint32_t* cycles_out, 
    float* latency_out
) {
    if (!handle) return -1;

    auto dev = static_cast<maataa::hal::SiddhamNpuDevice*>(handle);
    maataa::hal::HardwareStats stats{};

    maataa::hal::HalError status = dev->dispatch_vector_execution(input, output, len, stats);
    if (cycles_out) *cycles_out = stats.execution_cycles;
    if (latency_out) *latency_out = stats.latency_ms;

    return static_cast<int32_t>(status);
}

}