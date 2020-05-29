#!/usr/bin/env bash

set -e

ignore+=" refresh"
ignore+=" shell-check"
ignore+=" unsource"

for a in ${OVE_BUILT_INS_WITHOUT_ARGS}; do
	[[ $ignore == *$a* ]] && continue
	ove "$a" || exit 1
done
