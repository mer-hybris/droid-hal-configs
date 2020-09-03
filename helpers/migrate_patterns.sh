#!/bin/bash

METAPKG_DIR=patterns
PATTERNS_DIR=patterns
SPEC_DIR=rpm

function migrate {
  pattern=$1
  pattername=$(basename "$pattern" .yaml)
  remove_prefix="jolla-"
  meta=${pattername#"$remove_prefix"}
  meta=patterns-sailfish-device-${meta#"hw-"}
  metaspec=$meta.inc
  device=${meta##*-}

  if [ -f $METAPKG_DIR/"$metaspec" ]; then
    echo "Already migrated: $PATTERNS_DIR/$pattern -> $metaspec"
    return
  fi

  {
    echo "%package -n $meta"
    sed -n '/Summary:/p' $PATTERNS_DIR/"$pattern"
    awk '/Requires:/{flag=1;next}/Summary:/{flag=0}flag' $PATTERNS_DIR/"$pattern"
  } >> $METAPKG_DIR/"$metaspec"

  sed -i 's/- /Requires: /g' $METAPKG_DIR/"$metaspec"
  sed -i 's/pattern://g' $METAPKG_DIR/"$metaspec"
  sed -i 's/Requires: jolla-hw-adaptation-/Requires: patterns-sailfish-device-adaptation-/g' $METAPKG_DIR/"$metaspec"
  sed -i 's/Requires: jolla-configuration-/Requires: patterns-sailfish-device-configuration-/g' $METAPKG_DIR/"$metaspec"
  sed -i "s/@ICON_RES@/%{icon_res}/" $METAPKG_DIR/"$metaspec"

  {
    echo "%description -n $meta"
    sed -n -e 's/^Description: //p' $PATTERNS_DIR/"$pattern"
    echo
    echo "%files -n $meta"
  } >> $METAPKG_DIR/"$metaspec"

  # scan all .spec files, some of them might have differing rpm_device and device vars
  grep -l "device\s*$device$" $SPEC_DIR/droid-config-*.spec | while IFS= read -r f; do
    if ! grep -q "%include $METAPKG_DIR\/$metaspec" "$f"; then
      # include meta-packages to the .spec
      sed -i "/^%include droid-configs-device\/droid-configs.inc/a %include $METAPKG_DIR\/$metaspec" "$f"
    fi
  done

  if [[ $meta == patterns-sailfish-device-adaptation-* ]]; then
    rm $PATTERNS_DIR/"$pattern"
    sed -i "/$pattername.xml$/d" delete_pattern_*.list 2>/dev/null
  elif [[ $meta == patterns-sailfish-device-configuration-* ]]; then
    cat <<EOF > $PATTERNS_DIR/"$pattern"
Description: Pattern with packages for $device configurations
Name: jolla-configuration-$device
Requires:
- patterns-sailfish-device-configuration-$device

Summary: Jolla Configuration $device
EOF
  fi

  echo "Migrated successfully: $PATTERNS_DIR/$pattern -> $metaspec"
}

if [ ! -d droid-configs-device/helpers ]; then
  echo "$0: launch this script from the \$ANDROID_ROOT/hybris/droid-configs directory"
  exit 1
fi

for pattern in "$PATTERNS_DIR"/*.yaml; do
  migrate "${pattern##*/}"
done
