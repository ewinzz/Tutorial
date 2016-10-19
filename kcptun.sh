#!/bin/bash

<<COM
Copyright (C) 2016 Xingwang Liao

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
COM

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

SHELL_VERSION=5
CONFIG_VERSION=2
INIT_VERSION=1

clear
echo
echo "#############################################################"
echo "# Kcptun Server һ����װ�ű�                                #"
echo "# �ýű�֧�� Kcptun Server �İ�װ�����¡�ж�ؼ�����         #"
echo "# �ٷ���վ: https://blog.kuoruan.com/                       #"
echo "# ����: Index <kuoruan@gmail.com>                           #"
echo "# ��л: �ű���д�����вο��� @teddysun ��SSһ����װ�ű�     #"
echo "# QQ����Ⱥ: 43391448                                        #"
echo "#############################################################"
echo

# Get current dir
CUR_DIR=`pwd`

# Get public IP address
IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
[ -z "$IP" ] && IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)

# Make sure only root can run our script
function rootness(){
	if [ $EUID -ne 0 ]; then
		echo "Ȩ�޴���, ��ʹ�� root �û����д˽ű���"
		exit 1
	fi
}

# Check OS
function checkos(){
	if [ -f /etc/redhat-release ]; then
		OS='CentOS'
	elif [ ! -z "`cat /etc/issue | grep bian`" ]; then
		OS='Debian'
	elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ]; then
		OS='Ubuntu'
	else
		echo "�ݲ�֧�ִ�ϵͳ, ����װϵͳ�����ԣ�"
		exit_shell
	fi
}

# Get mechine type
function get_machine_type(){
	local type=`uname -m`;
	[ -z "$type" ] && type=`getconf LONG_BIT`;
	if [[ "$type" == *'64'* ]]; then
		SPRUCE_TYPE='linux-amd64'
		FILE_SUFFIX='linux_amd64'
	else
		SPRUCE_TYPE='linux-386'
		FILE_SUFFIX='linux_386'
	fi
}

# CentOS version
function centosversion(){
	if [ "$OS" == 'CentOS' ]; then
		local code=$1
		local version="`get_osversion`"
		local main_ver=${version%%.*}
		if [ $main_ver == $code ]; then
			return 0
		else
			return 1
		fi
	else
		return 1
	fi
}

# Get OS version
function get_osversion(){
	if [ -s /etc/redhat-release ]; then
		grep -oE "[0-9.]+" /etc/redhat-release
	else
		grep -oE "[0-9.]+" /etc/issue
	fi
}

# Disable selinux
function disable_selinux(){
	if [ -s /etc/selinux/config ] && grep -q 'SELINUX=enforcing' /etc/selinux/config; then
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
		setenforce 0
	fi
}

# Exit shell
function exit_shell(){
	echo
	echo "Kcptun Server ��װʧ�ܣ�"
	echo "ϣ�����ܼ�¼�´�����Ϣ, Ȼ�󽫴�����Ϣ���͸���"
	echo "�ҵ�����: kuoruan@gmail.com"
	echo "��ӭ�������ǵ�QQȺ: 43391448"
	echo "�����ͣ�https://blog.kuoruan.com"
	echo
	exit 1
}

function click_to_continue(){
	get_char(){
		SAVEDSTTY=`stty -g`
		stty -echo
		stty cbreak
		dd if=/dev/tty bs=1 count=1 2> /dev/null
		stty -raw
		stty echo
		stty $SAVEDSTTY
	}
	char=`get_char`
}

check_install() {
	if [ -f /etc/supervisor/supervisord.conf -a -d /usr/share/kcptun/ ]; then
		echo "�ƺ���������װ�� Kcptun Server"
		echo
		while true
		do
			echo "��ѡ����ϣ���Ĳ���:"
			echo "(1) ���ǰ�װ"
			echo "(2) ��������"
			echo "(3) ������"
			echo "(4) ж��"
			echo "(5) �˳�"
			read -p "(��ѡ�� [1~5], Ĭ��: ���ǰ�װ):" sel
			if [ -z "$sel" ]; then
				echo "��ʼ���ǰ�װ Kcptun Server..."
				echo
				return
			else
				expr $sel + 0 &> /dev/null
				if [ $? -eq 0 ]; then
					case $sel in
						1)
							echo "��ʼ���ǰ�װ Kcptun Server..."
							echo
							return
							;;
						2)
							reconfig_kcptun
							exit 0
							;;
						3)
							check_update
							exit 0
							;;
						4)
							uninstall_kcptun
							exit 0
							;;
						5)
							exit 0;;
						*)
							echo "��������Ч����(1~4)��"
							continue;;
					esac
				else
					echo "��������, ���������֣�"
				fi
			fi
		done
	fi
}

function set_config(){
	# Not support CentOS 5
	if centosversion 5; then
		echo "�ݲ�֧�� CentOS5, ����װϵͳΪ CentOS 6+, Debian 7+ ���� Ubuntu 12+ ������!"
		exit_shell
	fi

	local port_stat=""
	local sel=""
	# Set Kcptun config port
	while true
	do
		echo -e "������ Kcptun Server �˿� [1-65535]:"
		read -p "(Ĭ��: 554):" kcptunport
		[ -z "$kcptunport" ] && kcptunport="554"
		expr $kcptunport + 0 &>/dev/null
		if [ $? -eq 0 ]; then
			if [ $kcptunport -ge 1 ] && [ $kcptunport -le 65535 ]; then
				port_stat=`netstat -an | grep -E "[0-9:]:${kcptunport} .+LISTEN"`
				if [ -z "$port_stat" ]; then
					echo
					echo "---------------------------"
					echo "�˿� = $kcptunport"
					echo "---------------------------"
					echo
					break
				else
					echo "�˿��ѱ�ռ��, ���������룡"
				fi
			else
				echo "��������, ������ 1~65535 ֮������֣�"
			fi
		else
			echo "��������, ���������֣�"
		fi
	done

	# Set Kcptun forward port
	while true
	do
		echo -e "��������Ҫ���ٵ� IP [0.0.0.0 ~ 255.255.255.255]:"
		read -p "(Ĭ��: 127.0.0.1):" forwardip
		[ -z "$forwardip" ] && forwardip="127.0.0.1"
		echo "$forwardip" | grep -qE '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
		if [ $? -eq 0 ]; then
			echo
			echo "---------------------------"
			echo "���� IP = $forwardip"
			echo "---------------------------"
			echo
			break
		else
			echo "��������, ��������ȷ�� IP ��ַ��"
		fi
	done

	# Set Kcptun forward port
	while true
	do
		echo -e "��������Ҫ���ٵĶ˿� [1-65535]:"
		read -p "(Ĭ��: 8388):" forwardport
		[ -z "$forwardport" ] && forwardport="8388"
		expr $forwardport + 0 &>/dev/null
		if [ $? -eq 0 ]; then
			if [ $forwardport -ge 1 ] && [ $forwardport -le 65535 ]; then
				port_stat=`netstat -an | grep -E "[0-9:]:${forwardport} .+LISTEN"`
				if [ -z "$port_stat" ]; then
					read -p "��ǰû�����ʹ�ô˶˿�, ȷ�����ٴ˶˿�?(y/n)" yn
					case ${yn:0:1} in
						y|Y) ;;
						*) continue;;
					esac
				fi
				echo
				echo "---------------------------"
				echo "���ٶ˿� = $forwardport"
				echo "---------------------------"
				echo
				break
			else
				echo "��������, ������ 1~65535 ֮������֣�"
			fi
		else
			echo "��������, ���������֣�"
		fi
	done

	# Set Kcptun config password
	echo "������ Kcptun ����:"
	read -p "(�������ʹ������������):" kcptunpwd
	echo
	echo "---------------------------"
	if [ -z "$kcptunpwd" ]; then
		echo "δ��������"
	else
		echo "���� = $kcptunpwd"
	fi
	echo "---------------------------"
	echo

	# Set methods for encryption
	while true
	do
		echo "��ѡ����ܷ�ʽ:"
		echo "(1) aes"
		echo "(2) tea"
		echo "(3) xor"
		echo "(4) none"
		read -p "(��ѡ�� [1~4], Ĭ��: aes):" sel
		if [ -z "$sel" ]; then
			echo
			echo "-----------------------------"
			echo "��ʹ��Ĭ�ϼ��ܷ�ʽ"
			echo "-----------------------------"
			echo
			break
		else
			expr $sel + 0 &> /dev/null
			if [ $? -eq 0 ]; then
				case $sel in
					1) crypt_methods="aes";;
					2) crypt_methods="tea";;
					3) crypt_methods="xor";;
					4) crypt_methods="none";;
					*)
						echo "��������Ч����(1~4)��"
						continue;;
				esac
				echo
				echo "-----------------------------"
				echo "���ܷ�ʽ = $crypt_methods"
				echo "-----------------------------"
				echo
				break
			else
				echo "��������, ���������֣�"
			fi
		fi
	done

	# Set mode for communication
	while true
	do
		echo "��ѡ�����ģʽ (Խ��Խ�˷Ѵ���):"
		echo "(1) fast3"
		echo "(2) fast2"
		echo "(3) fast"
		echo "(4) normal"
		read -p "(��ѡ�� [1~4], Ĭ��: fast):" sel
		if [ -z "$sel" ]; then
			echo
			echo "---------------------------"
			echo "��ʹ��Ĭ�ϼ���ģʽ"
			echo "---------------------------"
			echo
			break
		else
			expr $sel + 0 &> /dev/null
			if [ $? -eq 0 ]; then
				case $sel in
					1) comm_mode="fast3";;
					2) comm_mode="fast2";;
					3) comm_mode="fast";;
					4) comm_mode="normal";;
					*)
						echo "��������Ч����(1~4)��"
						continue;;
				esac
				echo
				echo "---------------------------"
				echo "����ģʽ = $comm_mode"
				echo "---------------------------"
				echo
				break
			else
				echo "��������, ���������֣�"
			fi
		fi
	done

	while true
	do
		echo "������ UDP ���ݰ��� MTU (����䵥Ԫ)ֵ:"
		read -p "(Ĭ��: 1350):" mtu_value
		if [ -z "$mtu_value" ]; then
			echo
			echo "---------------------------"
			echo "MTU ��ʹ��Ĭ��ֵ"
			echo "---------------------------"
			echo
			break
		else
			expr $mtu_value + 0 &> /dev/null
			if [ $? -eq 0 ]; then
				if [ $mtu_value -gt 0 ]; then
					echo
					echo "---------------------------"
					echo "MTU = $mtu_value"
					echo "---------------------------"
					echo
					break
				else
					echo "������������"
				fi
			else
				echo "��������, ���������֣�"
			fi
		fi
	done

	while true
	do
		echo "�����÷��ʹ��ڴ�С(sndwnd):"
		read -p "(���ݰ�����, Ĭ��: 1024):" sndwnd_value
		if [ -z "$sndwnd_value" ]; then
			echo
			echo "---------------------------"
			echo "Sndwnd ��ʹ��Ĭ��ֵ"
			echo "---------------------------"
			echo
			break
		else
			expr $sndwnd_value + 0 &> /dev/null
			if [ $? -eq 0 ]; then
				if [ $sndwnd_value -gt 0 ]; then
					echo
					echo "---------------------------"
					echo "Sndwnd = $sndwnd_value"
					echo "---------------------------"
					echo
					break
				else
					echo "������������"
				fi
			else
				echo "��������, ���������֣�"
			fi
		fi
	done

	while true
	do
		echo "�����ý��մ��ڴ�С(rcvwnd):"
		read -p "(���ݰ�����, Ĭ��: 1024):" rcvwnd_value
		if [ -z "$rcvwnd_value" ]; then
			echo
			echo "---------------------------"
			echo "Rcvwnd ��ʹ��Ĭ��ֵ"
			echo "---------------------------"
			echo
			break
		else
			expr $rcvwnd_value + 0 &> /dev/null
			if [ $? -eq 0 ]; then
				if [ $rcvwnd_value -gt 0 ]; then
					echo
					echo "---------------------------"
					echo "Rcvwnd = $rcvwnd_value"
					echo "---------------------------"
					echo
					break
				else
					echo "������������"
				fi
			else
				echo "��������, ���������֣�"
			fi
		fi
	done

	while true
	do
		read -p "�Ƿ��������ѹ��? (Ĭ��: ������) (y/n)):" yn
		[ -z "$yn" ] && yn="n"
		case ${yn:0:1} in
			y|Y) nocomp="y";;
			n|N) nocomp="";;
			*)
				echo "��������, ���������룡"
				continue;;
		esac
		echo
		echo "---------------------------"
		if [ "$nocomp" == "y" ]; then
			echo "����ѹ���������ã�"
		else
			echo "����������ѹ����"
		fi
		echo "---------------------------"
		echo
		break
	done

	while true
	do
		echo "������ǰ����� Datashard:"
		read -p "(Ĭ��: 10):" datashard_value
		if [ -z "$datashard_value" ]; then
			echo
			echo "---------------------------"
			echo "Datashard ��ʹ��Ĭ��ֵ"
			echo "---------------------------"
			echo
			break
		else
			expr $datashard_value + 0 &> /dev/null
			if [ $? -eq 0 ]; then
				if [ $datashard_value -gt 0 ]; then
					echo
					echo "---------------------------"
					echo "Datashard = $datashard_value"
					echo "---------------------------"
					echo
					break
				else
					echo "������������"
				fi
			else
				echo "��������, ���������֣�"
			fi
		fi
	done

	while true
	do
		echo "������ǰ����� Parityshard:"
		read -p "(Ĭ��: 3):" parityshard_value
		if [ -z "$parityshard_value" ]; then
			echo
			echo "---------------------------"
			echo "Parityshard ��ʹ��Ĭ��ֵ"
			echo "---------------------------"
			echo
			break
		else
			expr $parityshard_value + 0 &> /dev/null
			if [ $? -eq 0 ]; then
				if [ $parityshard_value -gt 0 ]; then
					echo
					echo "---------------------------"
					echo "Parityshard = $parityshard_value"
					echo "---------------------------"
					echo
					break
				else
					echo "������������"
				fi
			else
				echo "��������, ���������֣�"
			fi
		fi
	done

	while true
	do
		echo "�����ò�ַ������� DSCP:"
		read -p "(Ĭ��: 0):" dscp_value
		if [ -z "$dscp_value" ]; then
			echo
			echo "---------------------------"
			echo "DSCP ��ʹ��Ĭ��ֵ"
			echo "---------------------------"
			echo
			break
		else
			expr $dscp_value + 0 &> /dev/null
			if [ $? -eq 0 ]; then
				if [ $dscp_value -gt 0 ]; then
					echo
					echo "---------------------------"
					echo "DSCP = $dscp_value"
					echo "---------------------------"
					echo
					break
				fi
			else
				echo "��������, ���������0������, ��ֱ�ӻس���"
			fi
		fi
	done

	KCPTUN_SERVER_ARGS="-t \"${forwardip}:${forwardport}\" -l \":${kcptunport}\""
	[ -n "$kcptunpwd" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --key \"${kcptunpwd}\""
	[ -n "$crypt_methods" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --crypt ${crypt_methods}"
	[ -n "$comm_mode" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --mode ${comm_mode}"
	[ -n "$mtu_value" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --mtu ${mtu_value}"
	[ -n "$sndwnd_value" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --sndwnd ${sndwnd_value}"
	[ -n "$rcvwnd_value" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --rcvwnd ${rcvwnd_value}"
	[ -n "$nocomp" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --nocomp"
	[ -n "$datashard_value" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --datashard ${datashard_value}"
	[ -n "$parityshard_value" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --parityshard ${parityshard_value}"
	[ -n "$dscp_value" ] && KCPTUN_SERVER_ARGS="${KCPTUN_SERVER_ARGS} --dscp ${dscp_value}"

	echo
	echo "�����������, �����������...���� Ctrl+C ȡ��"
	click_to_continue
}

# Pre-installation settings
function pre_install(){
	# Install necessary dependencies
	if [ "$OS" == 'CentOS' ]; then
		yum install -y epel-release
		yum --enablerepo=epel install -y curl wget jq python-setuptools
	else
		apt-get -y update
		apt-get -y install curl wget jq python-setuptools
		if [ $? -ne 0 ]; then
			if [ "$OS" == 'Debian' ]; then
				echo "deb http://ftp.debian.org/debian wheezy-backports main contrib non-free" >> /etc/apt/sources.list
			else
				echo "deb http://archive.ubuntu.com/ubuntu vivid main universe" >> /etc/apt/sources.list
			fi
			apt-get -y update
			apt-get -y install curl wget jq python-setuptools
			if [ $? -ne 0 ]; then
				echo "��װ���������ʧ�ܣ�"
				exit_shell
			fi
		fi
	fi
	easy_install supervisor
	if [ $? -ne 0 ]; then
		echo "��װ Supervisor ʧ�ܣ�"
		exit_shell
	fi
	mkdir -p /etc/supervisor/conf.d
	[ -f /etc/supervisor/supervisord.conf ] || echo_supervisord_conf > /etc/supervisor/supervisord.conf
	cd $CUR_DIR
}

# Get json contnet
function get_json_content(){
	KCPTUN_CONTENT=`curl -sfk https://api.github.com/repos/xtaci/kcptun/releases/latest`
	VERSION_CONTENT=`curl -sfk https://raw.githubusercontent.com/kuoruan/kcptun_installer/master/kcptun.json`
	if [ -z "$KCPTUN_CONTENT" ]; then
		echo "��ȡ Kcptun �ļ���Ϣʧ��, ��������������ӣ�"
		exit_shell
	fi
	[ -z "$VERSION_CONTENT" ] && VERSION_CONTENT="{}"
}

# Download kcptun file
function download_file(){
	cd $CUR_DIR
	download_url=`echo "$KCPTUN_CONTENT" | jq -r ".assets[] | select(.name | contains(\"$SPRUCE_TYPE\")) | .browser_download_url"`;

	# Download Kcptun file
	if ! wget --no-check-certificate -O kcptun-"$SPRUCE_TYPE".tar.gz "$download_url"; then
		echo "���� Kcptun �ļ�ʧ�ܣ�"
		exit_shell
	fi
}

# firewall set
function firewall_set(){
	echo "�������÷���ǽ..."
	if centosversion 6; then
		/etc/init.d/iptables status > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			iptables -L -n | grep '${kcptunport}' | grep 'ACCEPT' > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${kcptunport} -j ACCEPT
				iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${kcptunport} -j ACCEPT
				/etc/init.d/iptables save
				/etc/init.d/iptables restart
			else
				echo "�˿� ${kcptunport} �����ã�"
			fi
		else
			echo "����: iptables �ѹرջ�δ��װ, ����б�Ҫ, ���ֶ���Ӷ˿� ${kcptunport} �ķ���ǽ����"
		fi
	elif centosversion 7; then
		systemctl status firewalld > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			firewall-cmd --permanent --zone=public --add-port=${kcptunport}/tcp
			firewall-cmd --permanent --zone=public --add-port=${kcptunport}/udp
			firewall-cmd --reload
		else
			echo "Firewalld δ����, ���ڳ�������..."
			systemctl start firewalld
			if [ $? -eq 0 ]; then
				firewall-cmd --permanent --zone=public --add-port=${kcptunport}/tcp
				firewall-cmd --permanent --zone=public --add-port=${kcptunport}/udp
				firewall-cmd --reload
			else
				echo "����: �������� Firewalld ʧ��, ����б�Ҫ, ���ֶ���Ӷ˿� ${kcptunport} �ķ���ǽ����"
			fi
		fi
	fi
	echo "����ǽ�������óɹ���"
}

# Config kcptun
function config_kcptun(){
	if [ -f /etc/supervisor/supervisord.conf ]; then
		# sed -i 's/^\[include\]$/&\nfiles = \/etc\/supervisor\/conf.d\/\*\.conf/;t;$a [include]\nfiles = /etc/supervisor/conf.d/*.conf' /etc/supervisor/supervisord.conf

		if ! grep -q "^files\s*=\s*\/etc\/supervisor\/conf\.d\/\*\.conf$" /etc/supervisor/supervisord.conf; then
			if grep -q "^\[include\]$" /etc/supervisor/supervisord.conf; then
				sed -i '/^\[include\]$/a files = \/etc\/supervisor\/conf.d\/\*\.conf' /etc/supervisor/supervisord.conf
			else
				sed -i '$a [include]\nfiles = /etc/supervisor/conf.d/*.conf' /etc/supervisor/supervisord.conf
			fi
		fi

		cat > /etc/supervisor/conf.d/kcptun.conf<<-EOF
[program:kcptun]
directory=/usr/share/kcptun
; Config line. See: https://github.com/xtaci/kcptun
command=/usr/share/kcptun/server_${FILE_SUFFIX} ${KCPTUN_SERVER_ARGS}
process_name=%(program_name)s
autostart=true
redirect_stderr=true
stdout_logfile=/var/log/kcptun.log
stdout_logfile_maxbytes=1MB
stdout_logfile_backups=0
EOF
	else
		echo "δ�ҵ� Supervisor �����ļ���"
		exit_shell
	fi
}

# Download init script
downlod_init_script() {
	if [ "$OS" == 'CentOS' ]; then
		init_file_url="https://raw.githubusercontent.com/kuoruan/kcptun_installer/master/redhat.init"
	else
		init_file_url="https://raw.githubusercontent.com/kuoruan/kcptun_installer/master/ubuntu.init"
	fi
	if ! wget --no-check-certificate -O /etc/init.d/supervisord "$init_file_url"; then
		echo "���� Supervisor �����ű�ʧ�ܣ�"
		exit_shell
	fi
	chmod a+x /etc/init.d/supervisord
}

init_service(){
	if [ "$OS" == 'CentOS' ]; then
		chkconfig --add supervisord
		chkconfig supervisord on

		firewall_set
	else
		update-rc.d -f supervisord defaults
	fi

	service supervisord start
	if [ $? -ne 0 ]; then
		echo "���� Supervisord ʧ�ܣ�"
		exit_shell
	else
		sleep 5
		supervisorctl reload
		supervisorctl restart kcptun

		if [ $? -ne 0 ]; then
			echo "���� Kcptun Server ʧ�ܣ�"
			exit_shell
		fi
	fi
	cd $CUR_DIR
}

# Install cleanup
function cleanup(){
	cd $CUR_DIR
	rm -f kcptun-"$SPRUCE_TYPE".tar.gz
	rm -f /usr/share/kcptun/client_"$FILE_SUFFIX"
}

function show_config_info(){
	local kcptun_client_args="-r \"${IP}:${kcptunport}\" -l \":8388\""
	[ -n "$kcptunpwd" ] && kcptun_client_args="${kcptun_client_args} --key \"${kcptunpwd}\""
	[ -n "$crypt_methods" ] && kcptun_client_args="${kcptun_client_args} --crypt ${crypt_methods}"
	[ -n "$comm_mode" ] && kcptun_client_args="${kcptun_client_args} --mode ${comm_mode}"
	[ -n "$nocomp" ] && kcptun_client_args="${kcptun_client_args} --nocomp"
	[ -n "$datashard_value" ] && kcptun_client_args="${kcptun_client_args} --datashard ${datashard_value}"
	[ -n "$parityshard_value" ] && kcptun_client_args="${kcptun_client_args} --parityshard ${parityshard_value}"
	[ -n "$dscp_value" ] && kcptun_client_args="${kcptun_client_args} --dscp ${dscp_value}"

	echo -e "������IP: \033[41;37m ${IP} \033[0m"
	echo -e "�˿�: \033[41;37m ${kcptunport} \033[0m"
	echo -e "���ٵ�ַ: ${forwardip}:${forwardport}"
	[ -n "$kcptunpwd" ] && echo -e "����: \033[41;37m ${kcptunpwd} \033[0m"
	[ -n "$crypt_methods" ] && echo -e "���ܷ�ʽ Crypt: \033[41;37m ${crypt_methods} \033[0m"
	[ -n "$comm_mode" ] && echo -e "����ģʽ Mode: \033[41;37m ${comm_mode} \033[0m"
	[ -n "$mtu_value" ] && echo -e "MTU: \033[41;37m ${mtu_value} \033[0m"
	[ -n "$sndwnd_value" ] && echo -e "���ʹ��ڴ�С Sndwnd: \033[41;37m ${sndwnd_value} \033[0m"
	[ -n "$rcvwnd_value" ] && echo -e "���ܴ��ڴ�С Rcvwnd: \033[41;37m ${rcvwnd_value} \033[0m"
	[ -n "$nocomp" ] && echo -e "����ѹ��: \033[41;37m �ѽ��� \033[0m"
	[ -n "$datashard_value" ] && echo -e "ǰ����� Datashard: \033[41;37m ${datashard_value} \033[0m"
	[ -n "$parityshard_value" ] && echo -e "ǰ����� Parityshard: \033[41;37m ${parityshard_value} \033[0m"
	[ -n "$dscp_value" ] && echo -e "��ַ������� DSCP: \033[41;37m ${dscp_value} \033[0m"
	echo
	echo "�Ƽ��Ŀͻ��˲���Ϊ: "
	echo -e "\033[41;37m ${kcptun_client_args} \033[0m"
	echo
	echo "�������������м��������, ��ϸ��Ϣ���Բ鿴: https://github.com/xtaci/kcptun"
	echo
	echo -e "Kcptun Ŀ¼: \033[41;37m /usr/share/kcptun \033[0m"
	echo -e "Kcptun ��־�ļ�: \033[41;37m /var/log/kcptun.log \033[0m"
	echo
	echo "Supervisor �����������: service supervisord {start|stop|restart|status}"
	echo "kcptun Server �����������: supervisorctl {start|stop|restart|status} kcptun"
	echo "�ѽ� Supervisor ���뿪������, Kcptun Server ���� Supervisor ������������"
	echo
	echo -e "�����������÷����, ��ʹ��: \033[41;37m ${0} reconfig \033[0m"
	echo -e "���·����, ��ʹ��: \033[41;37m ${0} update \033[0m"
	echo -e "ж�ط����, ��ʹ��: \033[41;37m ${0} uninstall \033[0m"
	echo
	echo "��ӭ����������: https://blog.kuoruan.com/"
	echo
	echo "���ǵ�QQȺ: 43391448"
	echo
	echo "����ʹ�ðɣ�"
	echo
}

# Install Kcptun
function install_kcptun(){
	checkos
	rootness
	disable_selinux
	check_install
	set_config
	pre_install
	get_json_content
	get_machine_type
	download_file
	config_kcptun
	# make dir
	mkdir -p /usr/share/kcptun/
	tar -zxf kcptun-"$SPRUCE_TYPE".tar.gz -C /usr/share/kcptun/

	server_file=/usr/share/kcptun/server_"$FILE_SUFFIX"
	if [ -f "$server_file" ]; then
		chmod a+x "$server_file"
		downlod_init_script && init_service

		clear
		echo
		echo "��ϲ, Kcptun Server ��װ�ɹ���"
		show_config_info
	else
		exit_shell
	fi
	cleanup
}

function check_update(){
	rootness
	echo "��ʼ������..."
	get_json_content
	get_machine_type
	local shell_path=$0
	local new_shell_version=`echo "$VERSION_CONTENT" | jq -r ".shell_version" | grep -oE "[0-9]+"`
	[ -z "$new_shell_version" ] && new_shell_version=0
	if [ "$new_shell_version" -gt "$SHELL_VERSION" ]; then
		local change_log=`echo "$VERSION_CONTENT" | jq -r ".change_log"`
		echo "���ְ�װ�ű����� (�汾��: ${new_shell_version})"
		echo -e "����˵��: \n${change_log}"
		echo
		echo "���������ʼ����, ���� Ctrl+C ȡ��"
		click_to_continue
		echo "���ڸ��°�װ�ű�..."
		local new_shell_url=`echo "$VERSION_CONTENT" | jq -r ".shell_url"`
		mv -f $shell_path "$shell_path".bak

		if ! wget --no-check-certificate -O "$shell_path" "$new_shell_url"; then
			mv -f "$shell_path".bak $shell_path
			echo "���°�װ�ű�ʧ��..."
		else
			chmod a+x "$shell_path"
			sed -ri "s/CONFIG_VERSION=[0-9]+/CONFIG_VERSION=${CONFIG_VERSION}/" "$shell_path"
			sed -ri "s/INIT_VERSION=[0-9]+/INIT_VERSION=${INIT_VERSION}/" "$shell_path"
			rm -f "$shell_path".bak
			clear
			echo
			echo "��װ�ű��Ѹ��µ� v${new_init_version}, ���������µĽű�..."
			echo

			$shell_path update
			exit 0
		fi
	else
		echo "δ���ְ�װ�ű�����..."
	fi

	local kcptun_server=/usr/share/kcptun/server_"$FILE_SUFFIX"
	if [ -f $kcptun_server ]; then
		chmod a+x "$kcptun_server"
		local local_kcptun_version=`$kcptun_server --version | grep -oE "[0-9]+"`
		local remote_kcptun_version=`echo "$KCPTUN_CONTENT" | jq -r ".tag_name" | grep -oE "[0-9]+"`
		[ -z "$remote_kcptun_version" ] && remote_kcptun_version=0
		if [ "$remote_kcptun_version" -gt "$local_kcptun_version" ]; then
			local kcptun_version_desc=`echo "$KCPTUN_CONTENT" | jq -r ".name"`
			echo "���� Kcptun �°汾 (v${remote_kcptun_version})"
			echo -e "����˵��: \n${kcptun_version_desc}"
			echo
			echo "���������ʼ����, ���� Ctrl+C ȡ��"
			click_to_continue
			echo "�����Զ����� Kcptun..."
			download_file
			tar -zxf kcptun-"$SPRUCE_TYPE".tar.gz -C /usr/share/kcptun
			if [ -f $kcptun_server ]; then
				chmod a+x "$kcptun_server"
				supervisorctl restart kcptun
				cleanup
				echo
				echo "Kcptun Server �Ѹ��µ� v${remote_kcptun_version}, ���ֶ����¿ͻ��ˣ�"
				echo
			fi
		else
			echo "δ���� Kcptun ����..."
		fi
	else
		echo "δ�ҵ��Ѱ�װ�� Kcptun Server ִ���ļ�, �����㲢û�а�װ Kcptun?"
	fi

	local new_config_version=`echo "$VERSION_CONTENT" | jq -r ".config_version" | grep -oE "[0-9]+"`
	[ -z "$new_config_version" ] && new_config_version=0
	if [ "$new_config_version" -gt "$CONFIG_VERSION" ]; then
		local config_change_log=`echo "$VERSION_CONTENT" | jq -r ".config_change_log"`
		echo "���� Kcptun ���ø��� (�汾��: ${new_config_version}), ��Ҫ�������� Kcptun..."
		echo -e "����˵��: \n${config_change_log}"
		echo
		echo "���������ʼ����, ���� Ctrl+C ȡ��"
		click_to_continue
		reconfig_kcptun
		sed -i "s/CONFIG_VERSION=${CONFIG_VERSION}/CONFIG_VERSION=${new_config_version}/" "$shell_path"
	else
		echo "δ���� Kcptun ���ø���..."
	fi

	local new_init_version=`echo "$VERSION_CONTENT" | jq -r ".init_version" | grep -oE "[0-9]+"`
	[ -z "$new_init_version" ] && new_init_version=0
	if [ "$new_init_version" -gt "$INIT_VERSION" ]; then
		local init_change_log=`echo "$VERSION_CONTENT" | jq -r ".init_change_log"`
		echo "���ַ��������ű��ļ����� (�汾��: ${new_init_version})"
		echo -e "����˵��: \n${init_change_log}"
		echo
		echo "���������ʼ����, ���� Ctrl+C ȡ��"
		click_to_continue
		echo "�����Զ����������ű�..."
		checkos
		downlod_init_script
		if centosversion 7; then
			systemctl daemon-reload
		fi
		sed -i "s/INIT_VERSION=${INIT_VERSION}/INIT_VERSION=${new_init_version}/" "$shell_path"
		echo
		echo "���������ű��Ѹ��µ� v${new_init_version}, ������Ҫ����������������Ч��"
		echo
	else
		echo "δ���ַ��������ű�����..."
	fi
}

function uninstall_kcptun(){
	rootness
	echo "�Ƿ�ж�� Kcptun Server? �����������...���� Ctrl+C ȡ��"
	click_to_continue
	echo
	echo "����ж�� Kcptun ��ȡ�� Supervisor �Ŀ�������..."
	supervisorctl stop kcptun
	service supervisord stop
	checkos
	if [ "$OS" == 'CentOS' ]; then
		chkconfig supervisord off
	else
		update-rc.d -f supervisord remove
	fi

	rm -f /etc/supervisor/conf.d/kcptun.conf
	rm -rf /usr/share/kcptun/
	echo "Kcptun Server ж����ɣ���ӭ�ٴ�ʹ�á�"
}

function reconfig_kcptun(){
	rootness
	echo "��ʼ�������� Kcptun Server..."
	set_config
	get_machine_type
	echo "����д���µ�����..."
	config_kcptun

	if [ -f /etc/init.d/supervisord ]; then
		service supervisord restart
		sleep 5
		supervisorctl reload
		supervisorctl restart kcptun
		if [ $? -ne 0 ]; then
			echo "�Զ����� Kcptun ʧ��, ���ֶ���飡"
		fi
	else
		echo "δ�ҵ� Supervisor ����, �޷����� Kcptun Server, ���ֶ���飡"
	fi
	echo "��ϲ, Kcptun Server ������ϣ�"
	show_config_info
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
	install)
		install_kcptun
		;;
	uninstall)
		uninstall_kcptun
		;;
	update)
		check_update
		;;
	reconfig)
		reconfig_kcptun
		;;
	*)
		echo "�������� [${action}]"
		echo "��ʹ��: $0 {install|uninstall|update|reconfig}"
		;;
esac