#!/usr/bin/env bash

# Copyright (c) 2021, Jolla Ltd.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# * Neither the name of the <organization> nor the
# names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.
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


# Flash operations:
#
#   getvar_fail_if <variable-name> <variable-value>
#     If variable-name equals variable-value abort flashing
#     Custom error message can be set in GETVAR_ERROR_<variable-name>
#
#   flash <partition> <image>
#     Flash image to partition
#
#   flash_dont_fail <partition> <image>
#     Try to flash image to partition but retry 30 times before giving up,
#     sleep 1 second between retries
#
#   flash_blob <partition> <image>
#     Flash extra blob image to partition. This is a bit different from
#     regular flash operation, as image part can contain wildcards and
#     custom error messages can be set for not existing or too many files
#     in BLOB_ERROR_NOT_FOUND_<partition> and BLOB_ERROR_TOO_MANY_<partition>
#     variables, respectively.
#
#   run <commands>
#     Run arbitrary commands, for example run sleep 5
#
#   run fastboot <commands>
#     Run arbitrary fastboot commands
#
#
#
# Example flash-config.sh:
#
# VALID_PRODUCTS=(
# "product-name"
# )
#
# FLASH_OPS=(
# "getvar_fail_if secure yes"
# "run fastboot reboot-bootloader
# "run fastboot erase foo
# "run sleep 2"
# "flash_dont_fail partition partition.bin"
# "flash boot_a hybris-boot.img"
# "flash boot_b hybris-boot.img"
# "flash dtbo_a dtbo.img"
# "flash dtbo_b dtbo.img"
# "flash userdata userdata.img001"
# "flash_blob oem_a *_vendor_image.img"
# )
#
# GETVAR_ERROR_secure="
# Error to display if variable secure has value yes
# "
#
# BLOB_ERROR_NOT_FOUND_oem_a="
# Error to display if vendor blob is not found.
# "
#
# BLOB_ERROR_TOO_MANY_oem_a="
# Error to display if more than one matching blob is found when using wildcards
# "
#
# FLASH_COMPLETED_MESSAGE="
# Message to show with successful flashing.
# "

SCRIPT_VERSION=1.2

OS_VERSION=
FASTBOOT_BIN_PATH=
# Detect from fastboot command
FLASHCMD_FLASH_BOOT=
USB_AUTOSUSPEND=
USB_AUTOSUSPEND_PATH=/sys/module/usbcore/parameters/autosuspend

DRY_RUN=1

if [ -z "$FLASH_CONFIG" ]; then
    FLASH_CONFIG="./flash-config.sh"
fi

check_fastboot() {
    FASTBOOT_BIN_NAME=$1
    if [ -f "$FASTBOOT_BIN_NAME" ]; then
        chmod 755 "$FASTBOOT_BIN_NAME"
        # Ensure that the binary that is found can be executed fine
        if ./"$FASTBOOT_BIN_NAME" help &>/dev/null; then
            FASTBOOT_BIN_PATH="./"
            return 0
        fi
    fi
    return 1
}

print_and_run() {
    # shellcheck disable=SC2145
    echo ">> $@"

    # shellcheck disable=SC2068
    $@
    local ret=$?

    if [ $ret -ne 0 ]; then
        echo "Flashing failed ($ret)"
        exit $ret
    fi
}

print_and_run_retry() {
    # shellcheck disable=SC2145
    echo ">> $@"

    local retries=30
    local ret=1
    while [ $ret -ne 0 ]; do
        # shellcheck disable=SC2068
        $@
        ret=$?

        if [ $ret -ne 0 ]; then
            if [ $retries -eq 0 ]; then
                echo "Retry limit reached, flashing failed ($ret)"
                exit 1
            fi

            sleep 1
        fi

        ((--retries))
    done
}

restore_autosuspend() {
    if [ -z "$USB_AUTOSUSPEND" ]; then
        return
    fi

    echo "$USB_AUTOSUSPEND" > $USB_AUTOSUSPEND_PATH
}

usage() {
    cat <<EOF
Flash utility v$SCRIPT_VERSION

This script uses either flash-config.sh from the directory where the
script is ran or defined by --config.

Options
  --help          This help
  --force         Don't abort if md5sums of files don't match
  --fastboot      Location of fastboot binary to use
  --image-path    Where regular image files are located
  --blob-path     Where possible vendor specific image files are located
  --extra-opts    Custom extra options for fastboot
  --config        Specify location for flash ops
  --dry-run       Only dry run, don't do any changes to device

EOF
}

#
# Command line arguments
#

while [ $# -gt 0 ]; do
    case $1 in
        --force)
            FORCE=1
            ;;
        --fastboot)
            shift
            FASTBOOT_BIN_NAME="$1"
            ;;
        --image-path)
            shift
            IMAGE_PATH="$1"
            ;;
        --blob-path)
            shift
            BLOB_PATH="$1"
            ;;
        --extra-opts)
            shift
            FASTBOOTEXTRAOPTS="$1"
            ;;
        --config)
            shift
            FLASH_CONFIG="$1"
            ;;
        --dry-run)
            ONLY_DRY_RUN=1
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument '$1'"
            exit 1
            ;;
    esac
    shift
done

if [ ! -f "$FLASH_CONFIG" ]; then
    echo "Configuration file ($FLASH_CONFIG) for flash script not found."
    exit 1
fi

source "$FLASH_CONFIG"

if [ ${#FLASH_OPS[@]} -eq 0 ]; then
    echo "No flash operations defined in $FLASH_CONFIG"
    exit 1
fi

UNAME=$(uname)

# Do not need root for fastboot on Mac OS X
if [ "$UNAME" != "Darwin" ] && [ "$(id -u)" -ne 0 ]; then
    exec sudo -E bash -c "FORCE=$FORCE FASTBOOT_BIN_NAME=\"$FASTBOOT_BIN_NAME\" IMAGE_PATH=\"$IMAGE_PATH\" BLOB_PATH=\"$BLOB_PATH\" FASTBOOTEXTRAOPTS=\"$FASTBOOTEXTRAOPTS\" FLASH_CONFIG=\"$FLASH_CONFIG\" ONLY_DRY_RUN=$ONLY_DRY_RUN $0"
fi

echo "Flash utility v$SCRIPT_VERSION"

case $UNAME in
    Linux)
        echo "Detected Linux"
        ;;
    Darwin)
        IFS='.' read -r major minor patch <<< "$(sw_vers -productVersion)"
        OS_VERSION=$major-$minor
        echo "Detected Mac OS X - Version: $OS_VERSION"
        ;;
    FreeBSD)
        FASTBOOT_BIN_PATH="/usr/local/bin/"
        echo "Detected FreeBSD"
        ;;
    *)
        echo "Failed to detect operating system!"
        exit 1
        ;;
esac


if [ -z "$FASTBOOT_BIN_NAME" ]; then
    if ! check_fastboot "fastboot-$UNAME-$OS_VERSION" ; then
        if ! check_fastboot "fastboot-$UNAME"; then
            # In case we didn't provide functional fastboot binary to the system
            # lets check that one is found from the system.
            if ! which fastboot &>/dev/null; then
                echo "No 'fastboot' found in \$PATH. To install, use:"
                echo ""
                echo "    Debian/Ubuntu/.deb distros:  apt-get install android-tools-fastboot"
                echo "    Fedora:  yum install android-tools"
                echo "    OS X:    brew install android-sdk"
                echo "    FreeBSD: pkg install android-tools-fastboot"
                echo ""
                exit 1
            else
                FASTBOOT_BIN_NAME=fastboot
            fi
        fi
    fi
fi

# Store current autosuspend value and set to -1 to disable
if [ -f $USB_AUTOSUSPEND_PATH ]; then
    USB_AUTOSUSPEND="$(cat $USB_AUTOSUSPEND_PATH)"
    echo -1 > $USB_AUTOSUSPEND_PATH
    trap restore_autosuspend EXIT
fi

if [ -z "$FLASHCMD_FLASH_BOOT" ]; then
    ### Detect fastboot flash commands

    # By default use "flash" for boot partition
    FLASHCMD_FLASH_BOOT="flash"

    # If running fastboot version 30 or newer, use flash:raw for boot
    if ${FASTBOOT_BIN_PATH}${FASTBOOT_BIN_NAME} help 2>&1 | grep -q "flash:raw PARTITION"; then
        FLASHCMD_FLASH_BOOT="flash:raw"
    fi
fi

echo "Searching device to flash.."
FASTBOOTCMD_NO_DEVICE="${FASTBOOT_BIN_PATH}${FASTBOOT_BIN_NAME}"

FASTBOOT_DEVICES=$($FASTBOOTCMD_NO_DEVICE devices | awk '{ print $1 }' | tr $'\n' ' ')

if [ -z "$FASTBOOT_DEVICES" ]; then
    echo "No device that can be flashed found. Please connect your device in fastboot mode before running this script."
    exit 1
fi

TARGET_SERIALNO=
count=0
for SERIALNO in $FASTBOOT_DEVICES; do
    PRODUCT=$($FASTBOOTCMD_NO_DEVICE -s "$SERIALNO" getvar product 2>&1 | head -n1 | cut -d ' ' -f2)
    BASEBAND=$($FASTBOOTCMD_NO_DEVICE -s "$SERIALNO" getvar version-baseband 2>&1 | head -n1 | cut -d ' ' -f2)
    BOOTLOADER=$($FASTBOOTCMD_NO_DEVICE -s "$SERIALNO" getvar version-bootloader 2>&1 | head -n1 | cut -d ' ' -f2)

    echo "Found $PRODUCT, serial:$SERIALNO, baseband:$BASEBAND, bootloader:$BOOTLOADER"

    for VALID_PRODUCT in "${VALID_PRODUCTS[@]}"; do
        if echo "$PRODUCT" | grep -qe "^$VALID_PRODUCT$"; then
            TARGET_SERIALNO="$SERIALNO $TARGET_SERIALNO"
            ((++count))
        fi
    done
done
TARGET_SERIALNO=${TARGET_SERIALNO%% }

FASTBOOTCMD="${FASTBOOT_BIN_PATH}${FASTBOOT_BIN_NAME}"

if [ -n "$FASTBOOTEXTRAOPTS" ]; then
    echo "Fastboot extra options detected: $FASTBOOTEXTRAOPTS, let's ignore device count check."
    FASTBOOTCMD="$FASTBOOTCMD $FASTBOOTEXTRAOPTS"
elif [ $count -eq 0 ]; then
    echo "No valid devices found."
    exit 1
elif [ $count -gt 1 ]; then
    echo "More than one flashable device connected. Make sure there is exactly one device connected in fastboot mode."
    exit 1
else
    echo "Found matching device with serial $TARGET_SERIALNO"
    FASTBOOTCMD="$FASTBOOTCMD -s $TARGET_SERIALNO"
fi

echo "Fastboot command: $FASTBOOTCMD"

if [ "$UNAME" = "Darwin" ] || [ "$UNAME" = "FreeBSD" ]; then
    # macOS and FreeBSD don't have md5sum so lets use md5 there.
    while read -r line; do
        md5=$(echo "$line" | awk '{ print $1 }')
        filename=$(echo "$line" | awk '{ print $2 }')
        md5calc=$(md5 "$filename" | cut -d '=' -f2 | tr -d '[:space:]')
        if [ "$md5" != "$md5calc" ]; then
            if [ -n "$FORCE" ]; then
                echo "Ignoring md5sum errors (--force)"
            else
                echo; echo "md5sum does not match on file $filename, please download the package again."
                echo;
                exit 1;
            fi
        fi
    done < md5.lst
else
    if [ "$(md5sum -c md5.lst --status;echo $?)" -eq "1" ]; then
        if [ -n "$FORCE" ]; then
            echo "Ignoring md5sum errors (--force)"
        else
            echo; echo "md5sum does not match, please download the package again."
            echo;
            exit 1;
        fi
    fi
fi

#
# flash ops
#

flash_image() {
    local partition="$1"
    local image_file="$2"
    local exit_on_failure="$3"

    if [ -n "$IMAGE_PATH" ]; then
        image_file="$IMAGE_PATH/$image_file"
    fi

    if [ ! -e "$image_file" ]; then
        echo "Image file '$image_file' not found."
        exit 1
    fi

    if [ $DRY_RUN -eq 0 ]; then
        local flashcmd="flash"
        if [ "$partition" == "boot" ] || [ "$partition" == "boot_a" ] || [ "$partition" == "boot_b" ]; then
            flashcmd=$FLASHCMD_FLASH_BOOT
        fi

        if [ "$exit_on_failure" -eq 1 ]; then
            print_and_run "$FASTBOOTCMD" $flashcmd "$partition" "$image_file"
        else
            print_and_run_retry "$FASTBOOTCMD" $flashcmd "$partition" "$image_file"
        fi
    fi
}

flash_blob() {
    local partition="$1"
    local image_file="$2"

    local b_path="$BLOB_PATH"
    if [ -z "$b_path" ]; then
        b_path="."
    fi

    local count=0

    while IFS= read -r -d '' b; do
        if [ $DRY_RUN -eq 0 ]; then
            print_and_run "$FASTBOOTCMD" flash "$partition" "$b"
        fi
        ((++count))
    done < <(find "$b_path" -maxdepth 1 -name "$image_file" -print0)

    if [ $count -eq 0 ]; then
        eval echo -e \"\$BLOB_ERROR_NOT_FOUND_$partition\"
        exit 1
    fi

    if [ $count -gt 1 ]; then
        eval echo -e \"\$BLOB_ERROR_TOO_MANY_$partition\"
        exit 1
    fi
}

getvar_test() {
    local var_name="$1"
    local getvar_fail="$2"

    # Only test vars during dry run
    if [ $DRY_RUN -eq 0 ]; then
        return
    fi

    echo ">> $FASTBOOTCMD getvar $var_name"
    local val_line
    val_line="$($FASTBOOTCMD getvar "$var_name" 2>&1 | head -n1)"
    echo "<< $val_line"
    local val
    val="$(echo "$val_line" | awk '{ print $2 }')"

    if [ "$val" == "FAILED" ]; then
        # getvar:foo  FAILED (remote: ERROR_MESSAGE)
        exit 1
    elif [ "$val" == "$getvar_fail" ]; then
        eval echo -e \"\$GETVAR_ERROR_$var_name\"
        exit 1
    fi
}

run_flash_op() {
    local op="$1"
    local arg1="$2"
    local arg2="$3"

    case "$op" in
        flash)
            flash_image "$arg1" "$arg2" 1
            ;;

        flash_dont_fail)
            flash_image "$arg1" "$arg2" 0
            ;;

        flash_blob)
            flash_blob "$arg1" "$arg2"
            ;;

        getvar_fail_if)
            getvar_test "$arg1" "$arg2"
            ;;

        run)
            if [ $DRY_RUN -eq 0 ]; then
                case "$arg1" in
                    fastboot)
                        shift
                        shift
                        print_and_run "$FASTBOOTCMD" "$@"
                        ;;

                    *)
                        shift
                        shift
                        print_and_run "$arg1" "$@"
                        ;;
                esac
            fi
            ;;

        *)
            echo "Unknown flash operation '$op'"
            exit 1
            ;;
    esac
}

run_flash_ops() {
    for flash_op in "${FLASH_OPS[@]}"; do
        read var_op var_arg1 var_arg2 <<< "$flash_op"
        run_flash_op "$var_op" "$var_arg1" "$var_arg2"
    done
}

DRY_RUN=1
run_flash_ops

if [ -z "$ONLY_DRY_RUN" ]; then
    DRY_RUN=0
    run_flash_ops
fi

echo
echo "Flashing completed."

if [ -n "$FLASH_COMPLETED_MESSAGE" ]; then
    echo -e "$FLASH_COMPLETED_MESSAGE"
fi
