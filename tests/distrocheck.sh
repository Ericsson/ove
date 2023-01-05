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

lxc_ip=""
lxc_name=""
tag=""
_user=
use_ssh=0

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
		lxc_exec_flags="-t"
	fi

	distro="$2"

	if [ ! -v OVE_DISTROCHECK_STEPS ]; then
		OVE_DISTROCHECK_STEPS=""
	fi

	lxc_global_flags="--force-local"
	if [[ ${OVE_DISTROCHECK_STEPS} == *verbose* ]]; then
		for s in ${OVE_DISTROCHECK_STEPS//:/ };do
			echo ${s}
		done
	elif lxc -h | grep -q '\-q'; then
		lxc_global_flags+=" -q"
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *ssh* ]]; then
		if ! command -v sshpass > /dev/null; then
			echo "error: command sshpass missing"
			exit 1
		fi
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
			if [ "x${NO_EXIT}" = "x1" ]; then
				return 1
			else
				exit 1
			fi
		fi

		sleep_s=$((RANDOM%10))
		if grep "^Error:.*i/o timeout" "${OVE_TMP}/${tag}.err"; then
			ove-echo warning_noprefix "lxd: i/o timeout. Retry in ${sleep_s} sec"
			sleep ${sleep_s}
			continue
		elif grep "^Error: websocket:" "${OVE_TMP}/${tag}.err"; then
			ove-echo warning_noprefix "lxd: websocket error. Retry in ${sleep_s} sec"
			sleep ${sleep_s}
			continue
		elif grep "^Error: Missing event connection with target cluster member" "${OVE_TMP}/${tag}.err"; then
			ove-echo warning_noprefix "lxd: cluster error. Retry in ${sleep_s} sec"
			sleep ${sleep_s}
			continue
		elif grep "^Error: Operation not found" "${OVE_TMP}/${tag}.err"; then
			ove-echo warning_noprefix "lxd: operation not found error. Retry in ${sleep_s} sec"
			sleep ${sleep_s}
			continue
		elif grep -q "^Error: Command not found" "${OVE_TMP}/${tag}.err"; then
			true
		else
			cat "${OVE_TMP}/${tag}.err"
		fi

		if [ "x${NO_EXIT}" = "x1" ]; then
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

function ssh_exec {
       local prefix

       _echo "ssh ${_user}@${lxc_ip} $*"
       if ! ssh -t -o StrictHostKeyChecking=no ${_user:?}@${lxc_ip} "$@"; then
               return 1
       fi

       return 0
}

function lxc_exec {
	local e
	local lxc_exec_options

	if [ ${use_ssh} -eq 1 ]; then
		if ! ssh_exec "$@"; then
			return 1
		fi
		return 0
	fi

	lxc_exec_options="${lxc_exec_flags} --env DEBIAN_FRONTEND=noninteractive"
	for e in ftp_proxy http_proxy https_proxy; do
		if [ "x${!e}" = "x" ]; then
			continue
		fi
		lxc_exec_options+=" --env ${e}=${!e}"
	done

	if [ "x${LXC_EXEC_EXTRA}" != "x" ]; then
		lxc_exec_options+=" ${LXC_EXEC_EXTRA}"
	fi

	run "lxc ${lxc_global_flags} exec ${lxc_exec_options} ${lxc_name} -- $*"
}

function lxc_exec_no_exit {
	local e
	local lxc_exec_options

	if [ ${use_ssh} -eq 1 ]; then
		if ! ssh_exec "$@"; then
			return 1
		fi
		return 0
	fi

	lxc_exec_options="${lxc_exec_flags} --env DEBIAN_FRONTEND=noninteractive"
	for e in ftp_proxy http_proxy https_proxy; do
		if [ "x${!e}" = "x" ]; then
			continue
		fi
		lxc_exec_options+=" --env ${e}=${!e}"
	done

	if [ "x${LXC_EXEC_EXTRA}" != "x" ]; then
		lxc_exec_options+=" ${LXC_EXEC_EXTRA}"
	fi

	if ! run_no_exit "lxc ${lxc_global_flags} exec ${lxc_exec_options} ${lxc_name} -- $*"; then
		return 1
	fi
}

function package_manager_noconfirm {
	lxc_exec "bash ${bash_opt} -c '${prefix}; ove-add-config \$HOME/.oveconfig OVE_INSTALL_PKG 1'"

	if [[ ${package_manager} == apt-get* ]];  then
		lxc_exec "bash ${bash_opt} -c '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS -y -qq -o=Dpkg::Progress=0 -o=Dpkg::Progress-Fancy=false install'"
	elif [[ ${package_manager} == pacman* ]]; then
		lxc_exec "bash ${bash_opt} -c '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS -S --noconfirm --noprogressbar'"
	elif [[ ${package_manager} == xbps-install* ]]; then
		lxc_exec "bash ${bash_opt} -c '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER xbps-install -y'"
	elif [[ ${package_manager} == zypper* ]]; then
		lxc_exec "bash ${bash_opt} -c '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y'"
	elif [[ ${package_manager} == dnf* ]]; then
		lxc_exec "bash ${bash_opt} -c '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS install -y'"
	elif [[ ${package_manager} == apk* ]]; then
		lxc_exec "bash ${bash_opt} -c '${prefix}; ove-add-config \$HOME/.oveconfig OVE_OS_PACKAGE_MANAGER_ARGS add --no-progress -q'"
	fi
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
	run_no_exit "lxc ${lxc_global_flags} stop ${lxc_name}"
	if [[ ${OVE_DISTROCHECK_STEPS} == *stopped* ]]; then
		remove_tmp
		return
	fi
	run_no_exit "lxc ${lxc_global_flags} delete ${lxc_name} --force"
	remove_tmp
}

function setup_package_manager {
	local package_refresh
	local packman

	run "lxc ${lxc_global_flags} file pull ${lxc_name}/var/tmp/${tag}-packman ${OVE_TMP}/${tag}-packman"
	if [ ! -s "${OVE_TMP}/${tag}-packman" ]; then
		echo "error: could not determine package manager for ${distro}"
		exit 1
	fi

	packman=$(cat "${OVE_TMP}/${tag}-packman")
	if [ "${packman}" = "apk" ]; then
		package_manager="apk add --no-progress -q"
		if lxc_exec_no_exit "timeout 10 apk update"; then
			return 0
		fi

		# shellcheck disable=SC2086
		lxc ${lxc_global_flags} exec ${lxc_name} -- sed -i 's/https/http/g' /etc/apk/repositories
		if lxc_exec_no_exit "timeout 10 apk update"; then
			return 0
		fi

		echo "error: apk update failed"
		exit 1
	elif [ "${packman}" = "pacman" ]; then
		package_refresh="pacman -Syu --noconfirm -q --noprogressbar"
		package_manager="pacman -S --noconfirm -q --noprogressbar"
	elif [ "${packman}" = "apt-get" ]; then
		if [[ ${OVE_DISTROCHECK_STEPS} == *ove* ]]; then
			ove_packs="bsdmainutils procps "
		fi
		package_manager="apt-get -y -qq -o=Dpkg::Progress=0 -o=Dpkg::Progress-Fancy=false install"
		if [ -s "/etc/apt/apt.conf" ]; then
			cp -a "/etc/apt/apt.conf" "${OVE_TMP}/${tag}-apt.conf"
			run "lxc ${lxc_global_flags} file push --uid 0 --gid 0 ${OVE_TMP}/${tag}-apt.conf ${lxc_name}/etc/apt/apt.conf"
		fi
		package_refresh="apt-get update"
	elif [ "${packman}" = "xbps" ]; then
		package_manager="xbps-install -y"
	elif [ "${packman}" = "dnf" ]; then
		package_manager="dnf install -y"
	elif [ "${packman}" = "zypper" ]; then
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

function setup_sshd {
	lxc_exec_no_exit "${package_manager} openssh-server"
	lxc_exec_no_exit "${package_manager} openssh"

	if [[ ${distro} == *opensuse* ]]; then
		lxc_exec_no_exit "cp -av /usr/etc/ssh/sshd_config /etc/ssh/"
	elif [[ ${distro} == *void* ]]; then
		lxc_exec_no_exit "ln -s /etc/sv/sshd /var/service"
	fi

	cat > "${OVE_TMP}/${tag}-sshd" <<EOF
#!/usr/bin/env sh

if ! sed -i \
	-e 's,.*PermitRootLogin.*,PermitRootLogin yes,g' \
	-e 's,.*PermitUserEnvironment.*,PermitUserEnvironment yes,g' \
	-e 's,.*PasswordAuthentication.*,PasswordAuthentication yes,g' /etc/ssh/sshd_config; then
	exit 1
fi
exit 0
EOF
	run "lxc ${lxc_global_flags} file push --uid 0 --gid 0 ${OVE_TMP}/${tag}-sshd ${lxc_name}/var/tmp/${tag}-sshd"
	use_ssh=0 _user=root lxc_exec "sh /var/tmp/${tag}-sshd"

	if [[ ${distro} == *alpine* ]]; then
		lxc_exec "rc-update add sshd"
		lxc_exec "/etc/init.d/sshd start"
	else
		lxc_exec_no_exit "systemctl -q restart ssh sshd"
	fi

	wait_for_ssh_server

	lxc_ip=$(lxc list -c4 --format csv ${lxc_name})
	lxc_ip=${lxc_ip% *}
	if [ "x${lxc_ip}" = "x" ]; then
		echo "error: no IPv4 address for ${lxc_name}"
		exit 1
	fi
	_echo "${lxc_name}=${lxc_ip}"
}

function wait_for_ssh_server {
	local i

	i=0
	while true; do
		((i++))
		if [ ${i} -gt 100 ]; then
			echo "error: sshd did not start"
			exit 1
		elif lxc_exec_no_exit "pgrep -f sshd" > /dev/null; then
			# FIXME
			_echo "sleep 1 sec"
			sleep 1
			break;
		fi

		_echo "waiting for sshd ${i}"
		sleep 0.1
	done
}

# $1: user
function setup_ssh {
	local pass="${RANDOM}${RANDOM}${RANDOM}"

	_user="$1"

	if [[ ${distro} == *alpine* ]]; then
		cat > "${OVE_TMP}/${tag}-passwd-${_user}" <<EOF
echo -e "${pass}\n${pass}" | passwd ${_user} &> /dev/null
EOF
		run "lxc ${lxc_global_flags} file push --uid 0 --gid 0 ${OVE_TMP}/${tag}-passwd-${_user} ${lxc_name}/var/tmp/${tag}-passwd-${_user}"
		# shellcheck disable=SC2097,SC2098
		use_ssh=0 _user=root lxc_exec "sh /var/tmp/${tag}-passwd-${_user}"
	else
		# shellcheck disable=SC2097,SC2098
		use_ssh=0 _user=root lxc_exec "usermod -p '$(openssl passwd -1 ${pass})' ${_user}"
	fi

	if [ -s "${HOME}/.ssh/known_hosts" ]; then
		_echo "remove any previous entries in known_hosts"
		ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${lxc_ip:?}" -q &> /dev/null
	fi

	_echo "copy public key to container"
	if ! sshpass -p${pass} \
		ssh-copy-id \
		-o StrictHostKeyChecking=no \
		"${_user}"@"${lxc_ip}" &> /dev/null; then
		echo "error: not possible to copy public key to ${lxc_name} ${lxc_ip}"
		exit 1
	fi

	# from now on use ssh instead of lxc exec
	use_ssh=1

	true > "${OVE_TMP}/${tag}-sshenv"
	for e in ftp_proxy http_proxy https_proxy; do
		if [ "x${!e}" = "x" ]; then
			continue
		fi
		echo "${e}=${!e}" >> "${OVE_TMP}/${tag}-sshenv"
	done

	if [ -s "${OVE_TMP}/${tag}-sshenv" ]; then
		lxc_exec "mkdir -vp .ssh"
		scp -p -q "${OVE_TMP}/${tag}-sshenv" "${_user}"@"${lxc_ip}":.ssh/environment
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
	if [ "x${OVE_DISTROCHECK_CONTAINER_PREFIX}" != "x" ]; then
		lxc_name="${OVE_DISTROCHECK_CONTAINER_PREFIX}-${lxc_name}"
	fi

	# replace slashes and dots
	lxc_name="${lxc_name//\//-}"
	lxc_name="${lxc_name//./-}"

	if [ ${#lxc_name} -gt 63 ]; then
		_echo "info: lxc name '${lxc_name}' tuncated"
		lxc_name=${lxc_name:0:63}
	fi

	# ove, user and lxc cluster? => create container on localhost
	# shellcheck disable=SC2086
	if [[ ${OVE_DISTROCHECK_LAUNCH_EXTRA_ARGS} != *--target=* ]] && \
		[[ ${OVE_DISTROCHECK_STEPS} == *ove* ]] && \
		[[ ${OVE_DISTROCHECK_STEPS} == *user* ]] && \
		lxc ${lxc_global_flags} cluster list &> /dev/null; then
		server_name=$(lxc ${lxc_global_flags} info | grep server_name | awk '{print $2}')
		if [ "x${server_name}" != "x" ]; then
			OVE_DISTROCHECK_LAUNCH_EXTRA_ARGS="--target=${server_name}"
		fi
	fi

	# ephemeral container?
	if [[ ${OVE_DISTROCHECK_STEPS} != *running* ]] && \
		[[ ${OVE_DISTROCHECK_STEPS} != *stopped* ]]; then
			OVE_DISTROCHECK_LAUNCH_EXTRA_ARGS+=" --ephemeral"
			OVE_DISTROCHECK_STEPS+=" stopped"
	fi

	if [[ ${distro} == *archlinux* ]] || [[ ${distro} == *fedora* ]]; then
		OVE_DISTROCHECK_LAUNCH_EXTRA_ARGS+=" -c security.nesting=true"
	fi

	# shellcheck disable=SC2086
	if ! lxc ${lxc_global_flags} launch images:${distro} ${lxc_name} ${OVE_DISTROCHECK_LAUNCH_EXTRA_ARGS//\#/ } > /dev/null; then
		exit 1
	fi
	trap cleanup EXIT

	cat > "${OVE_TMP}/${tag}-bootcheck.sh" <<EOF
#!/usr/bin/env sh

if command -v apk > /dev/null; then
	packman="apk"
elif command -v pacman > /dev/null; then
	packman="pacman"
elif command -v apt-get > /dev/null; then
	packman="apt-get"
elif command -v dnf > /dev/null; then
	packman="dnf"
elif command -v zypper > /dev/null; then
	packman="zypper"
elif command -v xbps-install > /dev/null; then
	packman="xbps"
else
	echo "bootcheck: unknown package manager for ${distro}"
	packman="unknown"
fi
echo "\$packman" > /var/tmp/${tag}-packman

if command -v systemctl > /dev/null; then
	cmd="systemctl is-system-running"
	exp="running"
elif command -v rc-status > /dev/null; then
	cmd="rc-status -r"
	exp="default"
elif command -v sv > /dev/null; then
	cmd="readlink -f /etc/runit/runsvdir/current"
	exp="/etc/runit/runsvdir/default"
elif command -v runlevel > /dev/null; then
	cmd="runlevel"
	exp="N 2"
else
	echo "bootcheck: unknown init system for ${distro} - sleep 1 sec"
	sleep 1
	exit 0
fi

i=0
while true; do
	i=\$((i+1))
	if [ \$i -ge 200 ]; then
		exit 0
	fi
	s=\$(\$cmd 2> /dev/null);
	if [ "x\$s" = "x\$exp" ]; then
		break;
	fi
	sleep 0.01;
done
exit 0
EOF

	run "lxc ${lxc_global_flags} file push --uid 0 --gid 0 ${OVE_TMP}/${tag}-bootcheck.sh ${lxc_name}/var/tmp/${tag}-bootcheck.sh"
	lxc_exec_no_exit "sh /var/tmp/${tag}-bootcheck.sh"

	if [[ ( ${OVE_DISTROCHECK_STEPS} == *user* && ${EUID} -ne 0 ) || \
		( ${OVE_DISTROCHECK_STEPS} == *ssh* ) || \
		( ${OVE_DISTROCHECK_STEPS} == *ove* ) ]]; then
		setup_package_manager
		if [[ ${OVE_DISTROCHECK_STEPS} == *ssh* ]]; then
			setup_sshd
			setup_ssh "root"
		fi
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *user* ]] && [ ${EUID} -ne 0 ]; then
		lxc_exec "${package_manager} bash"
		if [[ ${distro} == *alpine* ]]; then
			lxc_exec "${package_manager} shadow sudo"
		fi
		lxc_exec "useradd --shell /bin/bash -m -d ${HOME:?} ${OVE_USER:?}"
		while true; do
			_uid=$(lxc_exec "id -u ${OVE_USER}")
			_uid=${_uid/$'\r'/}
			if [[ ! "${_uid}" =~ ^[0-9]+$ ]]; then
				sleep_s=$((RANDOM%10))
				ove-echo warning_noprefix "wrong uid ${_uid}. Retry in ${sleep_s} sec"
				sleep ${sleep_s}
				continue
			fi
			break
		done
		_home=${HOME}

		_echo "idmap"
		# shellcheck disable=SC2086
		printf "uid %s ${_uid}\ngid %s ${_uid}" "$(id -u)" "$(id -g)" | \
			lxc ${lxc_global_flags} config set "${lxc_name}" raw.idmap -

		_echo "user and sudo"
		echo "${OVE_USER} ALL=(ALL) NOPASSWD:ALL" > "${OVE_TMP}/${tag}-sudoers"
		run "lxc ${lxc_global_flags} file push --uid 0 --gid 0 ${OVE_TMP}/${tag}-sudoers ${lxc_name}/etc/sudoers.d/91-ove"

		run "lxc ${lxc_global_flags} restart ${lxc_name}"
		use_ssh=0 lxc_exec "sh /var/tmp/${tag}-bootcheck.sh"

		if [[ ${OVE_DISTROCHECK_STEPS} == *ssh* ]]; then
			wait_for_ssh_server
			setup_ssh "${OVE_USER}"
		fi
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *ove* ]]; then
		ove_packs+="bash bzip2 git curl file binutils util-linux coreutils tar"

		# install OVE packages
		_user=root lxc_exec "${package_manager} ${ove_packs}"

		if [[ ${distro} == *archlinux* ]]; then
			lxc_exec "sed -i 's|#en_US.UTF-8 UTF-8|en_US.UTF-8 UTF-8|g' /etc/locale.gen"
			lxc_exec "locale-gen"
		fi
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *user* ]] && [ ${EUID} -ne 0 ]; then
		# from now on, run all lxc exec commands as user
		export LXC_EXEC_EXTRA="--user ${_uid} --env HOME=${HOME}"
	fi

	if [[ ${OVE_DISTROCHECK_STEPS} == *ove* ]]; then
		# gitconfig
		if [ -s "${HOME}"/.gitconfig ]; then
			cp -a "${HOME}"/.gitconfig "${OVE_TMP}/${tag}-gitconfig"
			run "lxc ${lxc_global_flags} file push --uid ${_uid} ${OVE_TMP}/${tag}-gitconfig ${lxc_name}${_home}/.gitconfig"
		fi

		# oveconfig
		if [ -s "${HOME}"/.oveconfig ]; then
			cp -a "${HOME}"/.oveconfig "${OVE_TMP}/${tag}-oveconfig"
			run "lxc ${lxc_global_flags} file push --uid ${_uid} ${OVE_TMP}/${tag}-oveconfig ${lxc_name}${_home}/.oveconfig"
		fi

		# ove.bash
		if [ -s "${HOME}"/.ove.bash ]; then
			cp -a "${HOME}"/.ove.bash "${OVE_TMP}/${tag}-ove.bash"
			run "lxc ${lxc_global_flags} file push --uid ${_uid} ${OVE_TMP}/${tag}-ove.bash ${lxc_name}${_home}/.ove.bash"
		fi

		if [[ ${OVE_DISTROCHECK_STEPS} == *user* ]]; then
			# expose OVE workspace
			run "lxc ${lxc_global_flags} config device add ${lxc_name} ove-base disk source=${OVE_BASE_DIR} path=${OVE_BASE_DIR}"
			run "lxc ${lxc_global_flags} config device add ${lxc_name} ove-tmp disk source=${OVE_TMP} path=${OVE_TMP}"
			run "lxc ${lxc_global_flags} config device add ${lxc_name} ove-state disk source=${OVE_GLOBAL_STATE_DIR} path=${OVE_GLOBAL_STATE_DIR}"
			ws_name="${OVE_BASE_DIR}"
			prefix="cd ${ws_name}; source ove hush"
		else
			if [ -x "${OVE_OWEL_DIR}/SETUP" ]; then
				run "lxc ${lxc_global_flags} file push --uid ${_uid} ${OVE_OWEL_DIR}/SETUP ${lxc_name}${_home}/SETUP"
				lxc_exec "bash ${_home}/SETUP"
			else
				lxc_exec "bash -c '$(ove-setup)'"
			fi
			ws_name=$(lxc_exec "bash -c 'find -mindepth 2 -maxdepth 2 -name .owel' | cut -d/ -f2")
			ws_name=${ws_name//$'\r'/}
			if [ "x${ws_name}" = "x" ]; then
				ws_name="ove-tutorial"
				ove-echo cyan "using ${ws_name} as OVE workspace (fallback)"
				lxc_exec "bash -c 'curl -sSL https://raw.githubusercontent.com/Ericsson/ove/master/setup | bash -s ${ws_name} https://github.com/Ericsson/${ws_name}'"
			fi
			prefix="cd ${ws_name}; source ove hush"
		fi

		if [ ${unittest} -eq 1 ]; then
			lxc_exec "bash ${bash_opt} -c 'cd ${ws_name}; source ove'"
			lxc_exec "bash ${bash_opt} -c '${prefix}; ove-env'"
			lxc_exec "bash ${bash_opt} -c '${prefix}; ove-list-externals'"
			lxc_exec "bash ${bash_opt} -c '${prefix}; ove-status'"
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

		if [[ ${distro} == *almalinux* ]]; then
			lxc_exec "${package_manager} epel-release"
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
		lxc_exec "bash ${bash_opt} -c '${prefix}; ove-unittest'"
	fi

	if [ "x${distcheck}" != "x" ]; then
		if [[ ${OVE_DISTROCHECK_STEPS} == *ove* ]]; then
			# sanity check project
			if ! lxc_exec_no_exit "bash ${bash_opt} -c '${prefix}; ove-list-projects ${distcheck} > /dev/null'"; then
				echo "error: unknown project '${distcheck}'"
				exit 1
			fi

			packs=$(lxc_exec "bash ${bash_opt} -c '${prefix}; DEBIAN_FRONTEND=noninteractive ove-list-needs ${distcheck}'")
			packs=${packs//$'\r'/ }
			packs=${packs//$'\n'/}
			if [ "${packs}" != "" ]; then
				_user=root LXC_EXEC_EXTRA="--user 0" lxc_exec "${package_manager} ${packs}"
			fi

			# worktree?
			if [[ ${OVE_DISTROCHECK_STEPS} == *worktree* ]]; then
				lxc_exec "bash ${bash_opt} -c '${prefix}; ove-add-config ${_home}/.oveconfig OVE_REVTAB_CHECK 0'"
				if [[ ${OVE_DISTROCHECK_STEPS} == *user* ]]; then
					worktree_dir="${OVE_TMP}/${tag}"
				else
					worktree_dir="/var/tmp/${tag}"
				fi

				lxc_exec "bash ${bash_opt} -c '${prefix}; ove-worktree add ${worktree_dir}'"
				prev_prefix="${prefix}"
				prefix="cd ${worktree_dir}; source ove hush"
			fi

			lxc_exec "bash ${bash_opt} -c '${prefix}; OVE_AUTO_CLONE=1 ove-distcheck ${distcheck}'"

			# remove worktree
			if [[ ${OVE_DISTROCHECK_STEPS} == *worktree* ]]; then
				lxc_exec "bash ${bash_opt} -c '${prev_prefix}; ove-worktree remove ${worktree_dir}'"
			fi
		else
			if [ -s "${distcheck}" ]; then
				cp -a "${distcheck}" "${OVE_TMP}/${tag}.cmd"
			else
				echo "${distcheck}" > "${OVE_TMP}/${tag}.cmd"
			fi
			chmod +x "${OVE_TMP}/${tag}.cmd"
			run "lxc ${lxc_global_flags} file push --uid 0 --gid 0 ${OVE_TMP}/${tag}.cmd ${lxc_name}/var/tmp/${tag}.cmd"
			lxc_exec "/var/tmp/${tag}.cmd"
		fi
	fi
}

main "$@"
