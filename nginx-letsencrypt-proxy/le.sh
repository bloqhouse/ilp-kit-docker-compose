#!/bin/bash
set -e

# 0) Make sure the right parameters are here

if [[ -z "${NGINX_EMAIL}" ]]; then
  echo 'NGINX_EMAIL is not specified. Aborting.'
  exit 1
fi

SERVER_NAMES=("$NGINX_SERVER_NAME_LEDGER1" "$NGINX_SERVER_NAME_LEDGER2")

for NGINX_SERVER_NAME in ${SERVER_NAMES[@]}; do

  # 0.5) Start nginx for the first time
  # TODO: maybe just do this if letsencrypt hasn't been initalized?
  echo 'Starting initial nginx config.'
  nginx

  # 1) Check whether letsencrypt has already been initialized
  echo "Testing whether letsencrypt has been initialized already."
  if [[ ! -d "/etc/letsencrypt/live/${NGINX_SERVER_NAME}" ]]; then

    # 2) Initialize letsencrypt, if required
    echo "Initializing letsencrypt with certbot for '${NGINX_SERVER_NAME}'."
    # include --dry-run durign development
    letsencrypt certonly \
      -a webroot \
      -m ${NGINX_EMAIL} \
      -d ${NGINX_SERVER_NAME} \
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
    sed -e "s/\\\$SERVER_NAME/${NGINX_SERVER_NAME}/" | \
    sed -e "s/\\\$REVERSE_HOST/${NGINX_SERVER_NAME%%.*}/" \
    > /etc/nginx/sites-available/${NGINX_SERVER_NAME}.conf

  ln -s /etc/nginx/sites-available/${NGINX_SERVER_NAME}.conf /etc/nginx/sites-enabled/${NGINX_SERVER_NAME}.conf
done

echo "Stopping nginx"
nginx -s stop

echo "Restarting nginx"
exec nginx -g 'daemon off;'
