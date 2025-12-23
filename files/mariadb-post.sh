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

REAL_VERSION=$(php -r "CONST BASEPATH='/var/www'; include(BASEPATH . '/application/config/kalkun_settings.php'); echo \$config['kalkun_version'];")

CURRENT_DB_VER=$(mysql -N -s kalkun <<< "SELECT version FROM kalkun LIMIT 1;")
CURRENT_DB_VER=${CURRENT_DB_VER:-"0.0.0"}

logPrint "Applying DB Schema Updates"
for i in $(find /var/www/application/sql/mysql/ -type f -name "upgrade_kalkun_*.sql"| sort -V); do
	FILE_VER=$(basename "$i" | sed 's/upgrade_kalkun_//;s/\.sql//'| sed 's/[^0-9.]//g')
	IS_NEWER=$(php -r "echo (version_compare('$FILE_VER', '$CURRENT_DB_VER', '>') ? 1 : 0);")
	if [ "$IS_NEWER" == "1" ]; then
		logPrint "Applying $(basename $i)"
		mysql kalkun < $i
	else
		logPrint "Skipping $(basename $i) ... Current version ($CURRENT_DB_VER) is newer or equal"
	fi
done

if [[ $CURRENT_DB_VER != $REAL_VERSION ]]; then
	logPrint "Updating newest version ($REAL_VERSION) string in kalkun database"
	if [ $(mysql -N -s -e "SELECT COUNT(*) FROM kalkun;" kalkun) -eq 0 ]; then
		mysql -e "INSERT INTO kalkun (version) VALUES ('$REAL_VERSION');" kalkun
	else
		mysql -e "UPDATE kalkun SET version = '$REAL_VERSION';" kalkun
	fi
fi