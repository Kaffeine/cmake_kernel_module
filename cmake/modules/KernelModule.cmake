
set(KERNEL_INCLUDES
    -I${KERNEL_DIR}/arch/x86/include
    -I${KERNEL_DIR}/arch/x86/include/generated
    -I${KERNEL_DIR}/include
    -I${KERNEL_DIR}/arch/x86/include/uapi
    -I${KERNEL_DIR}/arch/x86/include/generated/uapi
    -I${KERNEL_DIR}/include/uapi
    -I${KERNEL_DIR}/include/generated/uapi
)

set (KERNEL_PREPROCESSOR_INCLUDES
    -include ${KERNEL_DIR}/include/linux/kconfig.h
    -include ${KERNEL_DIR}/include/linux/compiler_types.h
)

set(KERNEL_CFLAGS
    -D__KERNEL__
    -O2 -m64
    -std=gnu89
    -falign-jumps=1
    -falign-loops=1
    -mno-80387
    -mno-fp-ret-in-387
    -mskip-rax-setup
    -mno-red-zone
    -mcmodel=kernel
    --param=allow-store-data-races=0

    -fno-asynchronous-unwind-tables
    -fno-delete-null-pointer-checks
    -fno-var-tracking-assignments
    -fno-strict-overflow
    -fno-merge-all-constants -fmerge-constants
    -fno-stack-check
    -fstack-protector-strong
    -fconserve-stack
    -fomit-frame-pointer
    -fno-strict-aliasing -fno-common -fshort-wchar
    -fno-PIE
    -Wall
    -Wundef
    -Wno-trigraphs
    -Wno-format-security
    -Wno-sign-compare
    -Wno-frame-address
    -Wframe-larger-than=2048
    -Wno-unused-but-set-variable
    -Wno-unused-const-variable
    -Wdeclaration-after-statement
    -Wvla
    -Wno-pointer-sign

    -Werror=strict-prototypes
    -Werror-implicit-function-declaration
    -Werror=implicit-int
    -Werror=date-time
    -Werror=incompatible-pointer-types
    -Werror=designated-init
)

function(compile_kernel_object object_name)
    # Parse arguments
    set(options)
    set(oneValueArgs MODNAME)
    set(multiValueArgs)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    set(_object_source ${ARGS_UNPARSED_ARGUMENTS})

    add_custom_command(
        OUTPUT ${object_name}.o
        COMMENT "Generating ${object_name}.o"
        COMMAND gcc -Wp,-MD,.${object_name}.o.d
                -nostdinc -isystem /usr/lib/gcc/x86_64-pc-linux-gnu/${CMAKE_C_COMPILER_VERSION}/include
                ${KERNEL_INCLUDES} ${KERNEL_PREPROCESSOR_INCLUDES} ${KERNEL_CFLAGS}
                -DMODULE -DKBUILD_BASENAME='"${object_name}"' -DKBUILD_MODNAME='"${ARGS_MODNAME}"'
                -c -o ${object_name}.o ${_object_source}
        DEPENDS ${_object_source}
        )
endfunction()

function(process_kernel_object object_name)
    # Parse arguments
    set(options)
    set(oneValueArgs MODNAME)
    set(multiValueArgs)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    set(_object_source ${ARGS_UNPARSED_ARGUMENTS})

    add_custom_command(
        OUTPUT ${object_name}.mod.c
        COMMENT "Generating ${object_name}.mod.c"
        COMMAND echo "${object_name}.o"  | ${KERNEL_DIR}/scripts/mod/modpost -S -s -T -
        DEPENDS ${object_name}.o
    )
endfunction()

function(link_kernel_module target_name)
    set(options)
    set(oneValueArgs)
    set(multiValueArgs)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    set(_input_objects ${ARGS_UNPARSED_ARGUMENTS})
    set(_module_file "${target_name}.ko")

    add_custom_command(
        OUTPUT ${target_name}.ko
        COMMENT "Generating ${target_name}.ko"
        COMMAND ld -r -m elf_x86_64
            -z max-page-size=0x200000
            -T ${KERNEL_DIR}/scripts/module-common.lds
            --build-id
            -o ${target_name}.ko
            ${_input_objects}
        DEPENDS ${_input_objects}
    )
endfunction()

function(add_kernel_module target_name)
    # Parse arguments
    set(options)
    set(oneValueArgs)
    set(multiValueArgs)
    cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    set(_sources ${ARGS_UNPARSED_ARGUMENTS})
    set(_module_file "${target_name}.ko")

    set(_kernel_obj ${target_name}.o)

    compile_kernel_object(${target_name}
        MODNAME ${target_name}
        ${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.c
    )

    process_kernel_object(${target_name})

    compile_kernel_object(${target_name}.mod
        MODNAME ${target_name}
        ${target_name}.mod.c
    )

    link_kernel_module(${target_name}
        ${target_name}.o
        ${target_name}.mod.o
    )

    add_custom_target(${target_name} ALL DEPENDS ${target_name}.ko)
endfunction()
