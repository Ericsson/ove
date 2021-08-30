#!/usr/bin/env bash

set -e

function cleanup {
	[ -e a.diff ] && rm a.diff

	ove stash push
	ove stash drop

	return 0
}
trap cleanup EXIT
cleanup

while read -r f; do
	echo 123 >> "$f"
done < <(find git-1 git-3 git-5 -path '*/.git' -prune -o -type f -print)
ove diff > a.diff
ove stash push
ove apply a.diff
ove stash drop
