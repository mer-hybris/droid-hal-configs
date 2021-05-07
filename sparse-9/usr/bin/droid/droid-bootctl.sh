#!/bin/sh

# Check currentl used boot slot
SLOT="$(/usr/libexec/droid-hybris/system/bin/bootctl get-current-slot)"

# Check if current slot is marked successful
/usr/libexec/droid-hybris/system/bin/bootctl is-slot-marked-successful $SLOT 2> /dev/null

if [ $? -ne 0 ]
then
    echo "Marking boot as successful"
    /usr/libexec/droid-hybris/system/bin/bootctl mark-boot-successful 2> /dev/null
fi

