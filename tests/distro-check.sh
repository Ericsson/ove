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

function init {
	if ! command -v lxc > /dev/null; then
		echo "error: lxc missing"
		exit 1
	fi

	if [ $# -ne 2 ]; then
		echo "usage: $(basename "$0") unittest|file pattern"
		exit 1
	fi

	if [ "$1" = "unittest" ]; then
		unittest=1
	else
		unittest=0
		distcheck="$1"
		if [ ! -e "${distcheck}" ]; then
			echo "error: '${distcheck}' not found"
			exit 1
		fi
	fi
	arch=$(\uname -m)
	if [ "${arch}" = "x86_64" ]; then
		arch="amd64"
	fi

	if ! \lxc image list --format csv -cL images: arch=${arch} | \sed -e 's,",,g' -e '/^$/d' > "${OVE_GLOBAL_STATE_DIR:?}/distro-check.images"; then
		echo "error: 'lxc image list images:' failed"
		exit 1
	elif [ ! -s "${OVE_GLOBAL_STATE_DIR}/distro-check.images" ]; then
		echo "error: no images found"
		exit 1
	fi

	mapfile -t distro_list <<<"$(\grep -E "$2" "${OVE_GLOBAL_STATE_DIR}/distro-check.images")"
	if [[ ( ${#distro_list[@]} -eq 0 ) || ( ${#distro_list[@]} -eq 1 && "x${distro_list[*]}" = "x" ) ]]; then
		echo "error: no images, try to broaden the filter, choose from:"
		\cat "${OVE_GLOBAL_STATE_DIR}/distro-check.images"
		exit 1
	fi

	if [ "x${distcheck}" != "x" ] && [ ${#distro_list[@]} -gt 1 ];  then
		echo "info: pattern matched these images:"
		printf "%s\n" "${distro_list[@]}" | cat -n
		for i in {3..1}; do
			echo -en "\r${i}"
			sleep 1
		done
		echo
	fi
}

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

function lxc_command {
	if ! lxc exec "${lxc_name}" -- sh -c "command -v $1" &> /dev/null; then
		return 1
	else
		return 0
	fi
}

function lxc_exec {
	local lxc_exec_options

	lxc_exec_options="-t --env DEBIAN_FRONTEND=noninteractive"
	run "lxc exec ${lxc_exec_options} ${lxc_name} -- $*"
}

function package_manager_noconfirm {
	lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_INSTALL_PKG 1'"

	if [[ ${package_manager} == apt-get* ]];  then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -yq'"
	elif [[ ${package_manager} == pacman* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS -S --noconfirm --noprogressbar'"
	elif [[ ${package_manager} == xbps-install* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER xbps-install -y'"
	elif [[ ${package_manager} == zypper* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y'"
	elif [[ ${package_manager} == dnf* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y'"
	elif [[ ${package_manager} == apk* ]]; then
		lxc_exec "bash -c -i '${prefix}; ove add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS add --no-progress -q'"
	fi
	lxc_exec "bash -c -i '${prefix}; ove config'"
}

function cleanup {
	run_no_exit "lxc stop ${lxc_name} --force"
	run_no_exit "lxc delete ${lxc_name} --force"
}

function main {
	local distro
	local lxc_name
	local ove_packs
	local package_manager
	local start_sec

	init "$@"

	for distro in "${distro_list[@]}"; do
		start_sec=${SECONDS}
		# replace slashes and dots
		lxc_name="ove-distro-check-${distro//\//-}"
		lxc_name="${lxc_name//./-}"

		if lxc list --format csv | grep -q "^${lxc_name},"; then
			run "lxc delete --force ${lxc_name}"
		fi

		if [[ ${distro} == *archlinux* ]] || [[ ${distro} == *fedora* ]]; then
			run "lxc launch images:${distro} -c security.nesting=true ${lxc_name}"
		else
			run "lxc launch images:${distro} ${lxc_name}"
		fi
		run "sleep 10"

		ove_packs="bash bzip2 git curl file binutils util-linux coreutils"
		if lxc_command "apk"; then
			package_manager="apk add --no-progress -q"
		elif lxc_command "pacman"; then
			package_manager="pacman -S --noconfirm -q --noprogressbar"
		elif lxc_command "apt-get"; then
			ove_packs+=" bsdmainutils procps"
			package_manager="apt-get -y -qq install"
		elif lxc_command "xbps-install"; then
			package_manager="xbps-install -y"
		elif lxc_command "dnf"; then
			package_manager="dnf install -y"
		elif lxc_command "zypper"; then
			package_manager="zypper install -y"
		else
			echo "error: unknown package manager for '${distro}'"
			cleanup
			continue
		fi

		lxc_exec "${package_manager} ${ove_packs}"
		if [ "${OVE_PROJECT_DIR}" != "x" ] && [ -s "${OVE_PROJECT_DIR}/SETUP" ]; then
			lxc_exec "bash -c '$(cat "${OVE_PROJECT_DIR}"/SETUP)'"
			ws_name=$(lxc exec "${lxc_name}" -- bash -c 'find -mindepth 2 -maxdepth 2 -name .owel' | cut -d/ -f2)
			if [ "x${ws_name}" = "x" ]; then
				echo "error: workspace name not found"
				cleanup
				exit 1
			fi
		else
			ws_name="distro-check"
			lxc_exec "bash -c 'curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s ${ws_name} https://github.com/Ericsson/ove-tutorial'"
		fi
		prefix="cd ${ws_name}; source ove hush"
		lxc_exec "bash -c -i 'cd ${ws_name}; source ove'"
		lxc_exec "bash -c -i '${prefix}; ove env'"
		lxc_exec "bash -c -i '${prefix}; ove status'"

		package_manager_noconfirm
		if [[ ${distro} == *archlinux* ]]; then
			lxc_exec "sed -i 's|#en_US.UTF-8 UTF-8|en_US.UTF-8 UTF-8|g' /etc/locale.gen"
			lxc_exec "locale-gen"
		fi

		if [[ ${distro} == *opensuse* ]]; then
			lxc_exec "zypper install -y -t pattern devel_basis"
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

		if [ "x${distcheck}" != "x" ]; then
			run "lxc file push --uid 0 --gid 0 ${distcheck} ${lxc_name}/tmp/distcheck"
			lxc_exec "bash -c -i '${prefix}; DEBIAN_FRONTEND=noninteractive ove install-pkg $(basename "$(dirname "${distcheck}")")'"
			lxc_exec "bash -c -i '${prefix}; source /tmp/distcheck'"
		fi

		cleanup
		run "# done in $((SECONDS - start_sec)) seconds"
	done
}

main "$@"
