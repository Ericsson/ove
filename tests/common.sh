#!/usr/bin/env bash

function oneTimeSetUp() {
	# shellcheck disable=SC1091
	source ove

	find . -name .git -exec git -C {} config --local core.pager cat \;
}

if ! __shunit2=$(command -v shunit2); then
	__shunit2=$(find / -xdev -name shunit2 -type f 2> /dev/null)
	if [ "$__shunit2" = "" ]; then
		echo "error: could not find shunit2"
		exit 1
	fi
fi

export SHUNIT_COLOR=none
# shellcheck disable=SC1090
. "${__shunit2:?}"
