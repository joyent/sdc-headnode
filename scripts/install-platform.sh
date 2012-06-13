#!/bin/bash
#
# Copyright (c) 2012, Joyent Inc., All rights reserved.
#

function usage()
{
    echo "Usage: $0 <platform URI>"
    echo "(URI can be file:///, http://, anything curl supports or a filename)"
    exit 1
}

function fatal()
{
	printf "Error: %s\n" "$1" >/dev/stderr
        exit 1
}

input=$1
if [[ -z ${input} ]]; then
    usage
fi

if echo "${input}" | grep "^[a-z]*://"; then
    # input is a url style pattern
    /bin/true
else
    if [[ -f ${input} ]]; then
       dir=$(cd $(dirname ${input}); pwd)
       file=$(basename ${input})
       input="file://${dir}/${file}"
    else
       fatal "file: '${input}' not found."
    fi
fi

mounted="false"
usbmnt="/mnt/$(svcprop -p 'joyentfs/usb_mountpoint' svc:/system/filesystem/smartdc:default)"
usbcpy="$(svcprop -p 'joyentfs/usb_copy_path' svc:/system/filesystem/smartdc:default)"

. /lib/sdc/config.sh
load_sdc_config

if [[ -z $(mount | grep ^${usbmnt}) ]]; then
    echo "==> Mounting USB key"
    /usbkey/scripts/mount-usb.sh
    mounted="true"
fi

platform_type=smartos

# this should result in something like 20110318T170209Z
version=$(basename "${input}" .tgz | tr [:lower:] [:upper:] | sed -e "s/.*\-\(2.*Z\)$/\1/")
if [[ -n $(echo $(basename "${input}") | grep -i "HVM-${version}" 2>/dev/null) ]]; then
    version="HVM-${version}"
    platform_type=hvm
fi

if [[ ! -d ${usbmnt}/os/${version} ]]; then
    echo "==> Staging ${version}"
    curl --progress -k ${input} -o ${usbcpy}/os/tmp.$$.tgz
    [ $? != 0 ] && fatal "retrieving $input"

    [[ ! -f ${usbcpy}/os/tmp.$$.tgz ]] && fatal "file: '${input}' not found."
    
    echo "==> Unpacking ${version} to ${usbmnt}/os"
    echo "==> This may take a while..."
    mkdir -p ${usbmnt}/os/${version}
    [ $? != 0 ] && fatal "unable to mkdir ${usbmnt}/os/${version}"
    (cd ${usbmnt}/os/${version} \
      && gzcat ${usbcpy}/os/tmp.$$.tgz | tar -xf - 2>/tmp/install_platform.log)
    [ $? != 0 ] && fatal "unpacking image into ${usbmnt}/os/${version}"

    (cd ${usbmnt}/os/${version} && mv platform-* platform)
    [ $? != 0 ] && fatal "moving image in ${usbmnt}/os/${version}"

    rm -f ${usbcpy}/os/tmp.$$.tgz

    if [[ -f ${usbmnt}/os/${version}/platform/root.password ]]; then
         mv -f ${usbmnt}/os/${version}/platform/root.password \
             ${usbmnt}/private/root.password.${version}
    fi
fi

if [[ ! -d ${usbcpy}/os/${version} ]]; then
    echo "==> Copying ${version} to ${usbcpy}/os"
    mkdir -p ${usbcpy}/os
    [ $? != 0 ] && fatal "mkdir ${usbcpy}/os"
    (cd ${usbmnt}/os && rsync -a ${version}/ ${usbcpy}/os/${version})
    [ $? != 0 ] && fatal "copying image to ${usbmnt}/os"
fi

if [[ ${mounted} == "true" ]]; then
    echo "==> Unmounting USB Key"
    umount /mnt/usbkey
fi

echo "==> Adding to list of available platforms"

# XXX 

echo "==> Done!"

exit 0
