#!/bin/sh

DIR=$(dirname "$(readlink /etc/localtime)")

# initial value
setprop persist.sys.timezone UTC
/usr/bin/droid/droid-set-timezone.sh n "$DIR" localtime

/system/bin/inotifyd /usr/bin/droid/droid-set-timezone.sh "$DIR"

