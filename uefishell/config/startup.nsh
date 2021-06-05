@echo -off

#
# Setup the environment variables. All of them are created as volatile.
#

#
# The volume label for the RAMDISK.
#
# LABEL can be at most 11 character!
set -v VolumeLabel UEFI_INST

#
# Variable to store the file system index that will be looped
# to determine the FS<x> number for the RAMDISK that is created.
#
set -v FsIndex 0

#
# Variable to store the output string of the ramdisk -c command.
# Successful creation of RAMDISK will give the following output:
# "RAM disk 'FSx:' created successfully." where x=0,1,2,...
#
set -v RamDiskStr 0

#
# Size of the RAMDISK in MegaBytes (MB).
#
set -v RamDiskSize 512

#
# Server URL hosting the OS loader and images.
# Can be HTTP or FTP. Names or IP addresses are allowed.
# Ensure DNS service is available and configured (see pre-requisites)
# when server names are used.
#
set -v Url http://deployment.homelab.io/rhel79/x64/uefishellboot

#
# Files to be downloaded
#
set -v grubx64 grubx64.efi
set -v grubcfg grub.cfg
set -v vmlinuz vmlinuz
set -v initrd initrd.img


#
# Step 1. Create RAMDISK to store the downloaded OS programs.
#
echo "Creating a RAM Disk to save downloaded files..."
# ramdisk -c -s %RamDiskSize% -v %VolumeLabel% -t F32 >v RamDiskStr
ramdisk -c -s %RamDiskSize% -v %VolumeLabel% >v RamDiskStr
if %lasterror% ne 0x0 then
  echo "Cannot create a RAMDISK of size %RamDiskSize%."
  goto EXITSCRIPT
endif
echo "RAM Disk with Volume Label %VolumeLabel% created successfully."

#
# Step 2. Check each word in the output (RamDiskStr) and see if it matches
# the FSx: pattern. The newly created RAMDISK will be FS1: or higher.
# Here the check goes up to FS3: (the inner for loop), but a larger limit 
# may be used in case many other file systems already exist before
# the creation of this RAMDISK. The FS for the RAMDISK is found when the 
# FsIndex matches the FS<x> in RamDiskStr. Change the working directory
# to FS<FsIndex>:, so all downloads get saved there.
#
# FS0: is ignored. In the worst case, when no other usable
# file system is present, FS0: will map to the file system
# that this script is executing from.
#
#
for %a in %RamDiskStr%
  for %b run (1 10)
    set -v FsIndex %b
    if 'FS%FsIndex%:' == %a then
      FS%FsIndex%:
      goto RDFOUND
    endif
  endfor
endfor

#
# The following message appears if the newly created RAMDISK cannot be found.
#
echo "RAMDISK with Volume Label %VolumeLabel% not found!"
goto EXITSCRIPT

#
# The following message appears if the RAMDISK FS<x> has been found and you are in the
# RAMDISK's root folder.
#
:RDFOUND
echo "RAMDISK with Volume Label %VolumeLabel% found at FS%FsIndex%:."

#
# Step 3: Download the required files into the RAMDISK.
#
echo "Downloading %Url%/%grubx64% (File 1 of 4...)"
webclient -g %Url%/%grubx64% -o %grubx64%
if %lasterror% ne 0x0 then
  goto EXITSCRIPT
endif

echo "Downloading %Url%/%grubcfg% (File 2 of 4...)"
webclient -g %Url%/%grubcfg% -o %grubcfg%
if %lasterror% ne 0x0 then
  goto EXITSCRIPT
endif

echo "Downloading %Url%/pxeboot/%vmlinuz% (File 3 of 4...)"
webclient -g %Url%/pxeboot/%vmlinuz% -o %vmlinuz%
if %lasterror% ne 0x0 then
  goto EXITSCRIPT
endif

echo "Downloading %Url%/pxeboot/%initrd% (File 4 of 4...)"
webclient -g %Url%/pxeboot/%initrd% -o %initrd%
if %lasterror% ne 0x0 then
  goto EXITSCRIPT
endif


#
# Step4: Launch the boot loader.
#
echo "Starting the OS Installation..."
# %DownloadFile1% -f %DownloadFile2% initrd=%DownloadFile3%
%grubx64% 

#
# You reach here only if the downloads and booting failed.
#
:EXITSCRIPT
echo "Exiting Script."
