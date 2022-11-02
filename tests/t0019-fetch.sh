#!/usr/bin/env bash

set -e

ove-fetch > /dev/null
ove-forall 'date +%s -r .git/FETCH_HEAD' | sort > before
sleep 2
ove-fetch > /dev/null
ove-forall 'date +%s -r .git/FETCH_HEAD' | sort > after
a=$(diff -U0 before after | wc -l)
echo $(((a-3)/2))
