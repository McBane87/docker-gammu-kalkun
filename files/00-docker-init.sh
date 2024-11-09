#!/bin/bash

function createDir {

	local ref=$1
	local dest=$2

	if [[ $ref == "" || $dest == "" ]]; then
		return
	fi

	if [[ ! -d $dest ]]; then
		logPrint "Directory \"$dest\" does not exist. Creating..."
		mkdir $dest && \
		chmod --reference=$ref $dest && \
		chown --reference=$ref $dest
	fi

}

function isEmptyTarget() {
	local target=$1
	if [ -z "$(ls -A $target 2>/dev/null)" ]; then
		return 0
	else
		return 1
	fi
}

function copyIfEmptyDir {

	local ref=$1
	local dest=$2
	local allowSymlinks=$3

	if [[ $ref == "" || $dest == "" ]]; then
		return
	fi

	createDir $ref $dest

	if isEmptyTarget $dest; then
		logPrint "Empty directory \"$dest\". Copy dist files..."
		if [[ $allowSymlinks != "0" && $allowSymlinks != "" ]]; then
			#allow
			rsync -a $ref/ $dest/
		else
			#disallow
			rsync -rLptgoD  $ref/ $dest/
		fi
	fi
}

function logPrint() {
	echo "[$(date +'%Y-%m-%d %H:%I:%S')] $1"
}

copyIfEmptyDir /etc/apache2.dist /opt/configs/apache2 1
copyIfEmptyDir /etc/mysql.dist /opt/configs/mysql 0
copyIfEmptyDir /var/log/apache2.dist /opt/logs/apache2 0
copyIfEmptyDir /var/log/mysql.dist /opt/logs/mysql 0
copyIfEmptyDir /var/log/gammu-smsd.dist /opt/logs/gammu-smsd 0
copyIfEmptyDir /var/lib/mysql.dist /opt/data/mysql 0

if [[ ! -f /opt/configs/gammu-smsdrc ]]; then
	logPrint "Empty file \"/opt/configs/gammu-smsdrc\". Copy dist files..."
	rsync -rLptgoD /etc/gammu-smsdrc.dist /opt/configs/gammu-smsdrc
fi

if [[ -z "$(ls -A /opt/configs/apache2/ssl 2>/dev/null)" ]]; then
	logPrint "Empty directory \"/opt/configs/apache2/ssl\". Creating selfsign certs..."
	/etc/ssl/selfsign.sh /etc/ssl/selfsign.cnf /opt/configs/apache2/ssl >/dev/null
fi

if [[ ! -d /opt/configs/kalkun ]]; then
	mkdir /opt/configs/kalkun
fi

# Copy distributed config in order to show newest config syntax to users
cp -a /etc/kalkun/config.php.dist /opt/configs/kalkun/config.php.dist
cp -a /etc/kalkun/database.php.dist /opt/configs/kalkun/database.php.dist

[[ ! -f /opt/configs/kalkun/config.php ]] && cp -a /etc/kalkun/config.php.dist /opt/configs/kalkun/config.php
[[ ! -f /opt/configs/kalkun/database.php ]] && cp -a /etc/kalkun/database.php.dist /opt/configs/kalkun/database.php

chown -Rh  mysql:mysql /opt/logs/mysql
chown -Rh  gammu:gammu /opt/logs/gammu-smsd
chown -Rh  mysql:mysql /opt/data/mysql
install -m 755 -o gammu -g gammu -d /var/run/gammu

exit 0