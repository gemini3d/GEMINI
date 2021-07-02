module h5fortran
!! this is a dummy interface that errors intentionally

implicit none (type, external)

type hdf5_file
contains
procedure, public :: open, read, write, exist, exists, ndims, close
end type hdf5_file

contains

subroutine open(self,filename,ierr, status,action,comp_lvl,chunk_size,verbose)
class(hdf5_file), intent(inout)    :: self
character(*), intent(in)           :: filename
integer, intent(out), optional     :: ierr
character(*), intent(in), optional :: status
character(*), intent(in), optional :: action
integer, intent(in), optional      :: comp_lvl
class(*), intent(in), optional     :: chunk_size(7)
logical, intent(in), optional      :: verbose
error stop 'HDF5 / h5fortran not available'
end subroutine open

subroutine read(self, dname, value, ierr)
class(hdf5_file), intent(in)     :: self
character(*), intent(in)         :: dname
class(*), intent(inout)      :: value(..)
integer, intent(out), optional :: ierr
error stop 'HDF5 / h5fortran not available'
end subroutine read

subroutine write(self, dname, value, ierr)
class(hdf5_file), intent(in)     :: self
character(*), intent(in)         :: dname
class(*), intent(in)      :: value(..)
integer, intent(out), optional :: ierr
error stop 'HDF5 / h5fortran not available'
end subroutine write

logical function exist(self, dname)
class(hdf5_file), intent(in)     :: self
character(*), intent(in)         :: dname
exist = .false.
error stop 'HDF5 / h5fortran not available'
end function exist

logical function exists(self, dname)
class(hdf5_file), intent(in)     :: self
character(*), intent(in)         :: dname
exists = .false.
error stop 'HDF5 / h5fortran not available'
end function exists

integer function ndims(self, dname)
class(hdf5_file), intent(in) :: self
character(*), intent(in) :: dname
ndims = 0
error stop 'HDF5 / h5fortran not available'
end function ndims

subroutine close(self, ierr)
class(hdf5_file), intent(in) :: self
integer, intent(out), optional :: ierr
error stop 'HDF5 / h5fortran not available'
end subroutine close

end module h5fortran
