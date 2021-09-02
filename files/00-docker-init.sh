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

function copyIfEmptyDir {
	
	local ref=$1
	local dest=$2
	local allowSymlinks=$3
	
	if [[ $ref == "" || $dest == "" ]]; then
		return
	fi
	
	createDir $ref $dest
	
	if [[ -z "$(ls -A $dest 2>/dev/null)" ]]; then
		logPrint "Empty directory \"$dest\". Copy dist files..."
		if [[ $allowSymlinks != "0" && $allowSymlinks != "" ]]; then 
			#allow
			cp -a $ref/* $dest/
		else 
			#disallow
			cp -LR --preserve=all $ref/* $dest/
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
copyIfEmptyDir /var/www_html.dist /opt/website 0
copyIfEmptyDir /var/lib/mysql.dist /opt/data/mysql 0

if [[ ! -f /opt/configs/gammu-smsdrc ]]; then 
	logPrint "Empty file \"/opt/configs/gammu-smsdrc\". Copy dist files..."
	cp -LR --preserve=all /etc/gammu-smsdrc.dist /opt/configs/gammu-smsdrc
fi

if [[ -z "$(ls -A /opt/configs/apache2/ssl 2>/dev/null)" ]]; then
	logPrint "Empty directory \"/opt/configs/apache2/ssl\". Creating selfsign certs..."
	/etc/ssl/selfsign.sh /etc/ssl/selfsign.cnf /opt/configs/apache2/ssl >/dev/null
fi

chown -Rh  mysql:mysql /opt/logs/mysql
chown -Rh  gammu:gammu /opt/logs/gammu-smsd
chown -Rh  mysql:mysql /opt/data/mysql
install -m 755 -o gammu -g gammu -d /var/run/gammu

exit 0