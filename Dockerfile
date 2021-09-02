FROM debian:buster-slim

ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive
ENV PATH="${PATH}:/xbin"
ENV TZ Europe/London

RUN ln -sf /bin/bash /bin/sh

# Supervisor implementation ###############################################################

ENV container docker

RUN apt-get update \
    && apt-get install -y tzdata cron logrotate supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Careful! Docker remove Lines with leading '#', even if they are inside an echo statement!	
RUN mkdir /etc/pre.systemd.d && echo -e "#!/bin/bash\n\
\n\
[[ -n $TZ ]] && echo \"[\$(date +'%Y-%m-%d %H:%I:%S')] Setting timezone...\" && ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone\n\
\n\
if [ -d /etc/pre.systemd.d ]; then\n\
    for i in /etc/pre.systemd.d/*.sh ; do\n\
        if [ -r \"\$i\" ]; then\n\
                /bin/bash \"\$i\" \n\
        fi\n\
    done\n\
fi\n\
\n\
echo \"[\$(date +'%Y-%m-%d %H:%I:%S')] Starting Supervisord...\"\n\
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n\
" > /sbin/init.sh && chmod 700 /sbin/init.sh

CMD ["/sbin/init.sh"]

# Autostart disabled for now. Will be enabled later!
COPY files/sv-cron.conf /etc/supervisor/conf.d/cron.conf
COPY files/sv-mariadb.conf /etc/supervisor/conf.d/mariadb.conf
COPY files/sv-gammu.conf /etc/supervisor/conf.d/gammu.conf
COPY files/sv-apache2.conf /etc/supervisor/conf.d/apache2.conf

#####################################################################################
### docker run --tmpfs /run --tmpfs /run/lock                                     ###
#####################################################################################

########################################################################################

RUN apt-get update && \
	apt-get install -y locales && \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/*
	
ENV LANG en_US.utf8
	
RUN apt-get update && \
	apt-get dist-upgrade -y && \
	apt-get install -y mariadb-server mariadb-client apache2 busybox gammu gammu-smsd curl wget git rsync bash-completion && \
	mkdir /xbin && /bin/busybox --install -s /xbin && \
	mkdir /var/run/gammu-deb && chmod 777 /var/run/gammu-deb && cd /var/run/gammu-deb && \
	apt-get download -y gammu-smsd && dpkg -x *.deb . && \
	cp -a usr/share/doc/gammu-smsd/examples/mysql*.sql.gz /usr/share/doc/gammu-smsd/examples/ && \
	rm -rf /var/run/gammu-deb && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/
	
RUN apt-get update && \
	apt-get install -y wget apt-transport-https lsb-release ca-certificates && \
	wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
	echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
	apt-get update && apt-get install -y php5.6 php5.6-mysql php5.6-mbstring php5.6-curl php5.6-json php5.6-readline php5.6-soap php5.6-xml php5.6-xmlrpc php5.6-ldap && \
	apt-get clean && apt-get autoclean && \
	rm -rf /var/lib/apt/lists/*

# Setup MySQL Database, gammu-smsd and Kalkun-WebGUI
#=====================
ADD patches /var/run/patches
RUN cd /var/run/ && \
	git clone -b php5 https://github.com/back2arie/Kalkun.git && \
	rm -rf /var/www/html/* && mv Kalkun/* /var/www/html/ && chown -R www-data:www-data /var/www/html && \
	find /var/www/html/ -type f -exec dos2unix {} \; && \
	cd /var/www/html && for i in $(find /var/run/patches/ -maxdepth 1 -type f -name "*-kalkun-*.patch" | sort -n); do patch -p0 < $i || exit 1; done && \
	/bin/cp /var/run/patches/style/*.jpg /var/www/html/media/images/ && \
	/bin/cp /var/run/patches/style/*.png /var/www/html/media/images/ && \
	patch -p0 < /var/run/patches/style/style.patch && \
	chown -R www-data:www-data /var/www/html && \
	mkdir /var/log/gammu-smsd && \
	cd /etc/ && for i in $(find /var/run/patches/ -maxdepth 1 -type f -name "*-gammu-*.patch" | sort -n); do patch -p0 < $i || exit 1; done && \
	echo -e "/var/log/gammu-smsd/gammu.log {\n  rotate 5\n  size 10M\n  compress\n  missingok\n  notifempty\n}" > /etc/logrotate.d/gammu-smsd && \
	rm -rf /var/run/Kalkun && rm -rf /var/run/patches && \
	/usr/bin/supervisord -c /etc/supervisor/supervisord.conf && \
	supervisorctl start mariadb && sleep 5 && \
	mysql -e 'CREATE DATABASE kalkun;' && \
	bash -c 'zcat /usr/share/doc/gammu-smsd/examples/mysql.sql.gz | mysql kalkun' && \
	mysql kalkun < /var/www/html/media/db/mysql_kalkun.sql && \
	mysql -e "GRANT USAGE on *.* to 'gammu'@'localhost' IDENTIFIED BY 'MAlST101qfMy6FGYKj5d';" && \
	mysql -e "GRANT ALL PRIVILEGES on kalkun.* to 'gammu'@'localhost';" && \
	sleep 5 && supervisorctl stop mariadb && killall supervisord || true
	
RUN mkdir /opt/{configs,logs,data} && \
	mv /etc/apache2 /etc/apache2.dist && \
		mkdir /etc/apache2.dist/ssl && \
			sed -i 's#/etc/ssl/certs/ssl-cert-snakeoil#/etc/apache2/ssl/selfsigned#g' /etc/apache2.dist/sites-available/default-ssl.conf && \
			sed -i 's#/etc/ssl/private/ssl-cert-snakeoil#/etc/apache2/ssl/selfsigned#g' /etc/apache2.dist/sites-available/default-ssl.conf && \
			ln -sf ../sites-available/default-ssl.conf /etc/apache2.dist/sites-enabled/ && \
			ln -sf ../mods-available/ssl.{conf,load} /etc/apache2.dist/mods-enabled/ && \
			ln -sf ../mods-available/socache_shmcb.load /etc/apache2.dist/mods-enabled/ && \
		ln -s /opt/configs/apache2 /etc/apache2 && \
	mv /etc/mysql /etc/mysql.dist && \
		ln -s /opt/configs/mysql /etc/mysql && \
	mv /etc/gammu-smsdrc /etc/gammu-smsdrc.dist && \
		ln -s /opt/configs/gammu-smsdrc /etc/gammu-smsdrc && \
		ln -s /opt/configs/gammu-smsdrc /etc/gammurc && \
	mv /var/www/html /var/www_html.dist && \
		ln -s /opt/website /var/www/html && \
	mv /var/log/apache2 /var/log/apache2.dist && \
		ln -s /opt/logs/apache2 /var/log/apache2 && \
	mv /var/log/mysql /var/log/mysql.dist && \
		ln -s /opt/logs/mysql /var/log/mysql && \
	mv /var/log/gammu-smsd /var/log/gammu-smsd.dist && \
		ln -s /opt/logs/gammu-smsd /var/log/gammu-smsd && \
	mv /var/lib/mysql /var/lib/mysql.dist && \
		ln -s /opt/data/mysql /var/lib/mysql
	

COPY files/selfsign.cnf /etc/ssl/
COPY files/selfsign.sh /etc/ssl/
COPY files/00-docker-init.sh /etc/pre.systemd.d/

RUN find /etc/supervisor/conf.d/{cron,mariadb,gammu,apache2}.conf | \
	xargs -n1 sed -i 's/autostart=false/autostart=true/g'
	
VOLUME [ "/opt/configs" ]
VOLUME [ "/opt/website" ]
VOLUME [ "/opt/data" ]
VOLUME [ "/opt/logs" ]

EXPOSE 80
EXPOSE 443
