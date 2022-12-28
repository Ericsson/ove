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

lxc_name=""
tag=""

function _echo {
	if [[ ${OVE_DISTROCHECK_STEPS} == *verbose* ]]; then
		ove-echo stderr "$*"
	fi

	return 0
}

function init {
	local s

	if ! command -v lxc > /dev/null; then
		echo "error: lxc missing"
		exit 1
	elif [ $# -ne 2 ]; then
		echo "usage: $(basename "$0") file|project|unittest distro"
		exit 1
	fi

	if [ "$1" = "unittest" ]; then
		unittest=1
		OVE_DISTROCHECK_STEPS="ove verbose"
	else
		unittest=0
		distcheck="$1"
	fi

	if [ -t 1 ]; then
		bash_opt="-i"
		lxc_opt="-t"
	fi

	distro="$2"

	if [ ! -v OVE_DISTROCHECK_STEPS ]; then
		OVE_DISTROCHECK_STEPS=""
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *verbose* ]]; then
		for s in ${OVE_DISTROCHECK_STEPS//:/ };do
			echo $s
		done
	fi
}

function run {
	local sleep_s

	_echo "[${distro}]$ $*"
	while true; do
		if eval "$@" 2> "${OVE_TMP}/${tag:?}.err"; then
			return 0
		fi

		_echo "error: '$*' failed for distro '${distro}'"
		if [ ! -s "${OVE_TMP}/${tag}.err" ]; then
			if [ "x$NO_EXIT" = "x1" ]; then
				return 1
			else
				exit 1
			fi
		fi

		sleep_s=$((RANDOM%10))
		if grep "i/o timeout" "${OVE_TMP}/${tag}.err"; then
			ove-echo warning_noprefix "lxd i/o timeout, re-try in $sleep_s sec"
			sleep $sleep_s
			continue
		elif grep "Error: websocket:" "${OVE_TMP}/${tag}.err"; then
			ove-echo warning_noprefix "lxd websocket error, re-try in $sleep_s sec"
			sleep $sleep_s
			continue
		else
			cat "${OVE_TMP}/${tag}.err"
		fi

		if [ "x$NO_EXIT" = "x1" ]; then
			return 1
		else
			exit 1
		fi
	done
}

function run_no_exit {
	if ! NO_EXIT=1 run "$@"; then
		return 1
	fi
}

function lxc_command {
	if ! lxc_exec_no_exit "sh -c 'command -v $1' &> /dev/null"; then
		return 1
	else
		return 0
	fi
}

function lxc_exec {
	local e
	local lxc_exec_options

	lxc_exec_options="${lxc_opt} --env DEBIAN_FRONTEND=noninteractive"
	for e in ftp_proxy http_proxy https_proxy; do
		if [ "x${!e}" = "x" ]; then
			continue
		fi
		lxc_exec_options+=" --env ${e}=${!e}"
	done

	if [ "x$LXC_EXEC_EXTRA" != "x" ]; then
		lxc_exec_options+=" $LXC_EXEC_EXTRA"
	fi

	run "lxc exec ${lxc_exec_options} ${lxc_name} -- $*"
}

function lxc_exec_no_exit {
	local e
	local lxc_exec_options

	lxc_exec_options="${lxc_opt} --env DEBIAN_FRONTEND=noninteractive"
	for e in ftp_proxy http_proxy https_proxy; do
		if [ "x${!e}" = "x" ]; then
			continue
		fi
		lxc_exec_options+=" --env ${e}=${!e}"
	done

	if [ "x$LXC_EXEC_EXTRA" != "x" ]; then
		lxc_exec_options+=" $LXC_EXEC_EXTRA"
	fi

	if ! run_no_exit "lxc exec ${lxc_exec_options} ${lxc_name} -- $*"; then
		return 1
	fi
}

function package_manager_noconfirm {
	lxc_exec "bash -c ${bash_opt} '${prefix}; ove-add-config \$HOME/.oveconfig OVE_INSTALL_PKG 1'"

	if [[ ${package_manager} == apt-get* ]];  then
		lxc_exec "bash -c ${bash_opt} '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS -y -qq -o=Dpkg::Progress=0 -o=Dpkg::Progress-Fancy=false install'"
	elif [[ ${package_manager} == pacman* ]]; then
		lxc_exec "bash -c ${bash_opt} '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS -S --noconfirm --noprogressbar'"
	elif [[ ${package_manager} == xbps-install* ]]; then
		lxc_exec "bash -c ${bash_opt} '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER xbps-install -y'"
	elif [[ ${package_manager} == zypper* ]]; then
		lxc_exec "bash -c ${bash_opt} '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y'"
	elif [[ ${package_manager} == dnf* ]]; then
		lxc_exec "bash -c ${bash_opt} '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y'"
	elif [[ ${package_manager} == apk* ]]; then
		lxc_exec "bash -c ${bash_opt} '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS add --no-progress -q'"
	fi
	lxc_exec "bash -c ${bash_opt} '${prefix}; ove-config'"
}

function remove_tmp {
	find "${OVE_TMP:?}" -maxdepth 1 -name "${tag:?}*" -exec rm {} \;
	return 0
}

function cleanup {
	if [[ ${OVE_DISTROCHECK_STEPS} == *running* ]]; then
		remove_tmp
		return
	fi
	run_no_exit "lxc stop ${lxc_name} --force"
	if [[ ${OVE_DISTROCHECK_STEPS} == *stopped* ]]; then
		remove_tmp
		return
	fi
	run_no_exit "lxc delete ${lxc_name} --force"
	remove_tmp
}

function setup_package_manager {
	local package_refresh

	if lxc_command "apk"; then
		package_manager="apk add --no-progress -q"
		if lxc_exec_no_exit "timeout 10 apk update"; then
			return 0
		fi

		lxc exec ${lxc_name} -- sed -i 's/https/http/g' /etc/apk/repositories
		if lxc_exec_no_exit "timeout 10 apk update"; then
			return 0
		fi

		echo "error: apk update failed"
		exit 1
	elif lxc_command "pacman"; then
		package_refresh="pacman -Syu --noconfirm -q --noprogressbar"
		package_manager="pacman -S --noconfirm -q --noprogressbar"
	elif lxc_command "apt-get"; then
		if [[ ${OVE_DISTROCHECK_STEPS} == *ove* ]]; then
			ove_packs="bsdmainutils procps "
		fi
		package_manager="apt-get -y -qq -o=Dpkg::Progress=0 -o=Dpkg::Progress-Fancy=false install"
		if [ -s "/etc/apt/apt.conf" ]; then
			cp -a "/etc/apt/apt.conf" "$OVE_TMP/${tag}-apt.conf"
			run "lxc file push --uid 0 --gid 0 $OVE_TMP/${tag}-apt.conf ${lxc_name}/etc/apt/apt.conf"
		fi
		package_refresh="apt-get update"
	elif lxc_command "xbps-install"; then
		package_manager="xbps-install -y"
	elif lxc_command "dnf"; then
		package_manager="dnf install -y"
	elif lxc_command "zypper"; then
		package_manager="zypper install -y"
	else
		echo "error: unknown package manager for '${distro}'"
		exit 1
	fi

	# refresh package manager?
	if [ "x${package_refresh}" != "x" ]; then
		lxc_exec_no_exit "${package_refresh}"
	fi
}

function main {
	local _home="/root"
	local ove_packs
	local package_manager
	local prefix="true"
	local server_name
	local _uid=0

	init "$@"

	if [ "x${OVE_LAST_COMMAND}" != "x" ]; then
		# re-use date+time (ignore micro/nano) from OVE_LAST_COMMAND
		tag="${OVE_LAST_COMMAND##*/}"
		tag="${tag:0:18}"
	else
		tag="$(date '+%Y%m%d-%H%M%S%N')"
	fi

	lxc_name="${OVE_USER}-${tag}-${distro}"

	# replace slashes and dots
	lxc_name="${lxc_name//\//-}"
	lxc_name="${lxc_name//./-}"

	if [ ${#lxc_name} -gt 63 ]; then
		_echo "info: lxc name '${lxc_name}' tuncated"
		lxc_name=${lxc_name:0:63}
	fi

	# ove, user and lxc cluster? => create container on localhost
	if [ ! -v OVE_LXC_LAUNCH_EXTRA_ARGS ] && \
		[[ ${OVE_DISTROCHECK_STEPS} == *ove* ]] && \
		[[ ${OVE_DISTROCHECK_STEPS} == *user* ]] && \
		lxc cluster list &> /dev/null; then
		server_name=$(lxc info | grep server_name | awk '{print $2}')
		if [ "x$server_name" != "x" ]; then
			OVE_LXC_LAUNCH_EXTRA_ARGS="--target=$server_name"
		fi
	fi

	# ephemeral container?
	if [[ ${OVE_DISTROCHECK_STEPS} != *running* ]] && \
		[[ ${OVE_DISTROCHECK_STEPS} != *stopped* ]]; then
			OVE_LXC_LAUNCH_EXTRA_ARGS+=" --ephemeral"
			OVE_DISTROCHECK_STEPS+=" stopped"
	fi

	if [[ ${distro} == *archlinux* ]] || [[ ${distro} == *fedora* ]]; then
		OVE_LXC_LAUNCH_EXTRA_ARGS+=" -c security.nesting=true"
	fi

	run "lxc launch images:${distro} ${lxc_name} ${OVE_LXC_LAUNCH_EXTRA_ARGS//\#/ } > /dev/null"
	trap cleanup EXIT

	cat > "$OVE_TMP/${tag}-bootcheck.sh" <<EOF
#!/usr/bin/env sh
if ! command -v systemctl > /dev/null; then
	exit 0
fi

i=0
while true; do
	i=\$((i+1))
	if [ \$i -ge 200 ]; then
		exit 0
	fi
	s=\$(systemctl is-system-running 2> /dev/null);
	if [ "x\$s" = "xrunning" ]; then
		break;
	fi
	sleep 0.01;
done
EOF

	run "lxc file push --uid 0 --gid 0 $OVE_TMP/${tag}-bootcheck.sh ${lxc_name}/var/tmp/${tag}-bootcheck.sh"
	lxc_exec_no_exit "sh /var/tmp/${tag}-bootcheck.sh"

	if [[ ( ${OVE_DISTROCHECK_STEPS} == *user* && ${EUID} -ne 0 ) || ( ${OVE_DISTROCHECK_STEPS} == *ove* ) ]]; then
		setup_package_manager
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *user* ]] && [ ${EUID} -ne 0 ]; then
		lxc_exec "${package_manager} bash"
		if [[ ${distro} == *alpine* ]]; then
			lxc_exec "${package_manager} shadow sudo"
		fi
		lxc_exec "useradd --shell /bin/bash -m -d ${HOME:?} ${OVE_USER:?}"
		_uid=$(lxc_exec "id -u ${OVE_USER}")
		_uid=${_uid/$'\r'/}
		_home=$HOME

		_echo "idmap"
		printf "uid %s $_uid\ngid %s $_uid" "$(id -u)" "$(id -g)" | \
			lxc config set "${lxc_name}" raw.idmap -

		_echo "user and sudo"
		echo "${OVE_USER} ALL=(ALL) NOPASSWD:ALL" > "$OVE_TMP/${tag}-sudoers"
		run "lxc file push --uid 0 --gid 0 $OVE_TMP/${tag}-sudoers ${lxc_name}/etc/sudoers.d/91-ove"

		run "lxc restart ${lxc_name}"
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *ove* ]]; then
		ove_packs+="bash bzip2 git curl file binutils util-linux coreutils"

		# install OVE packages
		lxc_exec "${package_manager} ${ove_packs}"

		if [[ ${distro} == *archlinux* ]]; then
			lxc_exec "sed -i 's|#en_US.UTF-8 UTF-8|en_US.UTF-8 UTF-8|g' /etc/locale.gen"
			lxc_exec "locale-gen"
		fi
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *user* ]] && [ ${EUID} -ne 0 ]; then
		# from now on, run all lxc exec commands as user
		export LXC_EXEC_EXTRA="--user $_uid --env HOME=$HOME"
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *ove* ]]; then
		# gitconfig
		if [ -s "${HOME}"/.gitconfig ]; then
			cp -a "${HOME}"/.gitconfig "${OVE_TMP}/${tag}-gitconfig"
			run "lxc file push --uid $_uid ${OVE_TMP}/${tag}-gitconfig ${lxc_name}${_home}/.gitconfig"
		fi

		# oveconfig
		if [ -s "${HOME}"/.oveconfig ]; then
			cp -a "${HOME}"/.oveconfig "${OVE_TMP}/${tag}-oveconfig"
			run "lxc file push --uid $_uid ${OVE_TMP}/${tag}-oveconfig ${lxc_name}${_home}/.oveconfig"
		fi

		# ove.bash
		if [ -s "${HOME}"/.ove.bash ]; then
			cp -a "${HOME}"/.ove.bash "${OVE_TMP}/${tag}-ove.bash"
			run "lxc file push --uid $_uid ${OVE_TMP}/${tag}-ove.bash ${lxc_name}${_home}/.ove.bash"
		fi

		if [[ ${OVE_DISTROCHECK_STEPS} == *user* ]]; then
			# expose OVE workspace
			run "lxc config device add ${lxc_name} ove-base disk source=${OVE_BASE_DIR} path=${OVE_BASE_DIR}"
			run "lxc config device add ${lxc_name} ove-tmp disk source=${OVE_TMP} path=${OVE_TMP}"
			run "lxc config device add ${lxc_name} ove-state disk source=${OVE_GLOBAL_STATE_DIR} path=${OVE_GLOBAL_STATE_DIR}"
			ws_name="${OVE_BASE_DIR}"
			prefix="cd ${ws_name}; source ove hush"
		else
			# search for a SETUP file
			if [ "${OVE_OWEL_DIR}" != "x" ] && [ -s "${OVE_OWEL_DIR}/SETUP" ]; then
				lxc_exec "bash -c '$(cat "${OVE_OWEL_DIR}"/SETUP)'"
				ws_name=$(lxc_exec "bash -c 'find -mindepth 2 -maxdepth 2 -name .owel' | cut -d/ -f2")
				if [ "x${ws_name}" = "x" ]; then
					echo "error: workspace name not found"
					exit 1
				fi
			else
				# fallback to ove-tutorial
				ws_name="distrocheck"
				lxc_exec "bash -c 'curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s ${ws_name} https://github.com/Ericsson/ove-tutorial'"
			fi
			prefix="cd ${ws_name}; source ove hush"
		fi

		if [ ${unittest} -eq 1 ]; then
			lxc_exec "bash -c ${bash_opt} 'cd ${ws_name}; source ove'"
			lxc_exec "bash -c ${bash_opt} '${prefix}; ove-env'"
			lxc_exec "bash -c ${bash_opt} '${prefix}; ove-list-externals'"
			lxc_exec "bash -c ${bash_opt} '${prefix}; ove-status'"
		fi

		package_manager_noconfirm
		if [[ ${distro} == *opensuse* ]]; then
			lxc_exec "sudo zypper install -y -t pattern devel_basis"
		fi
	fi

	if [ ${unittest} -eq 1 ]; then
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
			lxc_exec "${package_manager} alpine-sdk cabal ghc libffi-dev"
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
		lxc_exec "bash -c ${bash_opt} '${prefix}; ove-unittest'"
	fi

	if [ "x${distcheck}" != "x" ]; then
		if [[ ${OVE_DISTROCHECK_STEPS} == *ove* ]]; then
			# sanity check project
			if ! lxc_exec_no_exit "bash -c ${bash_opt} '${prefix}; ove-list-projects $distcheck &> /dev/null'"; then
				echo "error: unknown project '$distcheck'"
				exit 1
			fi

			packs=$(lxc_exec "bash -c ${bash_opt} '${prefix}; DEBIAN_FRONTEND=noninteractive ove-list-needs $distcheck'")
			packs=${packs//$'\r'/ }
			packs=${packs//$'\n'/}
			if [ "$packs" != "" ]; then
				LXC_EXEC_EXTRA="--user 0" lxc_exec "${package_manager} ${packs}"
			fi

			# worktree?
			if [[ $OVE_DISTROCHECK_STEPS == *worktree* ]]; then
				lxc_exec "bash -c ${bash_opt} '${prefix}; ove-add-config $_home/.oveconfig OVE_REVTAB_CHECK 0'"
				if [[ ${OVE_DISTROCHECK_STEPS} == *user* ]]; then
					worktree_dir="${OVE_TMP}/${tag}"
				else
					worktree_dir="/var/tmp/${tag}"
				fi

				lxc_exec "bash -c ${bash_opt} '${prefix}; ove-worktree add ${worktree_dir}'"
				prev_prefix="$prefix"
				prefix="cd ${worktree_dir}; source ove hush"
			fi

			lxc_exec "bash -c ${bash_opt} '${prefix}; OVE_AUTO_CLONE=1 ove-distcheck $distcheck'"

			# remove worktree
			if [[ $OVE_DISTROCHECK_STEPS == *worktree* ]]; then
				lxc_exec "bash -c ${bash_opt} '${prev_prefix}; ove-worktree remove ${worktree_dir}'"
			fi
		else
			if [ -s "${distcheck}" ]; then
				cp -a "${distcheck}" "${OVE_TMP}/${tag}.cmd"
			else
				echo "$distcheck" > "${OVE_TMP}/${tag}.cmd"
			fi
			chmod +x "${OVE_TMP}/${tag}.cmd"
			run "lxc file push --uid 0 --gid 0 ${OVE_TMP}/${tag}.cmd ${lxc_name}/var/tmp/${tag}.cmd"
			lxc_exec "/var/tmp/${tag}.cmd"
		fi
	fi
}

main "$@"
