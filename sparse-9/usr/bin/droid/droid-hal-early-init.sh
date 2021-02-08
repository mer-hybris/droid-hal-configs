#!/bin/bash

if ! grep -q hybris /system/etc/ld.config.28.txt; then
    mount -o bind /usr/libexec/droid-hybris/system/etc/ld.config.28.txt /system/etc/ld.config.28.txt
fi

