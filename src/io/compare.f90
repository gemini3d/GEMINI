module compare_h5
!! for safety, this trades efficiency for reliability
!! that is, we repeatedly open, close, allocate to help avoid
!! any weird bugs causing false positive/negative

use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
use, intrinsic :: iso_fortran_env, only : stderr=>error_unit, int64
use phys_consts, only : wp
use timeutils, only : date_filename, dateinc
use config, only : gemini_cfg, read_configfile
use h5fortran, only : hdf5_file
use pathlib, only : get_suffix, file_name
use reader, only : get_simsize3, get_simsize2
use assert, only : isclose

implicit none (type, external)

type params
logical :: matlab = .false., python = .false., debug = .false.
end type params

integer, parameter :: lsp=7

real(wp), parameter :: &
rtol = 1e-5_wp,  atol = 1e-8_wp, &
rtolJ = 0.01_wp, atolJ = 1e-7_wp, &
rtolV = 1e-5_wp, atolV = 50, &
rtolN = 1e-5_wp, atolN = 1e9_wp, &
rtolT = 1e-5_wp, atolT = 100

private
public :: check_plasma_output_hdf5, check_plasma_input_hdf5, &
  check_simsize, check_simsize2, check_time, check_grid, &
  params, plot_diff

interface !< compare_out_h5.f90
module logical function check_plasma_output_hdf5(new_path, ref_path, P)
character(*), intent(in) :: new_path, ref_path
class(params), intent(in) :: P
end function check_plasma_output_hdf5
end interface

interface !< compare_in_h5.f90
module logical function check_plasma_input_hdf5(new_path, ref_path, P)
character(*), intent(in) :: new_path, ref_path
class(params), intent(in) :: P
end function check_plasma_input_hdf5
end interface

interface !< compare_grid_h5.f90
module logical function check_grid(new_path, ref_path, P)
character(*), intent(in) :: new_path, ref_path
class(params), intent(in) :: P
end function check_grid
end interface

contains

subroutine plot_diff(new_file, ref_file, name, P)
!! call MatGemini or PyGemini plotdiff()
character(*), intent(in) :: new_file, ref_file, name
class(params), intent(in) :: P

character(1000) :: cmd
integer :: ierr1, ierr2

ierr1 = 0
ierr2 = 0

if(P%python) then
  cmd = "python -m gemini3d.compare " // new_file // " " // ref_file // " -plot -name " // name(1:2)
elseif(P%matlab) then
  cmd = "matlab -batch " // achar(34) // "gemini3d.plot.plotdiff('" // new_file // "', '" // ref_file // "', '" // name(1:2) // &
    "')" // achar(34)
else
  return
endif

call execute_command_line(cmd, exitstat=ierr1, cmdstat=ierr2)
if(ierr1 /=0 .or. ierr2 /= 0) then
  if(P%python) then
    write(stderr,'(A,/,A)') "ERROR: failed to plot diff using PyGemini: ", trim(cmd)
  elseif(P%matlab) then
    write(stderr,"(A,/,A,/,A,/,A)") "ERROR: failed to plot diff using MatGemini: ", trim(cmd), &
      "try putting MatGemini path in user environment variable MATLABPATH. See:", &
      "https://www.mathworks.com/help/matlab/matlab_env/add-folders-to-matlab-search-path-at-startup.html"
  endif
endif

end subroutine plot_diff


subroutine check_simsize(new, ref, lx1, lx2all, lx3all)
!! check that new simsize == Old_simsize
!!
!! parameters
!! ----------
!! new: top-level new directory
!! ref: top-level reference directory
!!
!! returns
!! -------
!! lx1: # lx1 cells
!! lx2all: # lx2 cells
!! lx3all: # lx3 cells

character(*), intent(in) :: new, ref
integer, intent(out) :: lx1, lx2all, lx3all

integer :: R_lx1, R_lx2all, R_lx3all

call get_simsize3(ref // "/inputs/simsize.h5", R_lx1, R_lx2all, R_lx3all)
call get_simsize3(new // "/inputs/simsize.h5", lx1, lx2all, lx3all)

if(lx1 /= R_lx1) error stop 'lx1 != ref: ' // new
if(lx2all /= R_lx2all) error stop 'lx2all != ref: ' // new
if(lx3all /= R_lx3all) error stop 'lx3all != ref: ' // new

end subroutine check_simsize


subroutine check_simsize2(new, ref, lx2, lx3)
!! check that new simsize == Old_simsize
!!
!! parameters
!! ----------
!! new: top-level new directory
!! ref: top-level reference directory
!!
!! returns
!! -------
!! lx2: # lx2 cells
!! lx3: # lx3 cells

character(*), intent(in) :: new, ref
integer, intent(out) :: lx2, lx3

integer :: R_lx2, R_lx3

call get_simsize2(ref // "/simsize.h5", R_lx2, R_lx3)
call get_simsize2(new // "/simsize.h5", lx2, lx3)

if(lx2 /= R_lx2) error stop 'lx2 != ref: ' // new
if(lx3 /= R_lx3) error stop 'lx3 != ref: ' // new

end subroutine check_simsize2


subroutine check_time(new_file, ref_file)

character(*), intent(in) :: new_file, ref_file

real(wp) :: UTsec1, UTsec2
integer :: ymd1(3), ymd2(3)

type(hdf5_file) :: hnew, href

call hnew%open(new_file, action='r')
call href%open(ref_file, action='r')

call href%read('/time/ymd', ymd1)
call hnew%read('/time/ymd', ymd2)

if (href%exist('/time/UTsec')) then
  call href%read('/time/UTsec', UTsec1)
  call hnew%read('/time/UTsec', UTsec2)
elseif (href%exist('/time/UThour')) then
  call href%read('/time/UThour', UTsec1)
  call hnew%read('/time/UThour', UTsec2)
  UTsec1 = UTsec1*3600
  UTsec2 = UTsec2*3600
else
  error stop "check_time: did not find UTsec or UThour in " // ref_file
endif

call hnew%close()
call href%close()

!> compare file simulation time

call dateinc(0._wp, ymd1, UTsec1)
call dateinc(0._wp, ymd2, UTsec2)
!! sanitize wrapping glitches due to non-integer timebase
!! due to non-integer timebase, can get hour-wrapping in Fortran code.
!! This would be fixed someday by using integer microsecond timebase

if (any(ymd1 /= ymd2)) error stop 'dates did not match: ' // new_file
if (abs(UTsec1 - UTsec2) > 0.1) error stop "UThour not match: " // new_file


end subroutine check_time


end module compare_h5
