# Leave nc4fortran as FetchContent as we use wrangle NetCDF library distinctions there
include(FetchContent)

if(netcdf)
  set(nc4fortran_BUILD_TESTING false CACHE BOOL "h5fortran no test")

  find_package(nc4fortran CONFIG)
  if(nc4fortran_FOUND)
    find_package(NetCDF COMPONENTS Fortran REQUIRED)
    return()
  endif()

  cmake_minimum_required(VERSION 3.19...${CMAKE_MAX_VERSION})

  FetchContent_Declare(NC4FORTRAN
    GIT_REPOSITORY ${nc4fortran_git}
    GIT_TAG ${nc4fortran_tag})

  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.14)
    FetchContent_MakeAvailable(NC4FORTRAN)
  elseif(NOT nc4fortran_POPULATED)
    FetchContent_Populate(NC4FORTRAN)
    add_subdirectory(${nc4fortran_SOURCE_DIR} ${nc4fortran_BINARY_DIR})
  endif()
else(netcdf)
  message(VERBOSE " using nc4fortran dummy")

  add_library(nc4fortran ${CMAKE_CURRENT_SOURCE_DIR}/src/vendor/nc4fortran_dummy.f90)
  target_include_directories(nc4fortran INTERFACE ${CMAKE_CURRENT_BINARY_DIR}/include)
  set_target_properties(nc4fortran PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include)
  add_library(nc4fortran::nc4fortran ALIAS nc4fortran)
endif(netcdf)
