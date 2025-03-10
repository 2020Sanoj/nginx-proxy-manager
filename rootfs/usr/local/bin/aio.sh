#!/usr/bin/env sh

if [ "$NC_AIO" = "true" ] && [ ! -f /data/aio.lock ]; then
    while [ "$(healthcheck.sh)" != "OK" ]; do sleep 10s; done
    if ! curl -POST http://127.0.0.1:"$NIBEP"/nginx/certificates -sSH 'Content-Type: application/json' -d '{"domain_names":["'"$NC_DOMAIN"'"],"meta":{"letsencrypt_agree":true,"dns_challenge":false},"provider":"letsencrypt"}' -H "Authorization: Bearer $(curl -POST http://127.0.0.1:"$NIBEP"/tokens -sSH 'Content-Type: application/json' -d '{"identity":"'"$INITIAL_ADMIN_EMAIL"'","secret":"'"$INITIAL_ADMIN_PASSWORD"'"}' | jq -r .token)" | jq; then
        # shellcheck disable=SC2016
        curl -POST http://127.0.0.1:"$NIBEP"/nginx/proxy-hosts -sSH 'Content-Type: application/json' -d '{"domain_names":["'"$NC_DOMAIN"'"],"forward_scheme":"http","forward_host":"127.0.0.1","forward_port":11000,"allow_websocket_upgrade":true,"access_list_id":"0","certificate_id":"'"$(curl http://127.0.0.1:"$NIBEP"/nginx/certificates -sSH "Authorization: Bearer $(curl -POST http://127.0.0.1:"$NIBEP"/tokens -sSH 'Content-Type: application/json' -d '{"identity":"'"$INITIAL_ADMIN_EMAIL"'","secret":"'"$INITIAL_ADMIN_PASSWORD"'"}' | jq -r .token)" jq '.[] | select(.domain_names[] == "'"$NC_DOMAIN"'") | .id' )"'","ssl_forced":true,"http2_support":true,"hsts_enabled":true,"hsts_subdomains":true,"meta":{"letsencrypt_agree":false,"dns_challenge":false},"advanced_config":"","locations":[{"path":"/","advanced_config":"proxy_set_header Accept-Encoding $http_accept_encoding;","forward_scheme":"http","forward_host":"127.0.0.1","forward_port":11000}],"block_exploits":false,"caching_enabled":false}' -H "Authorization: Bearer $(curl -POST http://127.0.0.1:"$NIBEP"/tokens -sSH 'Content-Type: application/json' -d '{"identity":"'"$INITIAL_ADMIN_EMAIL"'","secret":"'"$INITIAL_ADMIN_PASSWORD"'"}' | jq -r .token)" | jq
        touch /data/aio.lock
        echo "The default config for AIO should now be created."
    else
        echo "There was an error creating the TLS certificate for AIO. If you want to retry please set your current admin credentials in the .env file using INITIAL_ADMIN_EMAIL and INITIAL_ADMIN_PASSWORD, if not create an empty file called aio.lock."
    fi
fi
