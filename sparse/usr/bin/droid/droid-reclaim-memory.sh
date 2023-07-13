#!/bin/sh

while [ "$(wc -l < /proc/swaps)" -lt 2 ]; do
    sleep 1
done

TASKS=$(find /sys/fs/cgroup -regex '.*system.slice.*cgroup.procs' -exec cat {} + | sort -u)

for task in $TASKS; do
    if [ -f /proc/"$task"/reclaim ]; then
        echo "all" > /proc/"$task"/reclaim
    fi
done

DONE_FILE="/tmp/.droid-reclaim-memory-ran"

if [ ! -f $DONE_FILE ]; then
    # right after first login, no user apps are running yet
    # reclaim also from the user session.
    TASKS=$(find /sys/fs/cgroup -regex '.*user.slice.*cgroup.procs' -exec cat {} + | sort -u)

    for task in $TASKS; do
        if [ -f /proc/"$task"/reclaim ]; then
            echo "all" > /proc/"$task"/reclaim
        fi
    done

    touch $DONE_FILE
fi

