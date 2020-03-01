use, intrinsic:: iso_fortran_env, only: sp=>real32

implicit none

integer, parameter :: mass=48
integer :: iyd,sec,lz, i
real(sp) :: f107a,f107,ap(7),stl,apday,ap3
real(sp) :: d(9),t(2)
real(sp), allocatable :: glat(:),glon(:),alt(:)

character(256) :: buf
character(:), allocatable :: infile,outfile

!> read in msis inputs
if (command_argument_count() < 2) error stop 'msis_setup: must specify input and output filenames'

call get_command_argument(1,buf)
infile = trim(buf)

block
  integer :: u
  open(newunit=u,file=infile, status='old',form='unformatted',access='stream', action='read')
  !! use binary to reduce file size and read times

  read(u) iyd
  read(u) sec
  read(u) f107a
  read(u) f107
  read(u) apday
  read(u) ap3
  read(u) lz

  print *, 'msis_setup parameters: ', infile,iyd,sec,f107a,f107,apday,ap3,lz

  call get_command_argument(3, buf, status=i)
  if (lz<1) error stop 'lz must be positive'
  if (i==0) then
    read(buf,*) i
    if (i/=lz) then
      write(stderr,*) 'expected ',i,' grid points but read ',lz
      error stop
    endif
  endif

  allocate(glat(lz),glon(lz),alt(lz))

  read(u) glat,glon,alt

  close(u)
end block

!> Run MSIS
ap(1:7)=apday
ap(2)=ap3

!> switch to mksa units
call meters(.true.)

!> output file
call get_command_argument(2, buf)
outfile = trim(buf)

block
  integer :: u
  open(newunit=u,file=outfile,status='replace',form='unformatted',access='stream', action='write')
    !! use binary to reduce file size and read times

  !> call to msis routine
  do i=1,lz
    stl = sec/3600. + glon(i)/15.
    call gtd7(iyd, real(sec, sp),alt(i),glat(i),glon(i),stl,f107a,f107,ap,mass,d,t)
    write(u) alt(i),d(1:9),t(2)
  !  write(*,'(1f20.4, 9e20.8, 1f20.4)') alt(i),d(1:9),t(2)
  ! write(*,1000),alt(i),d(1:9),t(2)
  ! 1000 format(1F,9E,1F)
  end do

  close(u)

  inquire(file=outfile, size=i)
  print *,'msis_setup: wrote ',i,' bytes to ',outfile
  if (i==0) error stop 'msis_setup failed to write file'
end block



end program
