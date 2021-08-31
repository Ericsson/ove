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

ws_name="distro-check"
prefix="cd ${ws_name}; source ove hush"

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

function lxc_exec {
	local lxc_exec_options

	lxc_exec_options="-t --env DEBIAN_FRONTEND=noninteractive"
	run "lxc exec ${lxc_exec_options} ${lxc_name} -- $*"
}

function package_manager_noconfirm {
	lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_INSTALL_PKG 1'"
	if [[ ${distro} == *ubuntu* ]] || [[ ${distro} == *debian* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -yq'"
	elif [[ ${distro} == *archlinux* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS -S --noconfirm --noprogressbar'"
	elif [[ ${distro} == *voidlinux* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER xbps-install -y'"
	elif [[ ${distro} == *opensuse* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y'"
	elif [[ ${distro} == *fedora* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y'"
	elif [[ ${distro} == *alpine* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS add --no-progress -q'"
	fi
	lxc_exec "bash -c -i '${prefix}; ove config'"
}

function main {
	local distro
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
		elif [[ ${distro} == *voidlinux* ]]; then
			package_manager="xbps-install -y"
		elif [[ ${distro} == *fedora* ]]; then
			package_manager="dnf install -y"
		elif [[ ${distro} == *opensuse* ]]; then
			package_manager="zypper install -y"
		fi

		lxc_exec "${package_manager} ${ove_packs}"
		lxc_exec "bash -c 'curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s ${ws_name} https://github.com/Ericsson/ove-tutorial'"
		lxc_exec "bash -c -i 'cd ${ws_name}; source ove'"
		lxc_exec "bash -c -i '${prefix}; ove env'"
		lxc_exec "bash -c -i '${prefix}; ove status'"

		package_manager_noconfirm

		if [ ${build} -eq 1 ]; then
			lxc_exec "bash -c -i '${prefix}; ove fetch tmux'"
			lxc_exec "bash -c -i '${prefix}; ove status'"

			if [[ ${distro} == *opensuse* ]]; then
				lxc_exec "zypper install -y -t pattern devel_basis"
			fi

			lxc_exec "bash -c -i '${prefix}; DEBIAN_FRONTEND=noninteractive ove install-pkg tmux'"
			lxc_exec "bash -c -i '${prefix}; ove buildme tmux'"
			if [[ ${distro} == *archlinux* ]]; then
				lxc_exec "sed -i 's|#en_US.UTF-8 UTF-8|en_US.UTF-8 UTF-8|g' /etc/locale.gen"
				lxc_exec "locale-gen"
			fi
			lxc_exec "bash -c -i '${prefix}; stage/usr/bin/tmux -V'"
			lxc_exec "bash -c -i '${prefix}; ove mrproper y'"
			lxc_exec "bash -c -i '${prefix}; ove buildme-parallel tmux'"
			lxc_exec "bash -c -i '${prefix}; stage/usr/bin/tmux -V'"
		fi

		if [ ${unittest} -eq 1 ]; then
			run "lxc file push --uid 0 --gid 0 ${HOME}/.gitconfig ${lxc_name}/root/.gitconfig"

			lxc_exec "${package_manager} python3"
			if [[ ${distro} == *alpine* ]]; then
				lxc_exec "${package_manager} py3-yaml"
			elif [[ ${distro} == *archlinux* ]]; then
				lxc_exec "${package_manager} python-yaml"
			elif [[ ${distro} == *opensuse* ]]; then
				lxc_exec "${package_manager} python3-PyYAML"
			else
				lxc_exec "${package_manager} python3-yaml"
			fi

			if [[ ${distro} == *alpine* ]]; then
				lxc_exec "${package_manager} alpine-sdk cabal ghc"
			elif [[ ${distro} == *voidlinux* ]]; then
				lxc_exec "${package_manager} cabal-install ghc"
			else
				lxc_exec "${package_manager} cabal-install ghc happy"
			fi
			lxc_exec "cabal update --verbose=0"
			if [[ ${distro} == *archlinux* ]]; then
				lxc_exec "cabal install --verbose=0 --ghc-options=-dynamic shelltestrunner-1.9"
			else
				lxc_exec "cabal install --verbose=0 shelltestrunner-1.9"
			fi
			lxc_exec "bash -c -i '${prefix}; ove unittest'"
		fi

		run_no_exit "lxc stop ${lxc_name} --force"
		run_no_exit "lxc delete ${lxc_name} --force"
		run "# done in $((SECONDS - start_sec)) seconds"
	done
}

main "$@"
