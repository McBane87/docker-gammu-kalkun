#!/bin/bash

CONF=$1
DIR=$2

[[ $DIR == "" || $CONF == "" ]] && exit 1

openssl req -new \
		-newkey rsa:4096 -sha256 -nodes -keyout $DIR/selfsigned.key \
		-days 99365 \
		-x509 -out $DIR/selfsigned.pem \
		-config $CONF
		
cat $DIR/selfsigned.{key,pem} > $DIR/selfsigned.chain && \
	openssl pkcs12 -export -passout pass: \
		-in $DIR/selfsigned.chain \
		-out $DIR/selfsigned.pfx
