#!/bin/bash

set -eu

CURSCRIPT=`realpath "$0"`
CURDIR=`dirname "$CURSCRIPT"`

add_path() {
	printf 'PATH=%q:$PATH\n' "$1"
}

add_path "$CURDIR/bin"
add_path "$CURDIR/vendor/parallel/src"

cat <<EOF
export PATH
LC_ALL=C.UTF-8
export LC_ALL
TMPDIR=\${TMPDIR:-/tmp}
export TMPDIR
EOF
