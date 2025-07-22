#!/bin/sh

set -eu

CURSCRIPT=`realpath "$0"`
CURDIR=`dirname "$CURSCRIPT"`

cat <<EOF
PATH=$CURDIR/bin:\$PATH
PATH=$CURDIR/vendor/parallel/src:\$PATH
export PATH
export LC_ALL=C
export TMPDIR=\${TMPDIR:-/tmp}
EOF
