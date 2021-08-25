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
unittest=1

distro_list=()
distro_list+=("alpine/3.14")
distro_list+=("archlinux/current")
distro_list+=("debian/buster")
distro_list+=("debian/bullseye")
distro_list+=("fedora/34")
distro_list+=("opensuse/tumbleweed")
distro_list+=("ubuntu/18.04")
distro_list+=("ubuntu/20.04")
distro_list+=("ubuntu/21.04")
distro_list+=("voidlinux/current")

function run {
	local start_sec=${SECONDS}
	local stop_sec

	echo "[${distro}]$ $*"
	if ! eval "$@"; then
		echo "error: '$*' failed for distro ${distro}"
		exit 1
	fi

	stop_sec=$((SECONDS - start_sec))
	if [ ${stop_sec} -gt 0 ]; then
		echo "[${distro}]$ # done in ${stop_sec} seconds"
	fi
}

function run_no_exit {
	local start_sec=${SECONDS}
	local stop_sec

	echo "[${distro}]$ $*"
	if ! eval "$@"; then
		echo "warning: '$*' failed for distro ${distro}"
	fi
	stop_sec=$((SECONDS - start_sec))
	if [ ${stop_sec} -gt 0 ]; then
		echo "[${distro}]$ # done in ${stop_sec} seconds"
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

		if [[ ${distro} == *archlinux* ]] || [[ ${distro} == *fedora* ]]; then
			run "lxc launch images:${distro} -c security.nesting=true ${lxc_name}"
		else
			run "lxc launch images:${distro} ${lxc_name}"
		fi
		run "sleep 10"

		ove_packs="bash bzip2 git curl file binutils util-linux coreutils"
		if [[ ${distro} == *alpine* ]]; then
			package_manager="apk add --no-progress -q"
		elif [[ ${distro} == *archlinux* ]]; then
			package_manager="pacman -S --noconfirm -q --noprogressbar"
		elif [[ ${distro} == *ubuntu* ]] || [[ ${distro} == *debian* ]]; then
			ove_packs+=" bsdmainutils"
			package_manager="apt-get -y -qq install"
			lxc_exec_options="--env DEBIAN_FRONTEND=noninteractive"
		elif [[ ${distro} == *voidlinux* ]]; then
			package_manager="xbps-install -y"
		elif [[ ${distro} == *fedora* ]]; then
			package_manager="dnf install -y"
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
			elif [[ ${distro} == *archlinux* ]]; then
				run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS -S --noconfirm --noprogressbar; ove config'"
			elif [[ ${distro} == *voidlinux* ]]; then
				run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER xbps-install -y; ove config'"
			elif [[ ${distro} == *opensuse* ]]; then
				run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y; ove config'"
			elif [[ ${distro} == *fedora* ]]; then
				run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y; ove config'"
			elif [[ ${distro} == *alpine* ]]; then
				run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS add --no-progress -q; ove config'"
			fi

			run "lxc exec ${lxc_exec_options} -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; DEBIAN_FRONTEND=noninteractive ove install-pkg tmux'"
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove buildme tmux'"
			if [[ ${distro} == *archlinux* ]]; then
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- sed -i 's|#en_US.UTF-8 UTF-8|en_US.UTF-8 UTF-8|g' /etc/locale.gen"
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- locale-gen"
			fi
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; stage/usr/bin/tmux -V'"
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove mrproper y'"
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove buildme-parallel tmux'"
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; stage/usr/bin/tmux -V'"
		fi

		if [ ${unittest} -eq 1 ]; then
			run "lxc file push --uid 0 --gid 0 ${HOME}/.gitconfig ${lxc_name}/root/.gitconfig"

			run "lxc exec ${lxc_exec_options} ${lxc_name} -- ${package_manager} python3"
			if [[ ${distro} == *alpine* ]]; then
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- ${package_manager} py3-yaml"
			elif [[ ${distro} == *archlinux* ]]; then
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- ${package_manager} python-yaml"
			elif [[ ${distro} == *opensuse* ]]; then
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- ${package_manager} python3-PyYAML"
			else
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- ${package_manager} python3-yaml"
			fi

			if [[ ${distro} == *alpine* ]]; then
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- ${package_manager} alpine-sdk cabal ghc"
			elif [[ ${distro} == *voidlinux* ]]; then
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- ${package_manager} cabal-install ghc"
			else
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- ${package_manager} cabal-install ghc happy"
			fi
			run "lxc exec ${lxc_exec_options} ${lxc_name} -- cabal update --verbose=0"
			if [[ ${distro} == *archlinux* ]]; then
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- cabal install --verbose=0 --ghc-options=-dynamic shelltestrunner-1.9"
			else
				run "lxc exec ${lxc_exec_options} ${lxc_name} -- cabal install --verbose=0 shelltestrunner-1.9"
			fi
			run "lxc exec -t ${lxc_name} -- bash -c -i 'cd my-ove-workspace; source ove hush; ove unittest'"
		fi

		run_no_exit "lxc stop ${lxc_name} --force"
		run_no_exit "lxc delete ${lxc_name} --force"
		run "# done in $((SECONDS - start_sec)) seconds"
	done
}

main "$@"
