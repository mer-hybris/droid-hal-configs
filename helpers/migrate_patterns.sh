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
  sed -i "/^Requires: patterns-sailfish-device-adaptation-/i Requires: patterns-sailfish-device-configuration-common-$device" $METAPKG_DIR/"$metaspec"
  sed -i '/^Requires: patterns-sailfish-applications/d' $METAPKG_DIR/"$metaspec"
  sed -i '/^Requires: patterns-sailfish-ui/d' $METAPKG_DIR/"$metaspec"
  sed -i '/^Requires: csd/d' $METAPKG_DIR/"$metaspec"
  sed -i 's/Requires: jolla-configuration-/Requires: patterns-sailfish-device-configuration-/g' $METAPKG_DIR/"$metaspec"
  sed -i 's/Requires: jolla-developer-mode$/Recommends: jolla-developer-mode/g' $METAPKG_DIR/"$metaspec"
  sed -i "s/@ICON_RES@/%{icon_res}/" $METAPKG_DIR/"$metaspec"

  {
    echo "%description -n $meta"
    sed -n -e 's/^Description: //p' $PATTERNS_DIR/"$pattern"
    echo
    echo "%files -n $meta"
  } >> $METAPKG_DIR/"$metaspec"

  # scan all .spec files, some of them might have differing rpm_device and device vars
  grep -l "device\s*$device\s*$" $SPEC_DIR/droid-config-*.spec | while IFS= read -r f; do
    if ! grep -q "%include $METAPKG_DIR\/$metaspec" "$f"; then
      # include meta-packages to the .spec
      sed -i "/^%include droid-configs-device\/droid-configs.inc/a %include $METAPKG_DIR\/$metaspec" "$f"
    fi
  done

  if [[ $meta == patterns-sailfish-device-adaptation-* ]]; then
    rm $PATTERNS_DIR/"$pattern"
    sed -i "/$pattername.xml$/d" delete_pattern_*.list 2>/dev/null
  elif [[ $meta == patterns-sailfish-device-*configuration-* ]]; then
    # Replace pattern contents with the main meta-package
    tmpmeta=$(mktemp)
    awk -v name=$meta '
      BEGIN         {p=1}
      /^Requires:/  {print;system("echo - "name"; echo");p=0}
      /^Summary:/   {p=1}
      p' $PATTERNS_DIR/"$pattern" > $tmpmeta
    mv $tmpmeta $PATTERNS_DIR/"$pattern"
  fi

  echo "Migrated successfully: $PATTERNS_DIR/$pattern -> $metaspec"
}

if [ ! -d droid-configs-device/helpers ]; then
  echo "$0: launch this script from the \$ANDROID_ROOT/hybris/droid-configs directory"
  exit 1
fi

for pattern in "$PATTERNS_DIR"/*.yaml; do
  while IFS= read -r f; do
    if (echo "$f" | grep -q "^- pattern:\s*sailfish-porter-tools"); then
      echo "Please replace '- pattern:sailfish-porter-tools' with:"
      echo "- patterns-sailfish-device-tools"
      echo
      echo "and re-run this script"
      exit 1
    fi
    if ! (echo "$f" | grep -q "^- pattern:\s*jolla-hw-adaptation-"); then
      echo "File $pattern contains patterns that cannot be migrated automatically. Aborting."
      exit 1
    fi
  done < <(grep "^- pattern:" "$pattern")
done

for pattern in "$PATTERNS_DIR"/*.yaml; do
  migrate "${pattern##*/}"
done
