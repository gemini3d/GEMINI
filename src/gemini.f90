Program Gemini3D
!! MAIN PROGRAM FOR GEMINI3D
!! Need program statement for FORD
use, intrinsic :: iso_fortran_env, only : stderr=>error_unit
use phys_consts, only : lnchem, lwave, lsp, wp, debug
use grid, only: grid_size,read_grid,clear_grid,lx1,lx2,lx3,lx2all,lx3all
use mesh, only: curvmesh
use config, only : read_configfile, gemini_cfg
use pathlib, only : assert_file_exists, assert_directory_exists
use io, only : input_plasma,create_outdir,output_plasma,create_outdir_aur,output_aur
use mpimod, only : mpisetup, mpibreakdown, mpi_manualgrid, mpigrid, lid, myid
use multifluid, only : fluid_adv
use neutral, only : neutral_atmos,make_dneu,neutral_perturb,clear_dneu
use potentialBCs_mumps, only: clear_potential_fileinput
use potential_comm,only : electrodynamics
use precipBCs_mod, only: make_precip_fileinput, clear_precip_fileinput
use temporal, only : dt_comm
use timeutils, only: dateinc

implicit none

integer :: ierr

!> VARIABLES READ IN FROM CONFIG FILE
real(wp) :: UTsec
!! UT (s)

!> INPUT AND OUTPUT FILES
character(:), allocatable :: infile
!! command line argument input file
character(:), allocatable :: outdir
!! " " output directory

type(gemini_cfg) :: cfg

!> GRID STRUCTURE
type(curvmesh) :: x
!! structure containg grid locations, finite differences, etc.:  see grid module for details

!> STATE VARIABLES
real(wp), dimension(:,:,:,:), allocatable :: ns,vs1,vs2,vs3,Ts
!! fluid state variables
real(wp), dimension(:,:,:), allocatable :: E1,E2,E3,J1,J2,J3
!! electrodynamic state variables
real(wp), dimension(:,:,:), allocatable :: rhov2,rhov3,B1,B2,B3
!! inductive state vars. (for future use - except for B1 which is used for the background field)
real(wp), dimension(:,:,:), allocatable :: rhom,v1,v2,v3
!! inductive auxiliary
real(wp), dimension(:,:,:,:), allocatable :: nn
!! neutral density array
real(wp), dimension(:,:,:), allocatable :: Tn,vn1,vn2,vn3
!! neutral temperature and velocities
real(wp), dimension(:,:,:), allocatable :: Phiall
!! full-grid potential solution.  To store previous time step value
real(wp), dimension(:,:,:), allocatable :: iver
!! integrated volume emission rate of aurora calculated by GLOW

!TEMPORAL VARIABLES
real(wp) :: t=0, dt=1e-6_wp,dtprev
!! time from beginning of simulation (s) and time step (s)
real(wp) :: tout
!! time for next output and time between outputs
real(wp) :: tstart,tfin
!! temp. vars. for measuring performance of code blocks
integer :: it,isp
!! time and species loop indices

!WORK ARRAYS
real(wp), allocatable :: dl1,dl2,dl3     !these are grid distances in [m] used to compute Courant numbers

real(wp) :: tglowout
!! time for next GLOW output

!> FOR HANDLING OUTPUT
logical :: nooutput = .false.
integer :: argc
character(256) :: argv
integer :: lid2in,lid3in

character(10) :: date, time

!> TO CONTROL THROTTLING OF TIME STEP
real(wp), parameter :: dtscale=2d0

!! MAIN PROGRAM

argc = command_argument_count()
if (argc < 2) then
  print '(/,A,/)', 'GEMINI-3D: by Matthew Zettergren'
  print '(A)', 'GLOW and auroral interfaces by Guy Grubbs'
  print '(A,/)', 'build system and software engineering by Michael Hirsch'
  print *, 'must specify config.nml file to configure simulation and output directory. Example:'
  print '(/,A,/)', 'mpiexec -np 4 build/gemini.bin initialize/test2d_fang/config.nml /tmp/test2d_fang'
  stop 77
  !! stops with de facto "skip test" return code
endif

!> INITIALIZE MESSING PASSING VARIABLES, IDS ETC.
call mpisetup()
call get_command_argument(0, argv)
call date_and_time(date,time)
print '(2A,I6,A3,I6,3A)', trim(argv), ' Process:  ', myid,' / ',lid-1, ' at ', date,' ',time


!> READ FILE INPUT
call get_command_argument(1,argv)
infile = trim(argv)

call read_configfile(infile, cfg)

!> PRINT SOME DIAGNOSIC INFO FROM ROOT
if (myid==0) then
  call assert_file_exists(cfg%indatsize)
  call assert_file_exists(cfg%indatgrid)
  call assert_file_exists(cfg%indatfile)

  print '(A,I6,A1,I0.2,A1,I0.2)', infile // ' simulation year-month-day is:  ',cfg%ymd(1),'-',cfg%ymd(2),'-',cfg%ymd(3)
  print '(A51,F10.3)', 'start time is:  ',cfg%UTsec0
  print '(A51,F10.3)', 'duration is:  ',cfg%tdur
  print '(A51,F10.3)', 'output every:  ',cfg%dtout
  print '(A,/,A,/,A,/,A)', 'gemini.f90: using input data files:', cfg%indatsize, cfg%indatgrid, cfg%indatfile

  if(cfg%flagdneu==1) then
    call assert_directory_exists(cfg%sourcedir)
    print *, 'Neutral disturbance mlat,mlon:  ',cfg%sourcemlat,cfg%sourcemlon
    print *, 'Neutral disturbance cadence (s):  ',cfg%dtneu
    print *, 'Neutral grid resolution (m):  ',cfg%drhon,cfg%dzn
    print *, 'Neutral disturbance data files located in directory:  ',cfg%sourcedir
  end if

  if (cfg%flagprecfile==1) then
    call assert_directory_exists(cfg%precdir)
    print '(A,F10.3)', 'Precipitation file input cadence (s):  ',cfg%dtprec
    print *, 'Precipitation file input source directory:  ' // cfg%precdir
  end if

  if(cfg%flagE0file==1) then
    call assert_directory_exists(cfg%E0dir)
    print *, 'Electric field file input cadence (s):  ',cfg%dtE0
    print *, 'Electric field file input source directory:  ' // cfg%E0dir
  end if

  if (cfg%flagglow==1) then
    print *, 'GLOW enabled for auroral emission calculations.'
    print *, 'GLOW electron transport calculation cadence (s): ', cfg%dtglow
    print *, 'GLOW auroral emission output cadence (s): ', cfg%dtglowout
  end if
end if

!> CHECK THE GRID SIZE AND ESTABLISH A PROCESS GRID
call grid_size(cfg%indatsize)

select case (argc)
  case (4,5) !< user specified process grid
    call get_command_argument(3,argv)
    read(argv,*) lid2in
    call get_command_argument(4,argv)
    read(argv,*) lid3in
    call mpi_manualgrid(lx2all,lx3all,lid2in,lid3in)
    if (argc == 5) then
      call get_command_argument(5,argv)
      select case (argv)
        case ('-d', '-debug')
          debug = .true.
        case ('-nooutput')
          nooutput = .true.
      end select
    endif
  case default
    if (argc == 3) then
      call get_command_argument(3,argv)
      select case (argv)
        case ('-d', '-debug')
          debug = .true.
        case ('-nooutput')
          nooutput = .true.
      end select
    endif
    call mpigrid(lx2all,lx3all)
    !! following grid_size these are in scope
end select


!> LOAD UP THE GRID STRUCTURE/MODULE VARS. FOR THIS SIMULATION
call read_grid(cfg%indatsize,cfg%indatgrid,cfg%flagperiodic, x)
!! read in a previously generated grid from filenames listed in input file


!> CREATE/PREP OUTPUT DIRECTORY AND OUTPUT SIMULATION SIZE AND GRID DATA
!> ONLY THE ROOT PROCESS WRITES OUTPUT DATA
call get_command_argument(2,argv)
outdir = trim(argv)

if (myid==0) then
  call create_outdir(outdir,infile,cfg)
  if (cfg%flagglow/=0) call create_outdir_aur(outdir)
end if


!> ALLOCATE ARRAYS (AT THIS POINT ALL SIZES ARE SET FOR EACH PROCESS SUBGRID)
allocate(ns(-1:lx1+2,-1:lx2+2,-1:lx3+2,lsp),vs1(-1:lx1+2,-1:lx2+2,-1:lx3+2,lsp),vs2(-1:lx1+2,-1:lx2+2,-1:lx3+2,lsp), &
  vs3(-1:lx1+2,-1:lx2+2,-1:lx3+2,lsp), Ts(-1:lx1+2,-1:lx2+2,-1:lx3+2,lsp))
allocate(rhov2(-1:lx1+2,-1:lx2+2,-1:lx3+2),rhov3(-1:lx1+2,-1:lx2+2,-1:lx3+2),B1(-1:lx1+2,-1:lx2+2,-1:lx3+2), &
         B2(-1:lx1+2,-1:lx2+2,-1:lx3+2),B3(-1:lx1+2,-1:lx2+2,-1:lx3+2))
allocate(v1(-1:lx1+2,-1:lx2+2,-1:lx3+2),v2(-1:lx1+2,-1:lx2+2,-1:lx3+2), &
         v3(-1:lx1+2,-1:lx2+2,-1:lx3+2),rhom(-1:lx1+2,-1:lx2+2,-1:lx3+2))
allocate(E1(lx1,lx2,lx3),E2(lx1,lx2,lx3),E3(lx1,lx2,lx3),J1(lx1,lx2,lx3),J2(lx1,lx2,lx3),J3(lx1,lx2,lx3))
allocate(nn(lx1,lx2,lx3,lnchem),Tn(lx1,lx2,lx3),vn1(lx1,lx2,lx3), vn2(lx1,lx2,lx3),vn3(lx1,lx2,lx3))
call make_dneu()
!! allocate space for neutral perturbations in case they are used with this run
call make_precip_fileinput()


!> ALLOCATE MEMORY FOR ROOT TO STORE CERTAIN VARS. OVER ENTIRE GRID
if (myid==0) then
  allocate(Phiall(lx1,lx2all,lx3all))
end if

!> ALLOCATE MEMORY FOR AURORAL EMISSIONS, IF CALCULATED
if (cfg%flagglow/=0) then
  allocate(iver(lx2,lx3,lwave))
end if


!> LOAD ICS AND DISTRIBUTE TO WORKERS (REQUIRES GRAVITY FOR INITIAL GUESSING)
call input_plasma(x%x1,x%x2all,x%x3all,cfg%indatsize,cfg%indatfile,ns,vs1,Ts)

!ROOT/WORKERS WILL ASSUME THAT THE MAGNETIC FIELDS AND PERP FLOWS START AT ZERO
!THIS KEEPS US FROM HAVING TO HAVE FULL-GRID ARRAYS FOR THESE STATE VARS (EXCEPT
!FOR IN OUTPUT FNS.).  IF A SIMULATIONS IS DONE WITH INTERTIAL CAPACITANCE THERE
!WILL BE A FINITE AMOUNT OF TIME FOR THE FLOWS TO 'START UP', BUT THIS SHOULDN'T
!BE TOO MUCH OF AN ISSUE.  WE ALSO NEED TO SET THE BACKGROUND MAGNETIC FIELD STATE
!VARIABLE HERE TO WHATEVER IS SPECIFIED IN THE GRID STRUCTURE (THESE MUST BE CONSISTENT)
rhov2=0d0; rhov3=0d0; v2=0d0; v3=0d0;
B2=0d0; B3=0d0;
B1(1:lx1,1:lx2,1:lx3)=x%Bmag
!! this assumes that the grid is defined s.t. the x1 direction corresponds
!! to the magnetic field direction (hence zero B2 and B3).


!> INITIALIZE ELECTRODYNAMIC QUANTITIES FOR POLARIZATION CURRENT
if (myid==0) Phiall = 0
!! only root stores entire potential array
E1=0; E2=0; E3=0;
vs2=0; vs3=0;

!> INITIALIZE AURORAL EMISSION MAP
if(cfg%flagglow/=0) iver=0


!> MAIN LOOP
UTsec=cfg%UTsec0; it=1; t=0; tout=t; tglowout=t;
do while (t < cfg%tdur)
  !! TIME STEP CALCULATION
  dtprev=dt
  call dt_comm(t,tout,tglowout,cfg%flagglow,cfg%tcfl,ns,Ts,vs1,vs2,vs3,B1,B2,B3,x,cfg%potsolve,dt)
  if (it>1) then
    if(dt/dtprev > dtscale) then
      !! throttle how quickly we allow dt to increase
      dt=dtscale*dtprev
      if (myid==0) then
        print '(A,EN14.3)', 'Throttling dt to:  ',dt
      end if
    end if
  end if


  !COMPUTE BACKGROUND NEUTRAL ATMOSPHERE USING MSIS00.  PRESENTLY THIS ONLY GETS CALLED
  !ON THE FIRST TIME STEP DUE TO A NEED TO KEEP A CONSTANT BACKGROUND (I.E. ONE NOT VARYING
  !IN TIME) FOR SOME SIMULATIONS USING NEUTRAL INPUT.  REALISTICALLY THIS NEEDS TO BE
  !RECALLED EVERY SO OFTEN (MAYBE EVERY 10-15 MINS)
  if (it==1) then
    call cpu_time(tstart)
    call neutral_atmos(cfg%ymd,UTsec,x%glat,x%glon,x%alt,cfg%activ,nn,Tn)
    vn1=0d0; vn2=0d0; vn3=0d0
    !! hard-code these to zero for the first time step
    if (myid==0) then
      call cpu_time(tfin)
      print *, 'Neutral background calculated in time:  ',tfin-tstart
    end if
  end if


  !> GET NEUTRAL PERTURBATIONS FROM ANOTHER MODEL
  if (cfg%flagdneu==1) then
    call cpu_time(tstart)
    if (it==1) then
      !! this triggers the code to load the neutral frame correspdonding ot the beginning time of the simulation
      if (myid==0) print *, '!!!Attempting initial load of neutral dynamics files!!!' // &
                              ' This is a workaround that fixes the restart code...',t-dt
      call neutral_perturb(cfg%interptype,dt,cfg%dtneu,t-cfg%dtneu,cfg%ymd,UTsec-cfg%dtneu, &
        cfg%sourcedir,cfg%dxn,cfg%drhon,cfg%dzn, &
        cfg%sourcemlat,cfg%sourcemlon,x,nn,Tn,vn1,vn2,vn3)
    end if
    call neutral_perturb(cfg%interptype,dt,cfg%dtneu,t,cfg%ymd,UTsec,cfg%sourcedir,cfg%dxn,cfg%drhon,cfg%dzn,cfg%sourcemlat, &
      cfg%sourcemlon,x,nn,Tn,vn1,vn2,vn3)
    if (myid==0 .and. debug) then
      call cpu_time(tfin)
      print *, 'Neutral perturbations calculated in time:  ',tfin-tstart
    endif
  end if

  !! POTENTIAL SOLUTION
  call cpu_time(tstart)
  call electrodynamics(it,t,dt,nn,vn2,vn3,Tn, cfg%sourcemlat,ns,Ts,vs1,B1,vs2,vs3,x, &
                        cfg%potsolve, cfg%flagcap,E1,E2,E3,J1,J2,J3, &
                        Phiall, cfg%flagE0file, cfg%dtE0, cfg%E0dir, cfg%ymd,UTsec)
  if (myid==0 .and. debug) then
    call cpu_time(tfin)
    print *, 'Electrodynamics total solve time:  ',tfin-tstart
  endif

  !! UPDATE THE FLUID VARIABLES
  if (myid==0 .and. debug) call cpu_time(tstart)
  call fluid_adv(ns,vs1,Ts,vs2,vs3,J1,E1,cfg%Teinf,t,dt,x,nn,vn1,vn2,vn3,Tn,iver,cfg%activ(2),cfg%activ(1),cfg%ymd,UTsec, &
    cfg%flagprecfile,cfg%dtprec,cfg%precdir,cfg%flagglow,cfg%dtglow)
  if (myid==0 .and. debug) then
    call cpu_time(tfin)
    print *, 'Multifluid total solve time:  ',tfin-tstart
  endif

  !! NOW OUR SOLUTION IS FULLY UPDATED SO UPDATE TIME VARIABLES TO MATCH...
  it=it+1; t=t+dt;
  if (myid==0 .and. debug) print *, 'Moving on to time step (in sec):  ',t,'; end time of simulation:  ',cfg%tdur
  call dateinc(dt,cfg%ymd,UTsec)

  if (myid==0 .and. modulo(it,10) == 0) then
    !! print every 10th time step to avoid extreme amounts of console printing
    print '(A,I4,A1,I0.2,A1,I0.2,A1,F12.6,A5,F8.6)', 'Current time ',cfg%ymd(1),'-',cfg%ymd(2),'-',cfg%ymd(3),' ',UTsec,'; dt=',dt
  endif

  !! OUTPUT
  if (abs(t-tout) < 1d-5) then
    tout = tout + cfg%dtout
    if (nooutput) then
      write(stderr,*) 'WARNING: skipping file output at sim time (sec)',t
      cycle
    endif
    !! close enough to warrant an output now...
    if (myid==0 .and. debug) call cpu_time(tstart)
    call output_plasma(outdir,cfg%flagoutput,cfg%ymd,UTsec,vs2,vs3,ns,vs1,Ts,Phiall,J1,J2,J3, cfg%out_format)

    if (myid==0 .and. debug) then
      call cpu_time(tfin)
      print *, 'Plasma output done for time step:  ',t,' in cpu_time of:  ',tfin-tstart
    endif
  end if

  !! GLOW OUTPUT
  if ((cfg%flagglow/=0).and.(abs(t-tglowout) < 1d-5)) then !same as plasma output
    call cpu_time(tstart)
    call output_aur(outdir,cfg%flagglow,cfg%ymd,UTsec,iver, cfg%out_format)
    if (myid==0) then
      call cpu_time(tfin)
      print *, 'Auroral output done for time step:  ',t,' in cpu_time of: ',tfin-tstart
    end if
    tglowout = tglowout + cfg%dtglowout
  end if
end do


!! DEALLOCATE MAIN PROGRAM DATA
deallocate(ns,vs1,vs2,vs3,Ts)
deallocate(E1,E2,E3,J1,J2,J3)
deallocate(nn,Tn,vn1,vn2,vn3)

if (myid==0) deallocate(Phiall)

if (cfg%flagglow/=0) deallocate(iver)

!! DEALLOCATE MODULE VARIABLES (MAY HAPPEN AUTOMATICALLY IN F2003???)
call clear_grid(x)
call clear_dneu()
call clear_precip_fileinput()
call clear_potential_fileinput()


!! SHUT DOWN MPI
ierr = mpibreakdown()

if (ierr /= 0) then
  write(stderr, *) 'GEMINI: abnormal MPI shutdown code', ierr, 'Process #', myid,' /',lid-1
  error stop
endif

call date_and_time(date,time)
print '(/,A,I6,A,I6,3A)', 'GEMINI normal termination, Process #', myid,' /',lid-1, ' at ',date,time

end program
