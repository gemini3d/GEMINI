use phys_consts, only: wp,pi
use interpolation, only : interp2
use h5fortran, only : hdf5_file

implicit none

type(hdf5_file) :: hout
integer, parameter :: lx1=50, lx2=100, lx1i=500, lx2i=1000
!integer, parameter :: lx1=1000, lx2=1000
!integer, parameter :: lx1i=8000, lx2i=8000
real(wp), parameter :: stride=0.5_wp

real(wp) :: x1(lx1), x2(lx2), f(lx1,lx2),x1i(lx1i), x2i(lx2i), fi(lx1i,lx2i)
real(wp), dimension(1:lx1i*lx2i) :: x1ilist, x2ilist,filist

integer :: ix1,ix2,ik



!grid for original data
x1=[ ((real(ix1,wp)-1._wp)*stride, ix1=1,lx1) ]
x2=[ ((real(ix2,wp)-1._wp)*stride, ix2=1,lx2) ]


!center grid points at zero
x1=x1-sum(x1)/size(x1,1)
x2=x2-sum(x2)/size(x2,1)


!test function
do ix2=1,lx2
  f(:,ix2)=sin(2._wp*pi/5._wp*x1)*cos(2._wp*pi/50._wp*x2(ix2))
end do


!> grid for interpolated data
x1i=[ ((real(ix1,wp)-1)*stride/(lx1i/lx1), ix1=1,lx1i) ]
x2i=[ ((real(ix2,wp)-1)*stride/(lx2i/lx2), ix2=1,lx2i) ]


!> center grid points at zero
x1i=x1i-sum(x1i)/size(x1i,1)
x2i=x2i-sum(x2i)/size(x2i,1)


!> try a 2d interpolation
!fi=interp2_plaid(x1,x2,f,x1i,x2i)
do ix2=1,lx2i
  do ix1=1,lx1i
    ik=(ix2-1)*lx1i+ix1
    x1ilist(ik)=x1i(ix1)
    x2ilist(ik)=x2i(ix2)
  end do
end do
filist=interp2(x1,x2,f,x1ilist,x2ilist)
fi=reshape(filist,[lx1i,lx2i])


!! dump results to a file so we can check things
call hout%initialize("input2d.h5", status="replace", action="write")

call hout%write("/lx1", lx1)
call hout%write("/lx2", lx2)
call hout%write("/x1", x1)
call hout%write("/x2", x2)
call hout%write("/f", f)

call hout%finalize()


call hout%initialize("output2d.h5", status="replace", action="write")

call hout%write("/lx1", lx1i)
call hout%write("/lx2", lx2i)
call hout%write("/x1", x1i)
call hout%write("/x2", x2i)
call hout%write("/f", fi)

call hout%finalize()

end program


!> has no problem with > 2GB output files
! block
!   integer :: u
!   open(newunit=u,file='input2d.dat',status='replace',form='unformatted',access='stream', action='write')
!   write(u) lx1,lx2
!   write(u) x1,x2,f
!   close(u)
! end block

! block
!   integer :: u
!   open(newunit=u,file='output2d.dat',status='replace',form='unformatted',access='stream', action='write')
!   write(u) lx1i,lx2i
!   write(u) x1i,x2i,fi   !since only interpolating in x1
!   close(u)
! end block