#!/usr/bin/env bash

set -e

function cleanup {

	return 0
}
trap cleanup EXIT
cleanup

for i in {1..10}; do
	for r in .owel git-1; do
		\tr -dc "\t\n [:alnum:]" < /dev/urandom | head -c1000 > $r/README
		\git -C $r add README
		\git -C $r commit -q -m "README"
	done
done

for t in 0.0.1 0.0.2 0.0.3; do
	ove update-revtab git-1 $t
	\git -C .owel add revtab
	\git -C .owel commit -q -m "git-1 on $t"
done

for r in {1..10}; do
	echo $r:log-project
	ove log-project HEAD~$r HEAD
	echo $r:shortlog-project
	ove shortlog-project HEAD~$r HEAD
	echo $r:diff-project
	ove diff-project HEAD~$r HEAD
done
