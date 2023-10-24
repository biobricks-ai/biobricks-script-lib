#!/bin/sh

set -eu

CURSCRIPT=`realpath "$0"`
CURDIR=`dirname "$CURSCRIPT"`

cat <<EOF
PATH=$CURDIR/bin:\$PATH
export PATH
EOF
