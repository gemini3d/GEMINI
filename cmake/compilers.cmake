if(NOT (CMAKE_Fortran_COMPILER_ID STREQUAL ${CMAKE_C_COMPILER_ID} AND CMAKE_Fortran_COMPILER_VERSION VERSION_EQUAL ${CMAKE_C_COMPILER_VERSION}))
message(WARNING "C compiler ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION} != Fortran compiler ${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION}.
Set environment variables CC and FC to control compiler selection in general.")
endif()

include(CheckFortranSourceCompiles)
include(CheckFortranCompilerFlag)

# === check that the compiler has adequate Fortran 2008 support
# this is to mitigate confusing syntax error messages for new users

# clean out prior libs to avoid false fails
set(CMAKE_REQUIRED_LIBRARIES)
set(CMAKE_REQUIRED_INCLUDES)
set(CMAKE_REQUIRED_FLAGS)

check_fortran_source_compiles("implicit none (type, external); end" f2018impnone SRC_EXT f90)
if(NOT f2018impnone)
  message(FATAL_ERROR "Compiler does not support Fortran 2018 IMPLICIT NONE (type, external): ${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION}")
endif()

check_fortran_source_compiles("character :: x; error stop x; end" f2018errorstop SRC_EXT f90)
if(NOT f2018errorstop)
  message(FATAL_ERROR "Compiler does not support Fortran 2018 error stop with character variable: ${CMAKE_Fortran_COMPILER_ID} ${CMAKE_Fortran_COMPILER_VERSION}")
endif()

# Do these before compiler options so options don't goof up finding

if(mpi)
  include(${CMAKE_CURRENT_LIST_DIR}/mpi.cmake)
endif(mpi)

if(NOT mpi)
  add_subdirectory(src/vendor/mpi_stubs)
endif(NOT mpi)

# optional, for possible MUMPS speedup
if(openmp)
find_package(OpenMP COMPONENTS C Fortran)
endif()
