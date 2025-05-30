#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# MIT License
#
# Copyright (c) 2020 Ericsson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice (including the next
# paragraph) shall be included in all copies or substantial portions of the
# Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
# OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
# OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

function ove {
	local m r s

	s=$(\pwd -P)
	while [ "${s}" != "" ]; do
		[[ -L ${s}/ove && -L ${s}/.owel ]] && break
		s=${s%/*}
	done

	if [ "${s}" != "" ]; then
		# save monitor setting
		m="$(set +o | \grep '\smonitor$')"

		cd "${s}" || return 1
		# shellcheck disable=SC1091
		. ove hush
		cd - > /dev/null || return 1
		ove "${@}"
		r=${?}

		# restore monitor setting
		eval "${m}"
	fi

	return ${r}
}

ove_built_ins="add add-config add-project add-repo ag ahead am apply apply-cached authors behind blame blame-history branch build-order buildme buildme-parallel cd checkout checkout-by-date commit config create-instance create-instance-all create-instance-parallel delete-instance demo describe diff diff-cached diff-check diff-owel digraph do domains dry-run echo edit emacs env export export-logs fetch fetch-fetched fetch-remains forall forall-parallel format-patch forowel forowel-parallel forsome fsck fzf generate-doc gfe gfv grep gvim head-tail heads2revtab help hooks ide import import-submodules init install-pkg install-pkg-os l lastlog lastlog-replay lastlog-summary less-lastlog list-aliases list-colors list-commands list-commands-by-category list-committed-files list-deps list-externals list-git-command-options list-heads list-hooks list-hub list-images list-missing-projects list-modified-files list-modified-files-basename list-needs list-path list-projects list-repositories list-scripts list-systests list-systests-aliases list-tags locate locate-all log log-owel loglevel logo loop loop-close lr ls-files ls-remote make mrproper news nop oneliner patch-repo post-push post-push-parallel pre-push proj2val ps pull purge-hub readme rebase-autosquash rec refresh refresh-hub refresh-image remote remote-check remote-set-url remove-repo rename replicate replicate-cluster replicate-cluster-parallel reset reset-ahead reset-hard revtab-check revtab-diff revtab-sync rg rm-logs run run-parallel run-remote setup shell-check shortlog-owel show show-ahead show-behind show-dangling show-news stash status strace-connect strace-execve-time strace-execve-timeline strace-graph systest tag tail-lastlog task ts unittest unsource update-revtab version vi wdiff wdiff-cached what-extensions what-is wipe-base-dir worktree"

complete -o bashdefault -W "${ove_built_ins}" ove
unset ove_built_ins
