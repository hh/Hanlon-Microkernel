#!/bin/sh
# put other system startup commands here, the boot process will wait until they complete.
# Use bootlocal.sh for system startup commands that can run in the background 
# and therefore not slow down the boot process.

LCL_TCE_MIRROR_DIR="/tmp/tinycorelinux/5.x/x86/tcz"
# install any kernel modules from the LCL_TCE_MIRROR_DIR and (re)start the
# module associated with them
DRIVER_MOD_DIR="/usr/local/lib/modules/`uname -r`/kernel/drivers"
DRIVER_INSMOD_DIR="/lib/modules/`uname -r`/kernel/drivers"
for map_filename in `ls ${LCL_TCE_MIRROR_DIR}/*.map`; do
  ext_filename=${map_filename%.*}
  while read line; do
    # parse the two fields out of the map file and save them in local variables
    kmod_filename=`echo "$line" | awk '{print $1}'`
    kmod_name=${kmod_filename%.*}
    kmod_target_filename=`echo "$line" | awk '{print $2}'`
    # in case it's already installed, try to remove the module we're going to install
    rmmod $kmod_name 2>&1 > /dev/null
    # use a 'mount' command to extract the specified kernel module file from
    # the specified extension file
    mkdir /tmp/$kmod_name; mount ${ext_filename} /tmp/$kmod_name -t squashfs -o loop
    # make sure the target directory exists (if it doesn't, then create it)
    target_filename="${DRIVER_MOD_DIR}/${kmod_target_filename}"
    target_path=${target_filename%/*}
    if [ ! -d ${target_path} ]; then
      mkdir -p ${target_path}
    fi
    # if the target is a gzipped kernel object and the file in the extension
    # is not, use gzip to convert it and write it out to the target, else just copy
    # it over to the target
    if [ ${kmod_filename##*.} != "gz" ] && [ ${kmod_target_filename##*.} =  "gz" ]; then
      gzip -c /tmp/${kmod_name}/${kmod_filename} > ${DRIVER_MOD_DIR}/${kmod_target_filename}
    else
      cp /tmp/${kmod_name}/${kmod_filename} ${DRIVER_MOD_DIR}/${kmod_target_filename}
    fi
    umount /tmp/$kmod_name; rmdir /tmp/$kmod_name
    # if the module already exists in the 'standard' modules directory, then overwrite it
    # with the module that was provided as part of the build
    if [ -f ${DRIVER_INSMOD_DIR}/${kmod_target_filename} ]; then
      cp ${DRIVER_MOD_DIR}/${kmod_target_filename} ${DRIVER_INSMOD_DIR}/${kmod_target_filename}
    fi
    insmod ${DRIVER_MOD_DIR}/${kmod_target_filename}
  done < ${map_filename}
done

# next, install rubygems (from the gzipped tarfile included in the ISO)
prev_wd=`pwd`
rubygems_file=`ls /opt/rubygems*.tgz | awk -F/ '{print $NF}'`
rubygems_dir=`echo $rubygems_file | cut -d'.' -f-3`
sudo mkdir /opt/tmp-install-rubygems
cd /opt/tmp-install-rubygems
sudo tar zxvf ../$rubygems_file
cd $rubygems_dir
sudo ruby setup.rb
cd $prev_wd
sudo rm -rf /opt/tmp-install-rubygems

# load the kernel modules needed to access SCSI devices
sudo /opt/load-scsi-kernel-mods.sh

# and, finally, start a few key services and initialize the Microkernel
/usr/bin/sethostname box
if [ -f /usr/local/etc/init.d/openssh ]
then
  sudo /usr/local/etc/init.d/openssh start
fi
sudo /usr/local/bin/hnl_mk_init.rb
/opt/bootlocal.sh &
