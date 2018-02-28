#!/bin/bash
set -e

# 0) Make sure the right parameters are here

if [[ -z "${NGINX_EMAIL}" ]]; then
  echo 'NGINX_EMAIL is not specified. Aborting.'
  exit 1
fi

if [[ -z "${NGINX_SERVER_NAME_LEDGER1}" ]]; then
  echo 'NGINX_SERVER_NAME_LEDGER1 is not specified. Aborting.'
  exit 1
fi

if [[ -z "${NGINX_SERVER_NAME_LEDGER2}" ]]; then
  echo 'NGINX_SERVER_NAME_LEDGER2 is not specified. Aborting.'
  exit 1
fi


# 0.5) Start nginx for the first time
# TODO: maybe just do this if letsencrypt hasn't been initalized?
echo 'Starting initial nginx config.'
# nginx
service nginx start

# 1) Check whether letsencrypt has already been initialized
echo "Testing whether letsencrypt has been initialized already."
if [[ ! -d "/etc/letsencrypt/live/${NGINX_SERVER_NAME_LEDGER1}" ]]; then

  # 2) Initialize letsencrypt, if required
  echo "Initializing letsencrypt with certbot for '${NGINX_SERVER_NAME_LEDGER1}'."
  # include --dry-run durign development
  letsencrypt certonly \
    -a webroot \
    -m ${NGINX_EMAIL} \
    -d ${NGINX_SERVER_NAME_LEDGER1} \
    --agree-tos \
    --webroot-path=/usr/share/nginx/html/

else
  echo "Letsencrypt has been initialized; skipping certbot setup."
fi

# 2.5) Generate DH Params if needed
echo "Testing whether DHParams exist."
mkdir -p '/opt/certs'
if [[ ! -f "/opt/certs/dhparam.pem" ]]; then

  # 2.75) Initialize DHParams if needed
  echo "Generating DHParams."
  openssl dhparam \
    -out /opt/certs/dhparam.pem \
    2048

else
  echo "DHParams exist; skipping DHParam setup."
fi

# 3) Install SSL-enabled config and restart nginx
echo "Applying SSL enabled nginx config"
cat /opt/site.conf | \
  sed -e "s/\\\$SERVER_NAME/${NGINX_SERVER_NAME_LEDGER1}/" | \
  sed -e "s/\\\$REVERSE_HOST/${NGINX_SERVER_NAME_LEDGER1%%.*}/" \
  > /etc/nginx/conf.d/${NGINX_SERVER_NAME_LEDGER1}.conf

# 1) Check whether letsencrypt has already been initialized
echo "Testing whether letsencrypt has been initialized already."
if [[ ! -d "/etc/letsencrypt/live/${NGINX_SERVER_NAME_LEDGER2}" ]]; then

  # 2) Initialize letsencrypt, if required
  echo "Initializing letsencrypt with certbot for '${NGINX_SERVER_NAME_LEDGER2}'."
  # include --dry-run durign development
  letsencrypt certonly \
    -a webroot \
    -m ${NGINX_EMAIL} \
    -d ${NGINX_SERVER_NAME_LEDGER2} \
    --agree-tos \
    --webroot-path=/usr/share/nginx/html/

else
  echo "Letsencrypt has been initialized; skipping certbot setup."
fi

# 2.5) Generate DH Params if needed
echo "Testing whether DHParams exist."
mkdir -p '/opt/certs'
if [[ ! -f "/opt/certs/dhparam.pem" ]]; then

  # 2.75) Initialize DHParams if needed
  echo "Generating DHParams."
  openssl dhparam \
    -out /opt/certs/dhparam.pem \
    2048

else
  echo "DHParams exist; skipping DHParam setup."
fi

# 3) Install SSL-enabled config and restart nginx
echo "Applying SSL enabled nginx config"
mkdir -p /etc/nginx/sites-{available,enabled}
cat /opt/site.conf | \
  sed -e "s/\\\$SERVER_NAME/${NGINX_SERVER_NAME_LEDGER2}/" | \
  sed -e "s/\\\$REVERSE_HOST/${NGINX_SERVER_NAME_LEDGER2%%.*}/" \
  > /etc/nginx/conf.d/${NGINX_SERVER_NAME_LEDGER2}.conf

#echo "Stopping nginx"
#nginx -s stop
service nginx stop

echo "Restarting nginx"
exec nginx -g 'daemon off;'
