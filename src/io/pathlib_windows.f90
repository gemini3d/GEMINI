submodule (pathlib) pathlib_windows

implicit none (type, external)

contains


module procedure is_absolute

character :: f

is_absolute = .false.
if(len_trim(path) < 2) return

f = path(1:1)

is_absolute = (((f >= "a" .and. f <= "z") .or. (f >= "A" .and. f <= "Z")) .and. &
  path(2:2) == ":")
!! NEED all these parentheses

end procedure is_absolute


module procedure copyfile

integer :: i,j
!! https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/copy
character(*), parameter :: CMD='copy /y '

call execute_command_line(CMD // filesep_windows(source) // ' ' // filesep_windows(dest), exitstat=i, cmdstat=j)
if (i /= 0 .or. j /= 0) error stop "could not copy " // source // " => " // dest

end procedure copyfile


module procedure mkdir
!! create a directory, with parents if needed
integer :: i,j
!! https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/md
character(*), parameter :: CMD='mkdir '

if(directory_exists(path)) return

call execute_command_line(CMD // filesep_windows(path), exitstat=i, cmdstat=j)
if (i /= 0 .or. j /= 0) error stop "could not create directory " // path

end procedure mkdir


end submodule pathlib_windows
