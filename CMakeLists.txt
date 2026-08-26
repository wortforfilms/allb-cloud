cmake_minimum_required(VERSION 3.16)
project(maataa_hal_driver CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Update source path to c_src/maataa_hal.cpp
add_library(maataa_hal SHARED c_src/maataa_hal.cpp)
target_include_directories(maataa_hal PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/c_src)