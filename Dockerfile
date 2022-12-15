FROM registry.digitalocean.com/dslk/php/php:7.4

WORKDIR /var/www
RUN apt-get update && \
    apt-get install -y nginx-full apache2-utils cron supervisor && \
    # install WP CLI
    curl -sL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp && \
    chmod +x /usr/local/bin/wp && \
    mkdir -p /var/cache/nginx/wp /etc/nginx/conf.redirects/ && \
    chown -R www-data:www-data /var/cache/nginx /etc/nginx/conf.redirects && \
    rm -rf /var/www/*

ARG WP_VERSION=6.1
ENV WP_VERSION=${WP_VERSION}

RUN curl -sL https://wordpress.org/wordpress-${WP_VERSION}.tar.gz | tar -zx --strip-components=1 --wildcards wordpress/* && \
    rm -rf /var/www/wp-content/themes/twentytwenty && \
    rm -rf /var/www/wp-content/themes/twentytwentyone && \
    rm -rf /var/www/wp-content/plugins/* && \
    # Make sure robots.txt gets stored in the volume
    ln -sf /var/www/wp-content/uploads/robots.txt /var/www/robots.txt && \
    mkdir -p /var/www/wp-content/uploads /var/www/content/cache /var/www/wp-content/languages && \
    chown -R www-data:www-data /var/www

# place dummy certs
COPY certs/* /etc/nginx/ssl/
COPY *.tmpl ${TEMPLATES_DIR}/
COPY prerun.sh                 /prerun/10-wp.sh
# add metrics script
COPY send-wp-plugin-metrics.sh /usr/local/bin/send-wp-plugin-metrics

ENV WP_DIR=/var/www
ENV WP_DB_HOST=mysql
ENV WP_CONFIG_HTTPS=false
ENV WP_POST_REVISIONS=5
ENV NGINX_HTTPS=false
ENV NGINX_BASIC_AUTH_LOGIN=digital
ENV NGINX_BASIC_AUTH_PASSWORD=silk
ENV FPM_LISTEN_SOCKET=true
ENV NGINX_FASTCGI_READ_TIMEOUT=60

EXPOSE 80 443 9000

VOLUME ["/var/www/wp-content/uploads", "/var/www/wp-content/cache", "/var/www/wp-content/languages", "/etc/nginx/conf.redirects"]

CMD ["supervisord"]
