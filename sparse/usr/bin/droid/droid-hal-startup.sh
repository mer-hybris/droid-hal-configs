#!/bin/sh
cd /
touch /dev/.coldboot_done

if [ "$(uname -m | grep -o 64)" == "64" ]; then
    # for 64 bit use the default LD_LIBRARY_PATH, otherwise we get conflicts.
    export LD_LIBRARY_PATH=
else
    # for 32 bit, this is safe
    export LD_LIBRARY_PATH=/usr/libexec/droid-hybris/system/lib/:/vendor/lib:/system/lib
fi

# Save systemd notify socket name to let droid-init-done.sh pick it up later
echo $NOTIFY_SOCKET > /run/droid-hal/notify-socket-name

exec /sbin/droid-hal-init

