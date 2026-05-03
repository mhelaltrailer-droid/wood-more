#!/bin/sh
set -e
# Render sets PORT; docker-compose app service maps 8080:80 and leaves PORT unset → 80
LISTEN_PORT="${PORT:-80}"

if getent hosts api >/dev/null 2>&1; then
  cp /etc/nginx/nginx.compose.conf /etc/nginx/conf.d/default.conf
else
  cp /etc/nginx/nginx.standalone.conf /etc/nginx/conf.d/default.conf
fi

sed -i "s/listen 80;/listen ${LISTEN_PORT};/" /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"
