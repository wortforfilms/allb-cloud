// ============================================================================
// File:        siddham_npu_driver.cpp
// Description: Siddham NPU Driver with explicit Software Register Emulation
// ============================================================================

#include <iostream>
#include <fstream>
#include <fcntl.h>
#include <cstdint>
#include <cstring>
#include <chrono>
#include <thread>

// Explicitly set 1 to force software emulation on macOS / non-Linux targets
#if defined(__APPLE__) || !defined(__linux__)
    #define EMULATION_MODE 1
#else
    #define EMULATION_MODE 0
#endif

#if !EMULATION_MODE
    #include <sys/mman.h>
    #include <unistd.h>
#endif

// Hardware Constants
#define NPU_MMIO_BASE_ADDR   0xA0000000U
#define NPU_MMIO_MAP_SIZE    0x00001000U

// Registers
#define REG_CONTROL          0x00
#define REG_STATUS           0x04
#define REG_WEIGHT_ADDR      0x08
#define REG_ACT_ADDR         0x0C
#define REG_OUT_ADDR         0x10
#define REG_MATRIX_DIM       0x14

#define FPGA_MANAGER_PATH    "/sys/class/fpga_manager/fpga0/firmware"
#define FIRMWARE_DEST_PATH   "/lib/firmware/siddham_npu.bit"

class SiddhamNPUDriver {
private:
    int mem_fd;
    volatile uint32_t* mmio_vaddr;

#if EMULATION_MODE
    uint32_t mock_registers[1024];
#endif

public:
    SiddhamNPUDriver() : mem_fd(-1), mmio_vaddr(nullptr) {
#if EMULATION_MODE
        std::memset((void*)mock_registers, 0, sizeof(mock_registers));
#endif
    }

    ~SiddhamNPUDriver() {
#if !EMULATION_MODE
        if (mmio_vaddr != nullptr) munmap((void*)mmio_vaddr, NPU_MMIO_MAP_SIZE);
        if (mem_fd >= 0) close(mem_fd);
#endif
    }

    bool load_bitstream(const std::string& bitstream_path) {
#if EMULATION_MODE
        std::cout << "[EMULATION] Software Emulation Mode Active." << std::endl;
        std::cout << "[EMULATION] Bypassing FPGA Manager PL programming." << std::endl;
        return true;
#else
        std::cout << "[INFO] Copying bitstream " << bitstream_path << "..." << std::endl;
        std::ifstream src(bitstream_path, std::ios::binary);
        if (!src.is_open()) return false;
        std::ofstream dst(FIRMWARE_DEST_PATH, std::ios::binary);
        if (!dst.is_open()) return false;
        dst << src.rdbuf();
        src.close(); dst.close();
        std::ofstream fpga_mgr(FPGA_MANAGER_PATH);
        if (!fpga_mgr.is_open()) return false;
        fpga_mgr << "siddham_npu.bit";
        return true;
#endif
    }

    bool init_mmio() {
#if EMULATION_MODE
        std::cout << "[EMULATION] Mapping address space (0xA0000000) to local mock memory." << std::endl;
        mmio_vaddr = mock_registers;
        std::cout << "[SUCCESS] Virtual memory mapped at: " << (void*)mmio_vaddr << std::endl;
        return true;
#else
        std::cout << "[INFO] Opening /dev/mem to map MMIO base: 0x" << std::hex << NPU_MMIO_BASE_ADDR << std::dec << "..." << std::endl;
        mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
        if (mem_fd < 0) {
            std::cerr << "[ERROR] Failed to open /dev/mem. Root privileges required." << std::endl;
            return false;
        }
        void* mapped_base = mmap(nullptr, NPU_MMIO_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, NPU_MMIO_BASE_ADDR);
        if (mapped_base == MAP_FAILED) return false;
        mmio_vaddr = static_cast<volatile uint32_t*>(mapped_base);
        return true;
#endif
    }

    void write_reg(uint32_t offset, uint32_t val) {
        mmio_vaddr[offset / 4] = val;

#if EMULATION_MODE
        if (offset == REG_CONTROL && (val & 0x01)) {
            std::thread([this]() {
                std::this_thread::sleep_for(std::chrono::microseconds(50));
                this->mmio_vaddr[REG_STATUS / 4] = 0x00000001; // Latch DONE flag
                this->mmio_vaddr[REG_CONTROL / 4] &= ~0x01;   // Clear START flag
            }).detach();
        }
#endif
    }

    uint32_t read_reg(uint32_t offset) {
        return mmio_vaddr[offset / 4];
    }

    bool execute_vector_operation(uint32_t weight_phys_addr, uint32_t act_phys_addr, uint32_t out_phys_addr, uint32_t matrix_dim) {
        if (!mmio_vaddr) return false;

        std::cout << "\n=================================================" << std::endl;
        std::cout << "  SIDDHAM NPU HARDWARE EXECUTION LAUNCH          " << std::endl;
        std::cout << "=================================================" << std::endl;

        std::cout << "[1/4] Writing Weight Address: 0x" << std::hex << weight_phys_addr << std::endl;
        write_reg(REG_WEIGHT_ADDR, weight_phys_addr);

        std::cout << "[2/4] Writing Activation Address: 0x" << std::hex << act_phys_addr << std::endl;
        write_reg(REG_ACT_ADDR, act_phys_addr);

        std::cout << "[3/4] Writing Output Buffer Address: 0x" << std::hex << out_phys_addr << std::endl;
        write_reg(REG_OUT_ADDR, out_phys_addr);

        std::cout << "[4/4] Setting Matrix Dimension N = " << std::dec << matrix_dim << std::endl;
        write_reg(REG_MATRIX_DIM, matrix_dim);

        std::cout << "[INFO] Asserting REG_CONTROL bit 0 (Start Pulse)..." << std::endl;
        auto start_time = std::chrono::high_resolution_clock::now();
        write_reg(REG_CONTROL, 0x00000001);

        std::cout << "[INFO] Polling REG_STATUS for completion..." << std::endl;
        uint32_t status = 0;
        int timeout_cycles = 10000;

        while (timeout_cycles--) {
            status = read_reg(REG_STATUS);
            if (status & 0x01) break;
            std::this_thread::sleep_for(std::chrono::microseconds(10));
        }

        auto end_time = std::chrono::high_resolution_clock::now();
        auto elapsed_us = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time).count();

        if (status & 0x01) {
            std::cout << "=================================================" << std::endl;
            std::cout << " [SUCCESS] NPU Execution Completed in " << elapsed_us << " us!" << std::endl;
            std::cout << "           • Status Register Readback: 0x" << std::hex << status << std::endl;
            std::cout << "=================================================" << std::endl;
            return true;
        } else {
            std::cerr << "[ERROR] Execution timed out!" << std::endl;
            return false;
        }
    }
};

int main(int argc, char* argv[]) {
    SiddhamNPUDriver npu;
    npu.load_bitstream("./siddham_npu.bit");
    if (!npu.init_mmio()) return -1;
    return npu.execute_vector_operation(0x80000000U, 0x85000000U, 0x90000000U, 16) ? 0 : -1;
}