#!/bin/bash

[ -z "${NGINX_CANONICAL_DOMAIN_NAME}" ] && NGINX_CANONICAL_DOMAIN_NAME=${NGINX_DOMAIN_NAME}

if [[ "${NGINX_HTTPS}" != "false" || "${WP_CONFIG_HTTPS}" != "false" ]]; then
    export WP_HOME=https://${NGINX_CANONICAL_DOMAIN_NAME}
    export WP_SITEURL=https://${NGINX_CANONICAL_DOMAIN_NAME}
else
    export WP_HOME=http://${NGINX_CANONICAL_DOMAIN_NAME}
    export WP_SITEURL=http://${NGINX_CANONICAL_DOMAIN_NAME}
fi
# reset canonical domain if it's the same
if [ "${NGINX_CANONICAL_DOMAIN_NAME}" = "${NGINX_DOMAIN_NAME}" ]; then
    export NGINX_CANONICAL_DOMAIN_NAME=""
else
    export NGINX_REDIRECT_TO_CANONICAL_DOMAIN=true
fi

# Prepare basic auth
htpasswd -b -c /etc/nginx/htpasswd "${NGINX_BASIC_AUTH_LOGIN}" "${NGINX_BASIC_AUTH_PASSWORD}"
# configure Nginx
dockerize -template "${TEMPLATES_DIR}/nginx.conf.tmpl"      > "/etc/nginx/nginx.conf"
dockerize -template "${TEMPLATES_DIR}/ssl.conf.tmpl"        > "/etc/nginx/snippets/ssl.conf"
dockerize -template "${TEMPLATES_DIR}/wordpress.conf.tmpl"  > "/etc/nginx/snippets/wordpress.conf"
dockerize -template "${TEMPLATES_DIR}/site.conf.tmpl"       > "/etc/nginx/conf.d/site.conf"
# configure real IP detection from CF
curl -sL https://www.cloudflare.com/ips-v4|awk '{print "set_real_ip_from", $1";"}' >  "/etc/nginx/snippets/cloudflare.conf"
curl -sL https://www.cloudflare.com/ips-v6|awk '{print "set_real_ip_from", $1";"}' >> "/etc/nginx/snippets/cloudflare.conf"
# configure supervisor
dockerize -template "${TEMPLATES_DIR}/supervisor.conf.tmpl" > "/etc/supervisor/conf.d/wordpress.conf"

# Generate WP secret keys
[ -z "${WP_SECRET_KEYS_BLOCK}" ] && export WP_SECRET_KEYS_BLOCK=$(curl -sL "https://api.wordpress.org/secret-key/1.1/salt/")
# Generate WP configuration from the template
dockerize -template "${TEMPLATES_DIR}/wp-config.php.tmpl" > "${WP_DIR}/wp-config.php"
# Set proper ownership
chown www-data:www-data "${WP_DIR}/wp-config.php"
chown -R www-data:www-data ${WP_DIR}/wp-content/cache
# NOT recursive!
chown www-data:www-data ${WP_DIR}/wp-content/uploads
# it's faster to find files not owned by certain user rather than update them all at once
find ${WP_DIR}/wp-content/uploads \! -user www-data -group www-data -exec chown www-data:www-data {} \;

