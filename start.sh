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
ADMIN_PASS=
ADMIN_USER=demoadmin
URL_FRONT="https://${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}/"
URL_ADMIN="https://${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}/backend/"

## generate admin password trying up to 10 iterations to ensure we get one with a number
i=0
while (( i++ <10 )) && [[ ! ${ADMIN_PASS} =~ ^.*[0-9]+.*$ ]]; do
  ADMIN_PASS="$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g' | colrm 17)"
done

## increase the docker-compose timeout since it can take some time to create the
## container volume due to the size of sample data copied into the volume on start
export COMPOSE_HTTP_TIMEOUT=180

:: Starting Warden
warden up
if [[ ! -f ~/.warden/ssl/certs/magento.test.crt.pem ]]; then
    warden sign-certificate magento.test
fi

:: Initializing environment
warden env up -d

## wait for mariadb to start listening for connections
warden shell -c "while ! nc -z db 3306 </dev/null; do sleep 2; done"

## Only 2.3 and later support amqp params being specified
AMQP_PARAMS=
if (( $(echo ${MAGENTO_VERSION:-2.3} | tr . " " | awk '{print $1$2}') > 22 )); then
  AMQP_PARAMS="
    --amqp-host=rabbitmq
    --amqp-port=5672
    --amqp-user=guest
    --amqp-password=guest
  "
fi

:: Installing Magento
warden env exec -- -T php-fpm bin/magento setup:install \
    --backend-frontname=backend \
    ${AMQP_PARAMS} \
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
warden env exec -T php-fpm bin/magento config:set -q --lock-env web/unsecure/base_url ${URL_FRONT}
warden env exec -T php-fpm bin/magento config:set -q --lock-env web/secure/base_url ${URL_FRONT}
warden env exec -T php-fpm bin/magento config:set -q --lock-env web/secure/use_in_frontend 1
warden env exec -T php-fpm bin/magento config:set -q --lock-env web/secure/use_in_adminhtml 1
warden env exec -T php-fpm bin/magento config:set -q --lock-env web/seo/use_rewrites 1
warden env exec -T php-fpm bin/magento config:set -q --lock-env system/full_page_cache/caching_application 2

:: Enabling production mode
warden env exec -T php-fpm bin/magento deploy:mode:set -s production

:: Rebuilding Magento indexers
warden env exec -T php-fpm bin/magento indexer:reindex

:: Flushing the cache
warden env exec -T php-fpm bin/magento cache:clean

:: Creating admin user
warden env exec -T php-fpm bin/magento admin:user:create \
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
