# PawnIO - Input-output driver
# Copyright (C) 2026  namazso <admin@namazso.eu>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Linking PawnIO statically or dynamically with other modules is making a
# combined work based on PawnIO. Thus, the terms and conditions of the GNU
# General Public License cover the whole combination.
#
# In addition, as a special exception, the copyright holders of PawnIO give
# you permission to combine PawnIO program with free software programs or
# libraries that are released under the GNU LGPL and with independent modules
# that communicate with PawnIO solely through the device IO control
# interface. You may copy and distribute such a system following the terms of
# the GNU GPL for PawnIO and the licenses of the other code concerned,
# provided that you include the source code of that other code when and as
# the GNU GPL requires distribution of source code.
#
# Note that this exception does not include programs that communicate with
# PawnIO over the Pawn interface. This means that all modules loaded into
# PawnIO must be compatible with this licence, including the earlier
# exception clause. We recommend using the GNU Lesser General Public License
# version 2.1 to fulfill this requirement.
#
# For alternative licensing options, please contact the copyright holder at
# admin@namazso.eu.
#
# Note that people who make modified versions of PawnIO are not obligated to
# grant this special exception for their modified versions; it is their
# choice whether to do so. The GNU General Public License gives permission
# to release a modified version without this exception; this exception also
# makes it possible to release a modified version which carries forward this
# exception.

cmake_minimum_required(VERSION 3.25)
project(PawnIO LANGUAGES CXX ASM_MASM VERSION 2.2.0)

set(PAWNIO_NAME "PawnIO" CACHE STRING "The name of the driver")
set(PAWNIO_NAME_FULL "PawnIO Official Build" CACHE STRING "The full name of the driver, shown in inf and file properties")
set(PAWNIO_AUTHOR "namazso" CACHE STRING "The author of the driver, shown in inf and file properties")
set(PAWNIO_DATE "03/11/2026" CACHE STRING "The date of the driver, used in inf file")

option(PAWNIO_UNRESTRICTED "Whether to build an unrestricted version of the driver" OFF)

option(PAWNIO_PRODUCTION_BUILD "Enforce the independently signed production-driver profile" OFF)
option(PAWNIO_TRUST_UPSTREAM "Trust modules signed by the upstream PawnIO module key" ON)
set(PAWNIO_CUSTOM_TRUST_KEY_BLOB "" CACHE FILEPATH
    "Raw 4096-bit CNG BCRYPT_RSAPUBLIC_BLOB trusted for module signing")
set(PAWNIO_CUSTOM_TRUST_KEY_SHA256 "" CACHE STRING
    "Pinned lowercase SHA-256 of the custom module trust-key blob")

if (PAWNIO_PRODUCTION_BUILD)
    if (PAWNIO_UNRESTRICTED)
        message(FATAL_ERROR "Production builds cannot enable PAWNIO_UNRESTRICTED")
    endif ()
    if (PAWNIO_TRUST_UPSTREAM)
        message(FATAL_ERROR "Softhe production builds must use only the explicitly supplied custom module key")
    endif ()
    if (PAWNIO_CUSTOM_TRUST_KEY_BLOB STREQUAL "")
        message(FATAL_ERROR "Softhe production builds require PAWNIO_CUSTOM_TRUST_KEY_BLOB")
    endif ()
    string(LENGTH "${PAWNIO_CUSTOM_TRUST_KEY_SHA256}" PAWNIO_CUSTOM_TRUST_KEY_SHA256_LENGTH)
    if (NOT PAWNIO_CUSTOM_TRUST_KEY_SHA256_LENGTH EQUAL 64 OR
        PAWNIO_CUSTOM_TRUST_KEY_SHA256 MATCHES "[^0-9a-f]")
        message(FATAL_ERROR "Softhe production builds require a pinned lowercase PAWNIO_CUSTOM_TRUST_KEY_SHA256")
    endif ()
    if (PAWNIO_NAME STREQUAL "PawnIO" OR PAWNIO_AUTHOR STREQUAL "namazso")
        message(FATAL_ERROR "Softhe production builds require distinct driver naming and authorship")
    endif ()
endif ()

if (NOT PAWNIO_CUSTOM_TRUST_KEY_BLOB STREQUAL "")
    if (NOT EXISTS "${PAWNIO_CUSTOM_TRUST_KEY_BLOB}")
        message(FATAL_ERROR "Custom module trust-key blob does not exist: ${PAWNIO_CUSTOM_TRUST_KEY_BLOB}")
    endif ()
    file(READ "${PAWNIO_CUSTOM_TRUST_KEY_BLOB}" PAWNIO_CUSTOM_TRUST_KEY_HEX HEX)
    string(LENGTH "${PAWNIO_CUSTOM_TRUST_KEY_HEX}" PAWNIO_CUSTOM_TRUST_KEY_HEX_LENGTH)
    if (NOT PAWNIO_CUSTOM_TRUST_KEY_HEX_LENGTH EQUAL 1078)
        message(FATAL_ERROR
            "Custom module trust key must be a 539-byte, 4096-bit CNG BCRYPT_RSAPUBLIC_BLOB")
    endif ()
    string(SUBSTRING "${PAWNIO_CUSTOM_TRUST_KEY_HEX}" 0 48 PAWNIO_CUSTOM_TRUST_KEY_HEADER_HEX)
    string(SUBSTRING "${PAWNIO_CUSTOM_TRUST_KEY_HEX}" 48 6 PAWNIO_CUSTOM_TRUST_KEY_EXPONENT_HEX)
    if (NOT PAWNIO_CUSTOM_TRUST_KEY_HEADER_HEX STREQUAL "525341310010000003000000000200000000000000000000" OR
        NOT PAWNIO_CUSTOM_TRUST_KEY_EXPONENT_HEX STREQUAL "010001")
        message(FATAL_ERROR
            "Custom module trust key must use a 4096-bit RSA public key with exponent 65537")
    endif ()
    file(SHA256 "${PAWNIO_CUSTOM_TRUST_KEY_BLOB}" PAWNIO_CUSTOM_TRUST_KEY_ACTUAL_SHA256)
    string(TOLOWER "${PAWNIO_CUSTOM_TRUST_KEY_ACTUAL_SHA256}" PAWNIO_CUSTOM_TRUST_KEY_ACTUAL_SHA256)
    if (PAWNIO_PRODUCTION_BUILD AND
        PAWNIO_CUSTOM_TRUST_KEY_ACTUAL_SHA256 STREQUAL "724af6ac42e7a4cbbbe3e4a5a0117af0fd98364a72c2aee40972228838400e59")
        message(FATAL_ERROR "Softhe production builds cannot reuse the upstream PawnIO module key")
    endif ()
    if (NOT PAWNIO_CUSTOM_TRUST_KEY_SHA256 STREQUAL "" AND
        NOT PAWNIO_CUSTOM_TRUST_KEY_ACTUAL_SHA256 STREQUAL PAWNIO_CUSTOM_TRUST_KEY_SHA256)
        message(FATAL_ERROR "Custom module trust-key SHA-256 does not match its pinned fingerprint")
    endif ()
    string(REGEX REPLACE "([0-9a-fA-F][0-9a-fA-F])" "0x\\1, "
        PAWNIO_CUSTOM_TRUST_KEY_BYTES "${PAWNIO_CUSTOM_TRUST_KEY_HEX}")
    file(CONFIGURE
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/generated/custom_trusted_key.h"
        CONTENT "constexpr static uint8_t k_pubkey_custom[] = { @PAWNIO_CUSTOM_TRUST_KEY_BYTES@ };\n"
        @ONLY)
endif ()

set(SIGN_SCRIPT "" CACHE STRING "Signing script, called like <script> <input> <output>")

set(CMAKE_CXX_STANDARD 20)

add_compile_definitions(
        PAWNIO_NAME="${PAWNIO_NAME}"
        PAWNIO_NAME_FULL="${PAWNIO_NAME_FULL}"
        PAWNIO_AUTHOR="${PAWNIO_AUTHOR}"
        PAWNIO_VERSION_STRING="${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}"
        PAWNIO_VERSION_STRING4="${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}.0"
        PAWNIO_MAJOR=${PROJECT_VERSION_MAJOR}
        PAWNIO_MINOR=${PROJECT_VERSION_MINOR}
        PAWNIO_PATCH=${PROJECT_VERSION_PATCH}
)

add_compile_options(
        /W4
        /WX
        /utf-8
        /d1nodatetime
        /Brepro
        /Zi
)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

find_package(WDK REQUIRED)

add_link_options(
        /DEBUG
        /OPT:REF
        /OPT:ICF=10
        /EMITPOGOPHASEINFO
        /FILEALIGN:0x1000
        $<$<STREQUAL:"${WDK_PLATFORM}","x64">:/CETCOMPAT>
        $<$<NOT:$<STREQUAL:"${CMAKE_BUILD_TYPE}","Debug">>:/BREPRO>
        $<$<NOT:$<STREQUAL:"${CMAKE_BUILD_TYPE}","Debug">>:/NOVCFEATURE>
        $<$<NOT:$<STREQUAL:"${CMAKE_BUILD_TYPE}","Debug">>:/NOCOFFGRPINFO>
        $<$<NOT:$<STREQUAL:"${CMAKE_BUILD_TYPE}","Debug">>:/PDBALTPATH:%_PDB%>
)

set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "ProgramDatabase")

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

string(REGEX REPLACE "(^| )[/-]GR( |$)" " " CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
string(REGEX REPLACE "(^| )[/-]EHsc( |$)" " " CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")

find_program(MAKECAB makecab REQUIRED)

find_program(INF2CAT REQUIRED
        NAMES inf2cat inf2cat.exe
        PATHS "${WDK_ROOT}"
        PATH_SUFFIXES
        "bin/x64"
        "bin/x86"
        "bin/${WDK_VERSION}/x64"
        "bin/${WDK_VERSION}/x86"
)

add_library(PawnPP INTERFACE)
target_include_directories(PawnPP INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/PawnPP)

add_subdirectory(PawnIO)

# PawnIOLib

add_library(PawnIOLib SHARED
        PawnIOLib/PawnIOLib.cpp
        PawnIOLib/resource.rc
)

target_compile_options(PawnIOLib PRIVATE /EHsc)

target_link_libraries(PawnIOLib PRIVATE ntdll.lib PawnIOInclude)

target_link_options(PawnIOLib PRIVATE
        /ENTRY:DllEntry
)

target_include_directories(PawnIOLib PUBLIC PawnIOLib/include)

# PawnIOUtil

add_executable(PawnIOUtil
        PawnIOUtil/PawnIOUtil.cpp
        PawnIOUtil/signature.cpp
        PawnIOUtil/resource.rc
)

target_compile_options(PawnIOUtil PRIVATE /EHsc)

target_link_libraries(PawnIOUtil PRIVATE PawnIOLib)
