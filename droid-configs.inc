# dcd_path is the base when run from hadk
# dcd_common is the common stuff (!) and dcd_sparse is the common sparse
%define dcd_path hybris/droid-configs
%define dcd_common %{dcd_path}/droid-configs-device
%define dcd_sparse droid-configs-device/sparse

Name:	    droid-config-%{device}
Provides:   droid-configs
Summary:    Config packages for Droid HAL adaptations
Version:    1
Release:    1
Group:      Configs
License:    GPLv2
Source0:    %{name}-%{version}.tar.bz2
BuildRequires: ssu-kickstart-configuration-jolla
BuildRequires: pkgconfig(android-headers)
BuildRequires: droid-hal
BuildRequires: droid-hal-devel
BuildRequires: repomd-pattern-builder

%description
%{summary}.

%package    ssu-kickstarts
Summary:    Kickstarts for Droid HAL
Provides:   image-configurations

%description ssu-kickstarts
%{summary}.

################################################################
%package patterns
Summary:    Repository patterns for %{rpm_device} hw
Provides:   package-groups

%description patterns
%{summary}.

################################################################
%package policy-settings
Summary:    Policy settings for %{rpm_device} hw
Requires:   ohm >= 1.1.16
Requires:   ohm-plugins-misc
Requires:   ohm-plugins-dbus
Requires:   ohm-plugin-telephony
Requires:   ohm-plugin-signaling
Requires:   ohm-plugin-media
Requires:   ohm-plugin-accessories
Requires:   ohm-plugin-resolver
Requires:   ohm-plugin-ruleengine
Requires:   ohm-plugin-profile
Requires:   pulseaudio-modules-nemo-common >= 4.0.11
Requires:   pulseaudio-policy-enforcement >= 4.0.8
Requires:   policy-settings-common >= 0.2.0
Obsoletes:  ohm-config <= 1.1.15
# ohm-configs-default should not be installed ever, thus no version
# specification defined here.
Obsoletes:  ohm-configs-default
Provides:   ohm-configs > 1.1.15
Provides:   policy-settings

%description policy-settings
%{summary}.

################################################################
%package kickstart-configuration
Summary:    Kickstart configuration for %{rpm_device}
Requires:   ssu-kickstart-configuration-jolla
Provides:   droid-hal-kickstart-configuration

%description kickstart-configuration
%{summary}.

################################################################
%package preinit-plugin
Summary:    Preinit plugins for %{rpm_device}
Provides:   preinit-plugins

%description preinit-plugin
%{summary}.

################################################################
%package pulseaudio-settings
Summary:    PulseAudio settings for %{rpm_device} hw
Requires:   pulseaudio >= 4.0
Requires:   pulseaudio-modules-nemo-parameters >= 4.0.11
Requires:   pulseaudio-modules-nemo-stream-restore >= 4.0.11
Requires:   pulseaudio-modules-nemo-mainvolume >= 4.0.11
Requires:   pulseaudio-modules-droid >= 4.0.6
Requires:   pulseaudio-policy-enforcement >= 4.0.8
Provides:   pulseaudio-settings

%description pulseaudio-settings
%{summary}.

################################################################
%package sailfish-config
Provides: droid-hal-sailfish-config
Group:	System
BuildArch:	noarch
Requires: %{name} = %{version}-%{release}
Requires: oneshot
Requires: dconf
Summary: Per device configuration for sailfish for droid-hal device: %{rpm_device}

%description sailfish-config
Configure sailfish eg naturally landscape devices like mako

################################################################

%prep
#%%setup

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
# Obtain the DEVICE from the same source as used in /etc/os-release
. /usr/lib/droid-devel/hw-release.vars

# Amalgamate configs files from device-specific and all- trees
# Retain permissions:
echo "%defattr(-,root,root,-)" > tmp/conf.files

# Add files that you will handle manually (per-device and/or per-package) to this | separated var:
EXCLUDES="/var/lib/platform-updates/flash-bootimg.sh"

# Prefer files from sparse/ in the HA specific
# area over sparse/ in the dcd area
copy_files_from() {
  config_dir=$1
  if [ -d $config_dir ]; then
    (cd $config_dir; find . \( -type f -or -type l \) -print ) | grep -vE "$EXCLUDES" | sed 's/^.//' >> tmp/conf.files
    cp -R $config_dir/* $RPM_BUILD_ROOT/
  fi
}

delete_files() {
  if [ -e delete_file.list ]; then
    egrep -v '^#' delete_file.list | (
      while read file; do
        rm -f $RPM_BUILD_ROOT/$file
      done)
  fi
}

# Copy from common; erase any we don't want; overlay from device
# specific sparse/ :
copy_files_from %{dcd_path}/%{dcd_sparse}
delete_files
copy_files_from %{dcd_path}/sparse

# Now the majority of the sparse tree is made we can handle configs
# which need some kind of substitution or generating

# packages
mkdir -p %{buildroot}/usr/share/package-groups/
/usr/bin/repomd-pattern-builder.py --patternxml -p %{dcd_common}/patterns/%{rpm_device} -p %{dcd_common}/patterns/common -p %{dcd_common}/patterns/hybris -o %{buildroot}/usr/share/package-groups/ --version=%{version} --release=%{release}

# Copy kickstart packs (for %%{rpm_device}-kickstart-configuration)
mkdir -p $RPM_BUILD_ROOT/%{_datadir}/ssu/kickstart/pack/%{rpm_device}
sed -e 's|@DEVICE@|%{rpm_device}|g' %{dcd_common}/kickstart/pack_package-droid-updater > $RPM_BUILD_ROOT/%{_datadir}/ssu/kickstart/pack/%{rpm_device}/package-droid-updater || true
sed -e 's|@DEVICE@|%{rpm_device}|g' %{dcd_path}/kickstart/pack_package-droid-updater > $RPM_BUILD_ROOT/%{_datadir}/ssu/kickstart/pack/%{rpm_device}/package-droid-updater || true

# and attachments (override if there is one)
mkdir -p $RPM_BUILD_ROOT/%{_datadir}/ssu/kickstart/attachment
cp -f %{dcd_common}/kickstart/attachment_hybris $RPM_BUILD_ROOT/%{_datadir}/ssu/kickstart/attachment/%{rpm_device}
cp -f %{dcd_path}/kickstart/attachment_hybris $RPM_BUILD_ROOT/%{_datadir}/ssu/kickstart/attachment/%{rpm_device} || true

# if we are building on Mer OBS or locally, make a domain=sales .ks
# so it works for HADK users:
%define disturl_subst %(echo %{disturl} | grep jollamobile.com)
%if "%{disturl_subst}" == ""
  echo "Setting domain to sales"
  %define ssu_override domain=sales
%else
  echo "Setting domain to jolla"
  %define ssu_override domain=jolla
%endif

# build rnd kickstarts on devel level, release kickstarts on all other levels
%if 0%{?qa_stage_devel:1}
KS_LEVELS=true %gen_ks $MER_HA_DEVICE
%else
KS_LEVELS=false %gen_ks $MER_HA_DEVICE
%endif

# Preinit plugins
ln -s /bin/false $RPM_BUILD_ROOT%{_libdir}/startup/preinit/is_total_erase_supported

# Create keyboard map file
mkdir -p $RPM_BUILD_ROOT/%{_datadir}/qt5/keymaps
/usr/lib/qt5/bin/kmap2qmap %{dcd_common}/configs/droid.kmap %{dcd_common}/configs/us.kmap $RPM_BUILD_ROOT/%{_datadir}/qt5/keymaps/droid.qmap
/usr/lib/qt5/bin/kmap2qmap %{dcd_path}/configs/droid.kmap %{dcd_path}/configs/us.kmap $RPM_BUILD_ROOT/%{_datadir}/qt5/keymaps/droid.qmap || true

################################################################
%post sailfish-config

%{_bindir}/add-oneshot dconf-update || :

################################################################
%files -f tmp/conf.files
%defattr(-,root,root,-)
%{_bindir}/droid/droid-init-done.sh
%{_bindir}/droid/kill-cgroup.sh
%{_bindir}/droid/droid-hal-startup.sh
/lib/udev/platform-device
%{_sharedstatedir}/environment/compositor/droid-hal-device.conf
%{_sharedstatedir}/environment/nemo/99-hybris.conf
%{_datadir}/qt5/keymaps/droid.qmap


%files ssu-kickstarts
%defattr(-,root,root,-)
%{_datadir}/kickstarts/*.ks

%files patterns
%defattr(-,root,root,-)
%{_datadir}/package-groups/*.xml

%files policy-settings
%defattr(644,root,root,-)

%files kickstart-configuration
%defattr(644,root,root-)
%{_datadir}/ssu/kickstart/pack/%{rpm_device}/package-droid-updater
%{_datadir}/ssu/kickstart/attachment/%{rpm_device}

%files preinit-plugin
%defattr(-,root,root,-)
%{_libdir}/startup/preinit/*

%files pulseaudio-settings
%defattr(644,root,root,-)
 
%files sailfish-config
%defattr(-,root,root,-)
%{_sysconfdir}/dconf/db/vendor.d/screen-rotation.txt
%{_sysconfdir}/dconf/db/vendor.d/locks/screen-rotation.txt
