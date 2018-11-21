Summary: meta-package for @DEVICE@ configurations
Name: jolla-configuration-@DEVICE@
Version: 0.0.1
Release: 1
License: BSD-3-Clause

Requires: jolla-hw-adaptation-@DEVICE@
Requires: patterns-sailfish-applications
Requires: patterns-sailfish-ui

# For devices with cellular modem. Those without one, please comment out:
Requires: patterns-sailfish-cellular-apps
# Early stages of porting benefit from these:
Requires: sailfish-porter-tools

Requires: sailfish-content-graphics-z@ICON_RES@

# For multi-SIM devices
#Requires: jolla-settings-networking-multisim

# Introduced starting Sailfish OS 2.0.4.x:
# 3rd party accounts like Twitter, VK, cloud services, etc
Requires: jolla-settings-accounts-extensions-3rd-party-all

# Introduced starting Sailfish OS 2.1.1.26
# Required for Jolla Store Access
Requires: patterns-sailfish-consumer-generic

# For Mozilla location services (online)
Requires: geoclue-provider-mlsdb

# Sailfish OS CSD tool for hardware testing
# needs some configuration to get all features working
Requires: csd

# Devices with 2G or more memory should also include this booster
# to improve camera startup times and the like
#Requires: mapplauncherd-booster-silica-qt5-media

%description
Adaptation packages for @DEVICE@
