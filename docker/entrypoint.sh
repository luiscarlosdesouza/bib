#!/bin/bash
set -e

echo "[bib-entrypoint] Iniciando container da Biblioteca (IME-USP)..."

# Garantir diretórios graváveis do WordPress (arquivos já vêm com www-data via COPY --chown)
mkdir -p /var/www/html/wp-content/uploads /var/www/html/wp-content/upgrade /var/www/html/wp-content/cache
chown www-data:www-data /var/www/html/wp-content /var/www/html/wp-content/uploads /var/www/html/wp-content/upgrade /var/www/html/wp-content/cache

# Ler variáveis de conexão ao banco
DB_HOST_RAW="${WORDPRESS_DB_HOST:-${DB_HOST:-db:3306}}"
DB_HOST_NAME="${DB_HOST_RAW%%:*}"
DB_PORT_NUM="${DB_HOST_RAW##*:}"
if [ "$DB_PORT_NUM" = "$DB_HOST_RAW" ]; then
    DB_PORT_NUM="3306"
fi

DB_NAME_VAL="${WORDPRESS_DB_NAME:-${DB_NAME:-bib}}"
DB_USER_VAL="${WORDPRESS_DB_USER:-${DB_USER:-bib}}"
DB_PASS_VAL="${WORDPRESS_DB_PASSWORD:-${DB_PASSWORD:-}}"

echo "[bib-entrypoint] Aguardando banco de dados em ${DB_HOST_NAME}:${DB_PORT_NUM}..."
MAX_TRIES=60
COUNT=0
until mariadb -h"$DB_HOST_NAME" -P"$DB_PORT_NUM" -u"$DB_USER_VAL" -p"$DB_PASS_VAL" --skip-ssl -e "SELECT 1;" >/dev/null 2>&1; do
    COUNT=$((COUNT + 1))
    if [ "$COUNT" -ge "$MAX_TRIES" ]; then
        echo "[bib-entrypoint] AVISO: Banco de dados não respondeu após ${MAX_TRIES} tentativas. Prosseguindo com inicialização do Apache..."
        exec "$@"
    fi
    sleep 2
done
echo "[bib-entrypoint] Conexão com o banco de dados estabelecida!"

# Verificar se o banco já possui as tabelas do WordPress (ex: wp_options)
HAS_TABLES=$(mariadb -h"$DB_HOST_NAME" -P"$DB_PORT_NUM" -u"$DB_USER_VAL" -p"$DB_PASS_VAL" --skip-ssl -N -e "SHOW TABLES LIKE 'wp_options';" "$DB_NAME_VAL" 2>/dev/null || true)

if [ -z "$HAS_TABLES" ]; then
    if [ -f "/usr/src/bib-db/bib.sql.gz" ]; then
        echo "[bib-entrypoint] Banco '${DB_NAME_VAL}' vazio. Importando dump inicial (/usr/src/bib-db/bib.sql.gz)..."
        gunzip -c /usr/src/bib-db/bib.sql.gz | mariadb -h"$DB_HOST_NAME" -P"$DB_PORT_NUM" -u"$DB_USER_VAL" -p"$DB_PASS_VAL" --skip-ssl "$DB_NAME_VAL"
        echo "[bib-entrypoint] Importação do banco de dados concluída com sucesso!"
    elif [ -f "/usr/src/bib-db/bib.sql" ]; then
        echo "[bib-entrypoint] Banco '${DB_NAME_VAL}' vazio. Importando dump inicial (/usr/src/bib-db/bib.sql)..."
        mariadb -h"$DB_HOST_NAME" -P"$DB_PORT_NUM" -u"$DB_USER_VAL" -p"$DB_PASS_VAL" --skip-ssl "$DB_NAME_VAL" < /usr/src/bib-db/bib.sql
        echo "[bib-entrypoint] Importação do banco de dados concluída com sucesso!"
    else
        echo "[bib-entrypoint] AVISO: Arquivo de dump inicial não encontrado em /usr/src/bib-db/."
    fi
else
    echo "[bib-entrypoint] Banco de dados já inicializado (tabela wp_options encontrada)."
fi

# Ajuste dinâmico de URL (WP_HOME) e caminhos legados via WP-CLI
if [ -n "$WP_HOME" ]; then
    TARGET_URL="${WP_HOME%/}"
    LAST_MIGRATED=$(wp option get bib_last_migrated_url --allow-root --path=/var/www/html 2>/dev/null || true)

    if [ "$LAST_MIGRATED" != "$TARGET_URL" ]; then
        echo "[bib-entrypoint] Ajustando URLs internas do banco para: ${TARGET_URL}..."

        if [ -n "$LAST_MIGRATED" ] && [ "$LAST_MIGRATED" != "$TARGET_URL" ]; then
            wp search-replace "$LAST_MIGRATED" "$TARGET_URL" --all-tables --precise --skip-columns=guid --allow-root --path=/var/www/html >/dev/null 2>&1 || true
        fi

        # Substituir URLs antigas do servidor desativado
        wp search-replace "https://www.ime.usp.br/bib" "$TARGET_URL" --all-tables --precise --skip-columns=guid --allow-root --path=/var/www/html >/dev/null 2>&1 || true
        wp search-replace "http://www.ime.usp.br/bib" "$TARGET_URL" --all-tables --precise --skip-columns=guid --allow-root --path=/var/www/html >/dev/null 2>&1 || true
        wp search-replace "http://www2.ime.usp.br:8088/bib" "$TARGET_URL" --all-tables --precise --skip-columns=guid --allow-root --path=/var/www/html >/dev/null 2>&1 || true
        wp search-replace "http://www2.ime.usp.br:8088/biblioteca" "$TARGET_URL" --all-tables --precise --skip-columns=guid --allow-root --path=/var/www/html >/dev/null 2>&1 || true
        wp search-replace "/home/spec/bib/www" "/var/www/html" --all-tables --precise --allow-root --path=/var/www/html >/dev/null 2>&1 || true

        wp option update home "$TARGET_URL" --allow-root --path=/var/www/html >/dev/null 2>&1 || true
        wp option update siteurl "$TARGET_URL" --allow-root --path=/var/www/html >/dev/null 2>&1 || true
        wp option update bib_last_migrated_url "$TARGET_URL" --autoload=no --allow-root --path=/var/www/html >/dev/null 2>&1 || true

        wp cache flush --allow-root --path=/var/www/html >/dev/null 2>&1 || true
        wp rewrite flush --hard --allow-root --path=/var/www/html >/dev/null 2>&1 || true
        chown www-data:www-data /var/www/html/.htaccess 2>/dev/null || true

        echo "[bib-entrypoint] URLs atualizadas com sucesso para ${TARGET_URL}!"
    else
        echo "[bib-entrypoint] URLs do banco já estão sincronizadas com ${TARGET_URL}."
    fi
fi

# Redefinição opcional de senha do usuário administrador via variável de ambiente
if [ -n "$WP_ADMIN_PASSWORD" ]; then
    ADMIN_USER="${WP_ADMIN_USER:-admin}"
    echo "[bib-entrypoint] Atualizando senha do usuário '${ADMIN_USER}' conforme definido em WP_ADMIN_PASSWORD..."
    wp user update "$ADMIN_USER" --user_pass="$WP_ADMIN_PASSWORD" --allow-root --path=/var/www/html >/dev/null 2>&1 || true
fi

echo "[bib-entrypoint] Inicialização concluída. Subindo Apache (PHP $(php -r 'echo PHP_VERSION;'))..."
if [ "$#" -eq 0 ]; then
    exec apache2-foreground
else
    exec "$@"
fi
