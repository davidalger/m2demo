#!/usr/bin/env bash
set -eu
trap '>&2 printf "\n\e[01;31mERROR\033[0m: Command \`%s\` on line $LINENO failed with exit code $?\n" "$BASH_COMMAND"' ERR

function :: {
    echo
    echo "==> [$(date +%H:%M:%S)] $@"
}

## find directory where this script is located following symlinks if neccessary
readonly BASE_DIR="$(
  cd "$(
    dirname "$(
      (readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}") \
        | sed -e "s#^../#$(dirname "$(dirname "${BASH_SOURCE[0]}")")/#"
    )"
  )" >/dev/null \
  && pwd
)"
cd "${BASE_DIR}"

## load configuration needed for installation
source .env
ADMIN_PASS="$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g' | colrm 17)"
ADMIN_USER=demoadmin
URL_FRONT="https://${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}/"
URL_ADMIN="https://${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}/backend/"

:: Starting Warden
warden up
if [[ ! -f ~/.warden/ssl/certs/magento.test.crt.pem ]]; then
    warden sign-certificate magento.test
fi

:: Initializing environment
docker-compose up -d

:: Installing Magento
docker-compose exec -T php-fpm bin/magento setup:install \
    --backend-frontname=backend \
    --amqp-host=rabbitmq \
    --amqp-port=5672 \
    --amqp-user=guest \
    --amqp-password=guest \
    --db-host=db \
    --db-name=magento \
    --db-user=magento \
    --db-password=magento \
    --http-cache-hosts=varnish:80 \
    --session-save=redis \
    --session-save-redis-host=redis \
    --session-save-redis-port=6379 \
    --session-save-redis-db=2 \
    --session-save-redis-max-concurrency=20 \
    --cache-backend=redis \
    --cache-backend-redis-server=redis \
    --cache-backend-redis-db=0 \
    --cache-backend-redis-port=6379 \
    --page-cache=redis \
    --page-cache-redis-server=redis \
    --page-cache-redis-db=1 \
    --page-cache-redis-port=6379

:: Configuring Magento
docker-compose exec -T php-fpm bin/magento config:set -q --lock-env web/unsecure/base_url ${URL_FRONT}
docker-compose exec -T php-fpm bin/magento config:set -q --lock-env web/secure/base_url ${URL_FRONT}
docker-compose exec -T php-fpm bin/magento config:set -q --lock-env web/secure/use_in_frontend 1
docker-compose exec -T php-fpm bin/magento config:set -q --lock-env web/secure/use_in_adminhtml 1
docker-compose exec -T php-fpm bin/magento config:set -q --lock-env web/seo/use_rewrites 1
docker-compose exec -T php-fpm bin/magento config:set -q --lock-env system/full_page_cache/caching_application 2

:: Enabling production mode
docker-compose exec -T php-fpm bin/magento deploy:mode:set -s production
docker-compose exec -T php-fpm bin/magento setup:static-content:deploy -j $(nproc)

:: Rebuilding Magento indexers
docker-compose exec -T php-fpm bin/magento indexer:reindex

:: Flushing the cache
docker-compose exec -T php-fpm bin/magento cache:clean

:: Creating admin user
docker-compose exec -T php-fpm bin/magento admin:user:create \
    --admin-password="${ADMIN_PASS}" \
    --admin-user="${ADMIN_USER}" \
    --admin-firstname="Demo" \
    --admin-lastname="User" \
    --admin-email="${ADMIN_USER}@example.com"

:: Demo build complete
function print_install_info {
    FILL=$(printf "%0.s-" {1..128})
    C1_LEN=8
    let "C2_LEN=${#URL_ADMIN}>${#ADMIN_PASS}?${#URL_ADMIN}:${#ADMIN_PASS}"
    
    # note: in CentOS bash .* isn't supported (is on Darwin), but *.* is more cross-platform
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN FrontURL $C2_LEN "$URL_FRONT"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN AdminURL $C2_LEN "$URL_ADMIN"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN Username $C2_LEN "$ADMIN_USER"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN Password $C2_LEN "$ADMIN_PASS"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
}
print_install_info
