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
	local r s

	s=$(\pwd -P)
	while [ "${s}" != "" ]; do
		[[ -L ${s}/ove && -L ${s}/.owel ]] && break
		s=${s%/*}
	done

	if [ "${s}" != "" ]; then
		cd "${s}"
		. ove hush
		ove ${*}
		r=${?}
	fi
	return ${r}
}

ove_built_ins="! add add-config add-repo ag ahead am apply authors blame blame-history branch build-order buildme buildme-parallel cd checkout commit config describe diff diff-cached diff-check diff-project digraph do domains dry-run emacs env export fetch forall forall-parallel format-patch forowel forowel-parallel fsck fzf generate-doc gitmodules2revtab grep head-tail heads2revtab help import init install-pkg lastlog less-lastlog list-commands list-committed-files list-heads list-missing-projects list-modified-files list-projects list-repositories list-scripts list-systests list-systests-aliases locate locate-all log log-project loglevel loop ls-files ls-remote make mrproper news nop pre-push pull readme refresh remote remote-check remote-set-url replicate reset reset-ahead reset-hard revtab-check revtab-diff run select-configuration setup shell-check shortlog-project show show-ahead show-configuration show-dangling show-news stash status strace-connect strace-execve-time strace-execve-timeline strace-graph systest tag tail-lastlog unittest unsource version vi wdiff wdiff-cached what-is"

complete -o bashdefault -W "${ove_built_ins}" ove
unset ove_built_ins
