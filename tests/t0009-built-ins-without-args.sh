#!/usr/bin/env bash

set -e

ignore+=" loop-close"
ignore+=" post-push"
ignore+=" post-push-parallel"
ignore+=" pre-push"
ignore+=" refresh"
ignore+=" shell-check"
ignore+=" unsource"

for a in ${OVE_BUILT_INS_WITHOUT_ARGS}; do
	[[ $ignore == *$a* ]] && continue
	if ! ove "$a"; then
		echo "$a failed"
		exit 1
	fi
done
