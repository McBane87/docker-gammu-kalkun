#!/bin/bash
function logPrint() {
	echo "[$(date +'%Y-%m-%d %H:%I:%S')] $1"
}

# Wait for mariadb to be up and running
i=0
while [[ ! -S /run/mysqld/mysqld.sock && $i -lt 10 ]]; do
    i=$(($i+1))
    sleep 1
done

logPrint "Applying DB Schema Updates"
for i in $(find /var/www/application/sql/mysql/ -type f -name "upgrade_kalkun_*.sql"); do
	logPrint "Applying $(basename $i)"
	mysql kalkun < $i
done