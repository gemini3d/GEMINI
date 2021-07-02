submodule (io:plasma_input) plasma_input_nc4

use timeutils, only : date_filename
use nc4fortran, only: netcdf_file

implicit none (type, external)

contains

module procedure input_root_currents_nc4
  !! READS, AS INPUT, A FILE GENERATED BY THE GEMINI.F90 PROGRAM

  character(:), allocatable :: filenamefull
  real(wp), dimension(:,:,:), allocatable :: J1all,J2all,J3all
  real(wp), dimension(:,:,:), allocatable :: tmpswap

  type(netcdf_file) :: hf

  !>  CHECK TO MAKE SURE WE ACTUALLY HAVE THE DATA WE NEED TO DO THE MAG COMPUTATIONS.
  if (flagoutput==3) error stop 'Need current densities in the output to compute magnetic fields'


  !> FORM THE INPUT FILE NAME
  filenamefull = date_filename(outdir,ymd,UTsec) // '.nc'
  print *, 'Input file name for current densities:  ', filenamefull

  call hf%open(filenamefull, status='old', action='r')

  !> LOAD THE DATA
  !> PERMUTE THE ARRAYS IF NECESSARY
  allocate(J1all(lx1,lx2all,lx3all),J2all(lx1,lx2all,lx3all),J3all(lx1,lx2all,lx3all))
  !! no need to permute dimensions for 3D simulations
  call hf%read('J1all', J1all)
  call hf%read('J2all', J2all)
  call hf%read('J3all', J3all)
  print *, 'Min/max current data:  ',minval(J1all),maxval(J1all),minval(J2all),maxval(J2all),minval(J3all),maxval(J3all)

  call hf%close()

  !> DISTRIBUTE DATA TO WORKERS AND TAKE A PIECE FOR ROOT
  call bcast_send(J1all,tag%J1,J1)
  call bcast_send(J2all,tag%J2,J2)
  call bcast_send(J3all,tag%J3,J3)
end procedure input_root_currents_nc4


module procedure input_root_mpi_nc4
  !! READ INPUT FROM FILE AND DISTRIBUTE TO WORKERS.
  !! STATE VARS ARE EXPECTED INCLUDE GHOST CELLS.  NOTE ALSO
  !! THAT RECORD-BASED INPUT IS USED SO NO FILES > 2GB DUE
  !! TO GFORTRAN BUG WHICH DISALLOWS 8 BYTE INTEGER RECORD
  !! LENGTHS.

  type(netcdf_file) :: hf

  integer :: lx1,lx2,lx3,lx2all,lx3all,isp
  integer :: ix1

  real(wp), dimension(-1:size(x1,1)-2,-1:size(x2all,1)-2,-1:size(x3all,1)-2,1:lsp) :: nsall, vs1all, Tsall
  integer :: lx1in,lx2in,lx3in,u, utrace
  real(wp) :: tin
  real(wp), dimension(3) :: ymdtmp
  real(wp) :: tstart,tfin
  real(wp), dimension(:,:), allocatable :: Phislab
  real(wp), allocatable :: tmp(:,:,:,:), tmpPhi(:)

  !> so that random values (including NaN) don't show up in Ghost cells
  nsall = 0
  ns = 0
  vs1all= 0
  vs1 = 0
  Tsall = 0
  Ts = 0

  !> SYSTEM SIZES
  lx1=size(ns,1)-4
  lx2=size(ns,2)-4
  lx3=size(ns,3)-4
  lx2all=size(x2all)-4
  lx3all=size(x3all)-4

  allocate(Phislab(1:lx2all,1:lx3all))  !space to store EFL potential

  !> READ IN FROM FILE, AS OF CURVILINEAR BRANCH THIS IS NOW THE ONLY INPUT OPTION
  call get_simsize3(indatsize, lx1in, lx2in, lx3in)
  print '(2A,3I6)', indatsize,' input dimensions:',lx1in,lx2in,lx3in
  print '(A,3I6)', 'Target (output) grid structure dimensions:',lx1,lx2all,lx3all

  if (.not. (lx1==lx1in .and. lx2all==lx2in .and. lx3all==lx3in)) then
    error stop 'The input data must be the same size as the grid which you are running the simulation on' // &
         '- use a script to interpolate up/down to the simulation grid'
  end if

  call hf%open(indatfile, status='old', action='r')

  call hf%read('nsall', nsall(1:lx1,1:lx2all,1:lx3all,1:lsp))
  call hf%read('vs1all', vs1all(1:lx1,1:lx2all,1:lx3all,1:lsp))
  call hf%read('Tsall', Tsall(1:lx1,1:lx2all,1:lx3all,1:lsp))
  !! FIXME: MH - does this need code like in the hdf5 input to check singleton dims???
  if (hf%exist('Phiall')) then
    call hf%read('Phiall', Phislab)
  else
    Phislab = 0
  end if

  call hf%close()

  !> Apply EFL approx to compute full grid potential
  do ix1=1,lx1
    Phiall(ix1,1:lx2all,1:lx3all)=Phislab(1:lx2all,1:lx3all)
  end do

  !> ROOT BROADCASTS IC DATA TO WORKERS
  call cpu_time(tstart)
  call bcast_send(nsall,tag%ns,ns)
  call bcast_send(vs1all,tag%vs1,vs1)
  call bcast_send(Tsall,tag%Ts,Ts)
  call bcast_send(Phiall,tag%Phi,Phi)
  call cpu_time(tfin)
  print '(A,ES12.3,A)', 'Sent ICs to workers in', tfin-tstart, ' seconds.'

  deallocate(Phislab)
end procedure input_root_mpi_nc4

end submodule plasma_input_nc4
