cmake_minimum_required(VERSION 3.2)

project(kdmessage
    LANGUAGES C
)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/modules")
set(KERNEL_DIR "/usr/src/linux")

include(KernelModule)

add_kernel_module(example1
    example1.c
)
