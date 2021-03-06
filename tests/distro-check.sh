#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# MIT License
#
# Copyright (c) 2021 Ericsson
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

if ! command -v lxc > /dev/null; then
	echo "error: lxc missing"
	exit 1
fi

build=1

distro_list=()
distro_list+=("alpine/3.14")
distro_list+=("debian/buster")
distro_list+=("opensuse/tumbleweed")
distro_list+=("ubuntu/18.04")
distro_list+=("ubuntu/20.04")
distro_list+=("ubuntu/21.04")
distro_list+=("voidlinux/current")

function run {
	echo "[${distro}]$ $*"
	if ! eval "$@"; then
		echo "error: '$*' failed for distro ${distro}"
		exit 1
	fi
}

function run_no_exit {
	echo "[${distro}]$ $*"
	if ! eval "$@"; then
		echo "warning: '$*' failed for distro ${distro}"
	fi
}

function main {
	local distro
	local lxc_exec_options
	local lxc_name
	local ove_packs
	local package_manager
	local start_sec

	for distro in "${distro_list[@]}"; do
		start_sec=${SECONDS}
		# replace slashes and dots
		lxc_name="ove-distro-check-${distro//\//-}"
		lxc_name="${lxc_name//./-}"

		if lxc list | grep -q -w "${lxc_name}"; then
			run "lxc delete --force ${lxc_name}"
		fi

		run "lxc launch images:${distro} ${lxc_name}"
		run "sleep 5"

		ove_packs="bash bzip2 git curl file binutils util-linux coreutils"
		if [[ ${distro} == *alpine* ]]; then
			package_manager="apk add"
		elif [[ ${distro} == *ubuntu* ]] || [[ ${distro} == *debian* ]]; then
			ove_packs+=" bsdmainutils"
			package_manager="apt-get -y -qq install"
			lxc_exec_options="--env DEBIAN_FRONTEND=noninteractive"
		elif [[ ${distro} == *voidlinux* ]]; then
			package_manager="xbps-install -y"
		elif [[ ${distro} == *opensuse* ]]; then
			package_manager="zypper install -y"
		fi

		run "lxc exec ${lxc_exec_options} ${lxc_name} -- ${package_manager} ${ove_packs}"
		run "lxc exec ${lxc_name} -- bash -c 'curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s my-ove-workspace https://github.com/Ericsson/ove-tutorial'"
		run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove'"
		run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove status'"
		run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove fetch tmux'"
		run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove status'"

		if [ ${build} -eq 1 ]; then
			if [[ ${distro} == *opensuse* ]]; then
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- zypper install -y -t pattern devel_basis"
			fi

			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove add-config \$HOME/.oveconfig OVE_INSTALL_PKG 1; ove config'"
			if [[ ${distro} == *ubuntu* ]] || [[ ${distro} == *debian* ]]; then
				run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -yq; ove config'"
			elif [[ ${distro} == *voidlinux* ]]; then
				run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER xbps-install -y; ove config'"
			elif [[ ${distro} == *opensuse* ]]; then
				run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y; ove config'"
			fi

			run "lxc exec ${lxc_exec_options} -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; DEBIAN_FRONTEND=noninteractive ove install-pkg tmux'"
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove buildme tmux'"
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; stage/usr/bin/tmux -V'"
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove mrproper y'"
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove buildme-parallel tmux'"
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; stage/usr/bin/tmux -V'"
		fi

		run_no_exit "lxc stop ${lxc_name} --force"
		run_no_exit "lxc delete ${lxc_name} --force"
		run "# done in $((SECONDS - start_sec)) seconds"
	done
}

main "$@"
