Summary: meta-package for common debugging tools used by porters
Name: sailfish-porter-tools
Version: 0.0.1
Release: 1
License: BSD-3-Clause

Requires: jolla-developer-mode
Requires: sailfishsilica-qt5-demos
Requires: libhybris-tests

Requires: busybox-static
Requires: net-tools
Requires: openssh-clients
Requires: openssh-server
Requires: vim-enhanced
Requires: zypper
Requires: strace

# jolla-rnd-device will enable usb-moded even when UI is not yet
# brought up (useful during development, available since update10)
Requires: jolla-rnd-device

%description
Common tools for debugging device adaptations
