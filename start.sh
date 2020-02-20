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
URL_FRONT="https://${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}/"
URL_ADMIN="https://${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}/backend/"

## increase the docker-compose timeout since it can take some time to create the
## container volume due to the size of sample data copied into the volume on start
export COMPOSE_HTTP_TIMEOUT=180

## argument parsing
## parse arguments
while (( "$#" )); do
    case "$1" in
        --no-sampledata)
            export MAGENTO_VARIANT=
            shift
            ;;
        --help)
            echo "Usage: $(basename $0) [--no-sampledata]"
            echo ""
            echo "       --no-sampledata                    starts m2demo using demo images without sampledata"
            echo ""
            exit -1
            ;;
        *)
            >&2 printf "\e[01;31mERROR\033[0m: Unrecognized argument '$1'\n"
            exit -1
            ;;
    esac
done

:: Starting Warden
warden up
if [[ ! -f ~/.warden/ssl/certs/"${TRAEFIK_DOMAIN}".crt.pem ]]; then
    warden sign-certificate "${TRAEFIK_DOMAIN}"
fi

:: Initializing environment
warden env up -d

## wait for mariadb to start listening for connections
warden shell -c "while ! nc -z db 3306 </dev/null; do sleep 2; done"

:: Installing Magento
warden env exec -- -T php-fpm bin/magento setup:install \
    --backend-frontname=backend \
    --amqp-host=rabbitmq \
    --amqp-port=5672 \
    --amqp-user=guest \
    --amqp-password=guest \
    --consumers-wait-for-messages=0 \
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
warden env exec -T php-fpm bin/magento config:set -q --lock-env system/full_page_cache/ttl 604800

warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/engine elasticsearch6
warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/enable_eav_indexer 1
warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch6_server_hostname elasticsearch
warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch6_server_port 9200
warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch6_index_prefix magento2
warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch6_enable_auth 0
warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch6_server_timeout 15

:: Enabling production mode
warden env exec -T php-fpm bin/magento deploy:mode:set -s production

:: Rebuilding indexes
warden env exec -T php-fpm bin/magento indexer:reindex

:: Flushing the cache
warden env exec -T php-fpm bin/magento cache:flush

:: Creating admin user
ADMIN_PASS=$(warden env exec -T php-fpm pwgen -n1 16)
ADMIN_USER=localadmin

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
