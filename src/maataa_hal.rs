use std::ffi::c_void;
use std::sync::Mutex;
use std::fmt;
use std::error::Error;

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
    raw_handle: Mutex<*mut c_void>,
}

unsafe impl Send for SovereignHardwareAccelerator {}
unsafe impl Sync for SovereignHardwareAccelerator {}

impl SovereignHardwareAccelerator {
    pub fn new() -> Result<Self, HalStatus> {
        let handle = unsafe { crate::maataa_hal::maataa_hal_create_device() };
        if handle.is_null() {
            Err(HalStatus::MmapFailed)
        } else {
            Ok(Self {
                raw_handle: Mutex::new(handle),
            })
        }
    }

    pub fn process_vector(&self, input: &[f32]) -> Result<(Vec<f32>, ExecutionMetrics), HalStatus> {
        let mut output = vec![0.0f32; input.len()];
        let mut cycles: u32 = 0;
        let mut latency: f32 = 0.0;

        let handle_guard = self.raw_handle.lock().unwrap();

        let raw_status = unsafe {
            crate::maataa_hal::maataa_hal_execute(
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
}

impl Drop for SovereignHardwareAccelerator {
    fn drop(&mut self) {
        let handle_guard = self.raw_handle.lock().unwrap();
        if !handle_guard.is_null() {
            unsafe { crate::maataa_hal::maataa_hal_destroy_device(*handle_guard) };
        }
    }
}

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