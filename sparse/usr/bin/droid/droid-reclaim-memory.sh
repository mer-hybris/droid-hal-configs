#!/bin/sh

while [ "$(wc -l < /proc/swaps)" -lt 2 ]; do
    sleep 1
done

TASKS=$(cat /sys/fs/cgroup/systemd/system.slice/*/cgroup.procs /sys/fs/cgroup/unified/system.slice/*/cgroup.procs /sys/fs/cgroup/system.slice/*/cgroup.procs)

for task in $TASKS; do
    echo "all" > /proc/"$task"/reclaim
done

DONE_FILE="/tmp/.droid-reclaim-memory-ran"

if [ ! -f $DONE_FILE ]; then
    # right after first login, no user apps are running yet
    # reclaim also from the user session.
    TASKS=$(cat /sys/fs/cgroup/systemd/user.slice/user-*.slice/*/cgroup.procs /sys/fs/cgroup/unified/user.slice/user-*.slice/*/cgroup.procs /sys/fs/cgroup/user.slice/user-*.slice/*/cgroup.procs)

    for task in $TASKS; do
        echo "all" > /proc/"$task"/reclaim
    done

    touch $DONE_FILE
fi

