#!/bin/bash
build_bzImage=0

#0:解析参数
for i in "$@"
do
	case $i in
	-p=*|--bzimage=*)
		build_bzImage="${i#*=}"
		;;
	-s=*|--search=*)
		SEARCH="${i#*=}"
		;;
	*)
		;;
	esac
done
		

#1:环境
apt-get install -y build-essential debootstrap flex bison libelf-dev openssl libncurses-dev libssl-dev

#2:编译内核
chmod -R 777 /opt
if [ ! -d "/opt/linux-5.13.8" ]; then
	cd /opt
	wget -c https://mirrors.aliyun.com/linux-kernel/v5.x/linux-5.13.8.tar.gz
	tar -zxvf linux-5.13.8.tar.gz
	build_bzImage=1
fi
if (( $build_bzImage > 0 )); then
	echo "需要重新编译啦.. build_bzimage >0"
	#cd /opt/linux-5.13.8
	#make clean
	#make defconfig
	#make bzImage
fi

#3:rootfs
if [ ! -d "/opt/rootfs" ]; then
	cd /opt && mkdir rootfs
	debootstrap --variant=minbase --arch=amd64 stretch rootfs http://cdn.debian.net/debian
	cat>/opt/rootfs/init<<EOF
		#!/bin/bash
		dmesg -n 1
		mount -t devtmpfs none /dev
		mount -t proc none /proc
		mount -t sysfs none /sys
		setsid /bin/bash
EOF
	chmod a+x /opt/rootfs/init
	#TODO...
	chmod -R 777 /opt/rootfs && cd /opt/rootfs
	find . | cpio -R root:root -H newc -o | gzip > ../rootfs.gz 
fi





#4:
function config_system(){
	echo "配置系统.."
	export LC_ALL=C LANGUAGE=C LANG=C
	chroot /opt/rootfs
	#source源
	echo "source源..."
	cat >/etc/apt/sources.list <<EOF
	deb http://mirrors.aliyun.com/debian/ stretch main non-free contrib
	deb-src http://mirrors.aliyun.com/debian/ stretch main non-free contrib
	deb http://mirrors.aliyun.com/debian-security stretch/updates main
	deb-src http://mirrors.aliyun.com/debian-security stretch/updates main
	deb http://mirrors.aliyun.com/debian/ stretch-updates main non-free contrib
	deb-src http://mirrors.aliyun.com/debian/ stretch-updates main non-free contrib
EOF
	#hostname
	echo "Debian" >/etc/hostname
	echo "Debian" >/proc/sys/kernel/hostname
	
	#安装软件
	#TODO..
	
	#配置网络
	mkdir -p /etc/network
	cat >/etc/network/interfaces <<EOF
	auto lo
	iface lo inet loopback

	auto eth0
	iface eth0 inet dhcp
EOF
	cat >/etc/resolv.conf <<EOF
	nameserver 114.114.114.114
	nameserver 8.8.8.8
EOF
	#配置分区
	cat >/etc/fstab <<EOF
	LABEL=rootfs	/	ext4	user_xattr,errors=remount-ro	0	1
EOF
	#配置root密码
	echo "root:123456" | chpasswd
	
	#清理缓存
	apt-get clean && rm -rf /var/cache/apt/
}

#config_system
