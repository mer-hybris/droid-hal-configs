#!/bin/sh

STATE=$1
DIR=$2
FILE=$3
if [ "$STATE" = "n" ]; then
	if [ "$FILE" = "localtime" ]; then
		TIMEZ=$(readlink "$DIR/$FILE" | sed "s|.*/usr/share/zoneinfo/||g")
		setprop persist.sys.timezone "$TIMEZ"
	fi
fi

exit 0

