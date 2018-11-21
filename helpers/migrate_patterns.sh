#!/bin/bash

METAPKG_DIR=rpm
PATTERNS_DIR=patterns

function migrate {
  pattern=$1
  metaspec=$(basename $1 .yaml).spec

  mkdir -p $METAPKG_DIR
  touch $METAPKG_DIR/$metaspec

  sed -n '/Name:/p' $PATTERNS_DIR/$pattern >> $METAPKG_DIR/$metaspec
  sed -n '/Summary:/p' $PATTERNS_DIR/$pattern >> $METAPKG_DIR/$metaspec

  cat <<EOF >> $METAPKG_DIR/$metaspec
Version: 0.0.1
Release: 1
License: BSD-3-Clause
Source: %{name}-%{version}.tar.gz
EOF

  awk '/Requires:/{flag=1;next}/Summary:/{flag=0}flag' $PATTERNS_DIR/$pattern >> $METAPKG_DIR/$metaspec
  sed -i 's/- /Requires: /g' $METAPKG_DIR/$metaspec
  sed -i 's/pattern://g' $METAPKG_DIR/$metaspec

  echo '%description' >> $METAPKG_DIR/$metaspec
  sed -n -e 's/^Description: //p' $PATTERNS_DIR/$pattern >> $METAPKG_DIR/$metaspec

  echo '%files' >> $METAPKG_DIR/$metaspec
}

for pattern in $PATTERNS_DIR/*.yaml; do
  migrate ${pattern##*/}
done

