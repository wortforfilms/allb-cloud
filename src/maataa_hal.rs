use std::error::Error;
use std::ffi::c_void;
use std::fmt;
use std::sync::Mutex;

#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum HalStatus {
    Success = 0,
    MmapFailed = 1,
    HardwareTimeout = 2,
    InvalidBuffer = 3,
    DeviceBusy = 4,
}

impl fmt::Display for HalStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            HalStatus::Success => write!(f, "HAL Execution Succeeded"),
            HalStatus::MmapFailed => write!(f, "Memory mapping (/dev/mem) failed"),
            HalStatus::HardwareTimeout => write!(f, "Hardware execution timed out"),
            HalStatus::InvalidBuffer => write!(f, "Invalid buffer passed to hardware"),
            HalStatus::DeviceBusy => write!(f, "Siddham NPU device busy"),
        }
    }
}

impl Error for HalStatus {}

#[derive(Debug, Clone)]
pub struct ExecutionMetrics {
    pub execution_cycles: u32,
    pub latency_ms: f32,
}

pub struct SovereignHardwareAccelerator {
    #[allow(dead_code)]
    raw_handle: Mutex<*mut c_void>,
}

unsafe impl Send for SovereignHardwareAccelerator {}
unsafe impl Sync for SovereignHardwareAccelerator {}

impl SovereignHardwareAccelerator {
    pub fn new() -> Result<Self, HalStatus> {
        #[cfg(not(target_arch = "wasm32"))]
        {
            let handle = unsafe { maataa_hal_create_device() };
            if handle.is_null() {
                Err(HalStatus::MmapFailed)
            } else {
                Ok(Self {
                    raw_handle: Mutex::new(handle),
                })
            }
        }

        #[cfg(target_arch = "wasm32")]
        {
            // WASM Emulation Handle (Non-null Sentinel Pointer)
            let dummy_handle = 0x1 as *mut c_void;
            Ok(Self {
                raw_handle: Mutex::new(dummy_handle),
            })
        }
    }

    pub fn process_vector(&self, input: &[f32]) -> Result<(Vec<f32>, ExecutionMetrics), HalStatus> {
        if input.is_empty() {
            return Err(HalStatus::InvalidBuffer);
        }

        let mut output = vec![0.0f32; input.len()];

        #[cfg(not(target_arch = "wasm32"))]
        {
            let mut cycles: u32 = 0;
            let mut latency: f32 = 0.0;

            let handle_guard = self.raw_handle.lock().unwrap();

            let raw_status = unsafe {
                maataa_hal_execute(
                    *handle_guard,
                    input.as_ptr(),
                    output.as_mut_ptr(),
                    input.len() as u32,
                    &mut cycles,
                    &mut latency,
                )
            };

            match raw_status {
                0 => Ok((
                    output,
                    ExecutionMetrics {
                        execution_cycles: cycles,
                        latency_ms: latency,
                    },
                )),
                1 => Err(HalStatus::MmapFailed),
                2 => Err(HalStatus::HardwareTimeout),
                3 => Err(HalStatus::InvalidBuffer),
                _ => Err(HalStatus::DeviceBusy),
            }
        }

        #[cfg(target_arch = "wasm32")]
        {
            // Software Fallback Vector Processing for WASM Environment
            let start = js_sys::Date::now();
            for (i, val) in input.iter().enumerate() {
                output[i] = val * 1.0; // Passthrough transformation
            }
            let elapsed_ms = (js_sys::Date::now() - start) as f32;

            Ok((
                output,
                ExecutionMetrics {
                    execution_cycles: (input.len() * 4) as u32,
                    latency_ms: elapsed_ms,
                },
            ))
        }
    }
}

impl Drop for SovereignHardwareAccelerator {
    fn drop(&mut self) {
        #[cfg(not(target_arch = "wasm32"))]
        {
            let handle_guard = self.raw_handle.lock().unwrap_or_else(|e| e.into_inner());
            if !handle_guard.is_null() {
                unsafe { maataa_hal_destroy_device(*handle_guard) };
            }
        }
    }
}

// Native Linux/macOS C FFI Bindings (Compiled out on WASM targets)
#[cfg(not(target_arch = "wasm32"))]
extern "C" {
    pub fn maataa_hal_create_device() -> *mut c_void;
    pub fn maataa_hal_destroy_device(handle: *mut c_void);
    pub fn maataa_hal_execute(
        handle: *mut c_void,
        input: *const f32,
        output: *mut f32,
        len: u32,
        cycles_out: *mut u32,
        latency_out: *mut f32,
    ) -> i32;
}