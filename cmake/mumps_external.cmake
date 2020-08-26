set(mumps_external true CACHE BOOL "autobuild Mumps")

# necessary since CMAKE_ARGS is broken in general
set(parallel ${mpi} CACHE BOOL "Mumps parallel == Gemini mpi")

include(FetchContent)

FetchContent_Declare(MUMPS_proj
  GIT_REPOSITORY https://github.com/scivision/mumps.git
  GIT_TAG v5.3.3.7
  CMAKE_ARGS -Darith=${arith} -Dmetis:BOOL=${metis} -Dscotch:BOOL=${scotch} -Dopenmp:BOOL=false
)

FetchContent_MakeAvailable(MUMPS_proj)

set(MUMPS_FOUND true)
