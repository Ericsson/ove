#!/usr/bin/env bash

set -e

function cleanup {
	[ -e a.diff ] && rm a.diff

	ove stash
	ove stash drop

	return 0
}
trap cleanup EXIT
cleanup

while read -r f; do
	echo 123 >> $f
done < <(find $(ove list-repositories | grep git-1 | awk '{print $1}') -maxdepth 1 -type f)
ove diff > a.diff
ove stash
ove apply a.diff
ove stash drop
