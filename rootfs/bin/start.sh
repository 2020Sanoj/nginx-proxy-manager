#!/bin/bash

# From https://github.com/nextcloud/all-in-one/pull/1377/files
if [ -n "$PHP_APKS" ]; then
    if ! echo "$PHP_APKS" | grep -q "^[a-z0-9 _-]\+$"; then
        echo "You've set PHP_APKS but not to an allowed value.
              It needs to be a string. Allowed are small letters a-z, digits 0-9, spaces, hyphens and underscores.
              It is set to '$PHP_APKS'." || exit 1
        sleep inf || exit 1
    fi
    
    
    read -ra APKS_ARRAY <<< "$PHP_APKS"
    for apk in "${APKS_ARRAY[@]}"; do
    
        if ! echo "$apk" | grep -q "php*"; then
            echo "'$apk' is a non allowed value.
                  It needs to start with php.
                  It is set to '$apk'." || exit 1
            sleep inf || exit 1
        fi
    
        echo "Installing $apk via apk..."
        if ! apk add --no-cache "$apk" >/dev/null; then
            echo "The packet $apk was not installed!"
        fi

    done
fi

mkdir -p /tmp/acme-challenge \
         /data/ssl/certbot \
         /data/ssl/custom \
         /data/php \
         /data/nginx/redirection_host \
         /data/nginx/proxy_host \
         /data/nginx/dead_host \
         /data/nginx/stream \
         /data/nginx/custom \
         /data/nginx/access \
         /data/nginx/html || exit 1

if [ -f /data/nginx/default_host/site.conf ]; then
mv /data/nginx/default_host/site.conf /data/nginx/default.conf || exit 1
fi

if [ -f /data/nginx/default_www/index.html ]; then
mv /data/nginx/default_www/index.html /data/nginx/html/index.html || exit 1
fi

if [ -e /data/access ]; then
mv /data/access/* /data/nginx/access || exit 1
fi

if [ -e /etc/letsencrypt/live ]; then
mv /etc/letsencrypt/* /data/ssl/certbot || exit 1
fi

if [ -e /data/letsencrypt/live ]; then
mv /data/letsencrypt/* /data/ssl/certbot || exit 1
fi

if [ -e /data/custom_ssl/npm-* ]; then
mv /data/custom_ssl/* /data/ssl/custom || exit 1
fi

rm -rf /data/letsencrypt-acme-challenge \
       /data/nginx/default_host \
       /data/nginx/default_www \
       /data/nginx/streams \
       /data/nginx/temp \
       /data/index.html \
       /data/letsencrypt \
       /data/custom_ssl \
       /data/certbot \
       /data/access \
       /data/logs \
       /data/error.log \
       /data/nginx/error.log || exit 1

find /data/nginx -type f -name '*.conf' -exec sed -i "s|/data/access|/data/nginx/access|g" {} \; || exit 1

find /data/nginx -type f -name '*.conf' -exec sed -i "s|/data/custom_ssl|/data/ssl/custom|g" {} \; || exit 1
find /data/nginx -type f -name '*.conf' -exec sed -i "s|/etc/letsencrypt|/data/ssl/certbot|g" {} \; || exit 1
find /data/nginx -type f -name '*.conf' -exec sed -i "s|/data/letsencrypt|/data/ssl/certbot|g" {} \; || exit 1

find /data/ssl/certbot/renewal -type f -name '*.conf' -exec sed -i "s|/etc/letsencrypt|/data/ssl/certbot|g" {} \; || exit 1
find /data/ssl/certbot/renewal -type f -name '*.conf' -exec sed -i "s|/data/letsencrypt|/data/ssl/certbot|g" {} \; || exit 1

find /data/nginx -type f -name '*.conf' -exec sed -i "s|include conf.d/include/letsencrypt-acme-challenge.conf;|include conf.d/include/acme-challenge.conf;|g" {} \; || exit 1

find /data/nginx -type f -name '*.conf' -exec sed -i "s|include conf.d/include/assets.conf;||g" {} \; || exit 1
find /data/nginx -type f -name '*.conf' -exec sed -i "s/# Asset Caching//g" {} \; || exit 1

find /data/nginx -type f -name '*.conf' -exec sed -i "s/proxy_http_version.*//g" {} \; || exit 1
find /data/nginx -type f -name '*.conf' -exec sed -i "s/access_log.*//g" {} \; || exit 1

if [ ! -f /data/nginx/dummycert.pem ] || [ ! -f /data/nginx/dummykey.pem ]; then
openssl req -new -newkey rsa:4096 -days 365000 -nodes -x509 -subj '/CN=*' -sha256 -keyout /data/nginx/dummykey.pem -out /data/nginx/dummycert.pem || exit 1
fi

if [ ! -f /data/nginx/default.conf ]; then
cp /usr/local/nginx/conf/conf.d/include/default.conf /data/nginx/default.conf || exit 1
fi

if [ ! -f /data/ssl/certbot/config.ini ]; then
cp /etc/ssl/certbot.ini /data/ssl/certbot/config.ini || exit 1
fi

touch /data/nginx/default.conf \
      /data/nginx/html/index.html \
      /data/nginx/custom/root.conf \
      /data/nginx/custom/events.conf \
      /data/nginx/custom/http.conf \
      /data/nginx/custom/http_top.conf \
      /data/nginx/custom/server_dead.conf \
      /data/nginx/custom/server_proxy.conf \
      /data/nginx/custom/server_redirect.conf \
      /data/nginx/custom/stream.conf \
      /data/nginx/custom/server_stream.conf \
      /data/nginx/custom/server_stream_tcp.conf \
      /data/nginx/custom/server_stream_udp.conf \
      /usr/local/nginx/conf/conf.d/include/ip_ranges.conf || exit 1

for folder in $(find /etc -maxdepth 1 -type d -name php*); do cp -Trn $folder /data/php/$(echo $folder| sed "s|/etc/php||g"); done;
for folder in $(find /etc -maxdepth 1 -type d -name php*); do sed -i "s|user =.*|user = root|" /data/php/$(echo $folder| sed "s|/etc/php||g")/php-fpm.d/www.conf; done;
for folder in $(find /etc -maxdepth 1 -type d -name php*); do sed -i "s|group =.*|group = root|" /data/php/$(echo $folder| sed "s|/etc/php||g")/php-fpm.d/www.conf; done;
for folder in $(find /etc -maxdepth 1 -type d -name php*); do sed -i "s|listen =.*|listen = /dev/$(echo $folder| sed "s|/etc/||g").sock|" /data/php/$(echo $folder| sed "s|/etc/php||g")/php-fpm.d/www.conf; done;
for folder in $(find /etc -maxdepth 1 -type d -name php*); do sed -i "s|include=.*|include=/data/php/$(echo $folder| sed "s|/etc/php||g")/php-fpm.d/*.conf|g" /data/php/$(echo $folder| sed "s|/etc/php||g")/php-fpm.conf; done;

if [ "$NPM_LISTEN_LOCALHOST" == "true" ]; then
sed -i "s/listen 81/listen 127.0.0.1:81/g" /usr/local/nginx/conf/conf.d/npm.conf || exit 1
sed -i "s/listen \[::\]:81/listen \[::1\]:81/g" /usr/local/nginx/conf/conf.d/npm.conf || exit 1
fi

if [ "$NGINX_LOG_NOT_FOUND" == "true" ]; then
sed -i "s/log_not_found off;/log_not_found on;/g" /usr/local/nginx/conf/nginx.conf || exit 1
fi

if ! nginx -t 2> /dev/null; then
nginx -T || exit 1
sleep inf || exit 1
fi

if ! cross-env PHP_INI_SCAN_DIR=/data/php/7/conf.d php-fpm7 -c /data/php/7 -y /data/php/7/php-fpm.conf -FORt 2> /dev/null; then
cross-env PHP_INI_SCAN_DIR=/data/php/7/conf.d php-fpm7 -c /data/php/7 -y /data/php/7/php-fpm.conf -FORt || exit 1
sleep inf || exit 1
fi

if ! cross-env PHP_INI_SCAN_DIR=/data/php/8/conf.d php-fpm8 -c /data/php/8 -y /data/php/8/php-fpm.conf -FORt 2> /dev/null; then
cross-env PHP_INI_SCAN_DIR=/data/php/8/conf.d php-fpm8 -c /data/php/8 -y /data/php/8/php-fpm.conf -FORt || exit 1
sleep inf || exit 1
fi

if ! cross-env PHP_INI_SCAN_DIR=/data/php/81/conf.d php-fpm81 -c /data/php/81 -y /data/php/81/php-fpm.conf -FORt 2> /dev/null; then
cross-env PHP_INI_SCAN_DIR=/data/php/81/conf.d php-fpm81 -c /data/php/81 -y /data/php/81/php-fpm.conf -FORt || exit 1
sleep inf || exit 1
fi

if ! cross-env PHP_INI_SCAN_DIR=/data/php/82/conf.d php-fpm82 -c /data/php/82 -y /data/php/82/php-fpm.conf -FORt 2> /dev/null; then
cross-env PHP_INI_SCAN_DIR=/data/php/82/conf.d php-fpm82 -c /data/php/82 -y /data/php/82/php-fpm.conf -FORt || exit 1
sleep inf || exit 1
fi

while (nginx -t 2> /dev/null && cross-env PHP_INI_SCAN_DIR=/data/php/7/conf.d php-fpm7 -c /data/php/7 -y /data/php/7/php-fpm.conf -FORt 2> /dev/null && cross-env PHP_INI_SCAN_DIR=/data/php/8/conf.d php-fpm8 -c /data/php/8 -y /data/php/8/php-fpm.conf -FORt 2> /dev/null && cross-env PHP_INI_SCAN_DIR=/data/php/81/conf.d php-fpm81 -c /data/php/81 -y /data/php/81/php-fpm.conf -FORt 2> /dev/null && cross-env PHP_INI_SCAN_DIR=/data/php/82/conf.d php-fpm82 -c /data/php/82 -y /data/php/82/php-fpm.conf -FORt 2> /dev/null); do
nginx || exit 1 &
cross-env PHP_INI_SCAN_DIR=/data/php/7/conf.d php-fpm7 -c /data/php/7 -y /data/php/7/php-fpm.conf -FOR || exit 1 &
cross-env PHP_INI_SCAN_DIR=/data/php/8/conf.d php-fpm8 -c /data/php/8 -y /data/php/8/php-fpm.conf -FOR || exit 1 &
cross-env PHP_INI_SCAN_DIR=/data/php/81/conf.d php-fpm81 -c /data/php/81 -y /data/php/81/php-fpm.conf -FOR || exit 1 &
cross-env PHP_INI_SCAN_DIR=/data/php/82/conf.d php-fpm82 -c /data/php/82 -y /data/php/82/php-fpm.conf -FOR || exit 1 &
node --abort_on_uncaught_exception --max_old_space_size=250 index.js || exit 1 &
wait
done

if ! nginx -t 2> /dev/null; then
nginx -T || exit 1
sleep inf || exit 1
fi

if ! cross-env PHP_INI_SCAN_DIR=/data/php/7/conf.d php-fpm7 -c /data/php/7 -y /data/php/7/php-fpm.conf -FORt 2> /dev/null; then
cross-env PHP_INI_SCAN_DIR=/data/php/7/conf.d php-fpm7 -c /data/php/7 -y /data/php/7/php-fpm.conf -FORt || exit 1
sleep inf || exit 1
fi

if ! cross-env PHP_INI_SCAN_DIR=/data/php/8/conf.d php-fpm8 -c /data/php/8 -y /data/php/8/php-fpm.conf -FORt 2> /dev/null; then
cross-env PHP_INI_SCAN_DIR=/data/php/8/conf.d php-fpm8 -c /data/php/8 -y /data/php/8/php-fpm.conf -FORt || exit 1
sleep inf || exit 1
fi

if ! cross-env PHP_INI_SCAN_DIR=/data/php/81/conf.d php-fpm81 -c /data/php/81 -y /data/php/81/php-fpm.conf -FORt 2> /dev/null; then
cross-env PHP_INI_SCAN_DIR=/data/php/81/conf.d php-fpm81 -c /data/php/81 -y /data/php/81/php-fpm.conf -FORt || exit 1
sleep inf || exit 1
fi

if ! cross-env PHP_INI_SCAN_DIR=/data/php/82/conf.d php-fpm82 -c /data/php/82 -y /data/php/82/php-fpm.conf -FORt 2> /dev/null; then
cross-env PHP_INI_SCAN_DIR=/data/php/82/conf.d php-fpm82 -c /data/php/82 -y /data/php/82/php-fpm.conf -FORt || exit 1
sleep inf || exit 1
fi
