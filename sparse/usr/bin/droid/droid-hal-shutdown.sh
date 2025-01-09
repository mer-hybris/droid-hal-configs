#!/bin/sh
# Contact: Pekka Lundstrom  <pekka.lundstrom@jollamobile.com>
#
# Copyright (c) 2013, Jolla Ltd.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the <organization> nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# The following should be in /init.rc, so init will shut everything down:
# on property:hybris.shutdown=*
#    class_stop late_start
#    class_stop main
#    class_stop core

# Kill all processes that are in this same cgroup.
# Deducing the name of the service's cgroup based on the shutdown script's
# cgroup name.
CGROUP=$(sed -r '/1:name=systemd:/!d;s|||;s|/control||' < /proc/self/cgroup)
if [ ! -f "/sys/fs/cgroup/systemd/$CGROUP/cgroup.procs" ]; then
    echo "No such cgroup: $CGROUP"
    exit 1
fi

get_pids() {
    # Get list of running pids in this cgroup, excluding this script
    # return list $PIDS and $NUM_PIDS
    PIDS=$(grep -Ev "\b$$\b" "/sys/fs/cgroup/systemd/$CGROUP/cgroup.procs")
    NUM_PIDS=$(echo "$PIDS" | wc -w)
    echo "Android service PIDs remaining: $NUM_PIDS"
}

# ============== main() ===============

get_pids
PREV_NUM_PIDS=$NUM_PIDS
# This android property is supposed to ensure a shutdown if system-server crashes
# We don't use it, but some init scripts watch for it as a signal to shut other things down
/usr/bin/setprop sys.shutdown.requested 1

echo "Shutting down droid-hal-init services..."
/usr/bin/setprop hybris.shutdown 1

sleep 1
WAIT=1
get_pids
MAX_WAIT=5
# -gt 1 because droid-hal-init is also in this cgroup
while [ $NUM_PIDS -gt 1 ] && [ $WAIT -lt $MAX_WAIT ]; do
    WAIT=$((WAIT+1))
    if [ $NUM_PIDS -lt $PREV_NUM_PIDS ]; then
        # Number of running processes is getting smaller
        # Wait a little bit more
        sleep 1
     else
        # Number of pids is not getting smaller
        break
    fi
    PREV_NUM_PIDS=$NUM_PIDS
    get_pids
done

echo "Killing droid-hal-init..."
killall droid-hal-init

get_pids
if [ $NUM_PIDS -gt 0 ]; then
    echo "Terminating remaining processes after hybris.shutdown..."
    kill -TERM $PIDS
    sleep 1
    get_pids
    if [ $NUM_PIDS -gt 0 ]; then
        echo "Killing remaining processes after hybris.shutdown..."
        kill -KILL $PIDS
    fi
fi

get_pids
exit 0

