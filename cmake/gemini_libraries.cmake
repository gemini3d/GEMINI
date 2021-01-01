# this reads gemini_libraries.json in memory, as a "single source of truth"
if(CMAKE_VERSION VERSION_LESS 3.19)
  # FIXME: we should eventually require CMake 3.19 for this and other stability enhancements.

  message(STATUS "Due to CMake < 3.19, using fallback Gemini library versions in ${CMAKE_CURRENT_LIST_FILE}")

  set(gemini_glow_url "https://github.com/gemini3d/glow.git")
  set(gemini_glow_tag "915592c")

  set(gemini_lapack_url "https://github.com/scivision/lapack.git")
  set(gemini_lapack_tag "v3.9.0.2")

  set(gemini_h5fortran_url "https://github.com/geospace-code/h5fortran.git")
  set(gemini_h5fortran_tag "v3.4.2")

  set(gemini_mumps_url "https://github.com/scivision/mumps.git")
  set(gemini_mumps_tag "v5.3.5.2")

  set(gemini_nc4fortran_url "https://github.com/geospace-code/nc4fortran.git")
  set(gemini_nc4fortran_tag "v1.1.2")

  set(gemini_scalapack_url "https://github.com/scivision/scalapack.git")
  set(gemini_scalapack_tag "v2.1.0.11")

  set(gemini_pygemini_url "https://github.com/gemini3d/pygemini.git")
  set(gemini_pygemini_tag "main")

  return()
endif()

# preferred method CMake >= 3.19
file(READ ${CMAKE_CURRENT_LIST_DIR}/gemini_libraries.json _libj)

string(JSON gemini_glow_url GET ${_libj} "glow" "url")
string(JSON gemini_glow_tag GET ${_libj} "glow" "tag")

string(JSON gemini_lapack_url GET ${_libj} "lapack" "url")
string(JSON gemini_lapack_tag GET ${_libj} "lapack" "tag")

string(JSON gemini_h5fortran_url GET ${_libj} "h5fortran" "url")
string(JSON gemini_h5fortran_tag GET ${_libj} "h5fortran" "tag")

string(JSON gemini_mumps_url GET ${_libj} "mumps" "url")
string(JSON gemini_mumps_tag GET ${_libj} "mumps" "tag")

string(JSON gemini_nc4fortran_url GET ${_libj} "nc4fortran" "url")
string(JSON gemini_nc4fortran_tag GET ${_libj} "nc4fortran" "tag")

string(JSON gemini_scalapack_url GET ${_libj} "scalapack" "url")
string(JSON gemini_scalapack_tag GET ${_libj} "scalapack" "tag")

string(JSON gemini_pygemini_url GET ${_libj} "pygemini" "url")
string(JSON gemini_pygemini_tag GET ${_libj} "pygemini" "tag")
