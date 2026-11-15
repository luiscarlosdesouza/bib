FROM wordpress:php8.3-apache

# A imagem wordpress:php8.3-apache já traz mysqli, gd, imagick, zip, intl, exif, bcmath e opcache pré-compilados.
# Instalamos apenas o mariadb-client e o WP-CLI (execução em poucos segundos).
RUN apt-get update && apt-get install -y --no-install-recommends \
        mariadb-client \
        less \
        gzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sS -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp \
    && printf "ServerName localhost\nServerTokens Prod\nServerSignature Off\n" > /etc/apache2/conf-available/security-hardening.conf \
    && a2enconf security-hardening

# Copiar configurações otimizadas do PHP, dump compactado do banco e script de inicialização
COPY docker/php/custom.ini /usr/local/etc/php/conf.d/zz-bib-custom.ini
COPY docker/db/bib.sql.gz /usr/src/bib-db/bib.sql.gz
COPY docker/entrypoint.sh /usr/local/bin/bib-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/bib-entrypoint.sh \
    && chmod +x /usr/local/bin/bib-entrypoint.sh

# Copiar código da aplicação já com permissão www-data:www-data
WORKDIR /var/www/html
COPY --chown=www-data:www-data . /var/www/html/
RUN rm -rf /var/www/html/docker /var/www/html/Dockerfile /var/www/html/docker-compose*.yml /var/www/html/.dockerignore /var/www/html/.gitattributes

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/bib-entrypoint.sh"]
CMD ["apache2-foreground"]
