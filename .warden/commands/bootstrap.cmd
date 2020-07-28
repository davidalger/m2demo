#!/usr/bin/env bash
[[ ! ${WARDEN_DIR} ]] && >&2 echo -e "\033[31mThis script is not intended to be run directly!\033[0m" && exit 1
set -euo pipefail

function :: {
  echo
  echo "==> [$(date +%H:%M:%S)] $@"
}

## load configuration needed for setup
WARDEN_ENV_PATH="$(locateEnvPath)" || exit $?
loadEnvConfig "${WARDEN_ENV_PATH}" || exit $?
assertDockerRunning

## load version from as it won't be loaded by loadEnvConfig
eval "$(grep "^MAGENTO_VERSION" "${WARDEN_ENV_PATH}/.env")"

## change into the project directory
cd "${WARDEN_ENV_PATH}"

## configure command defaults
AUTO_PULL=1
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
        --no-pull)
            AUTO_PULL=
            shift
            ;;
        *)
            error "Unrecognized argument '$1'"
            exit -1
            ;;
    esac
done

:: Verifying configuration
INIT_ERROR=

## verify warden version constraint
WARDEN_VERSION=$(warden version 2>/dev/null) || true
WARDEN_REQUIRE=0.6.0
if ! test $(version ${WARDEN_VERSION}) -ge $(version ${WARDEN_REQUIRE}); then
  error "Warden ${WARDEN_REQUIRE} or greater is required (version ${WARDEN_VERSION} is installed)"
  INIT_ERROR=1
fi

## exit script if there are any missing dependencies or configuration files
[[ ${INIT_ERROR} ]] && exit 1

:: Starting Warden
warden svc up
if [[ ! -f ~/.warden/ssl/certs/${TRAEFIK_DOMAIN}.crt.pem ]]; then
    warden sign-certificate ${TRAEFIK_DOMAIN}
fi

:: Initializing environment
if [[ $AUTO_PULL ]]; then
  warden env pull --ignore-pull-failures || true
  warden env build --pull
else
  warden env build
fi
warden env up -d

## wait for mariadb to start listening for connections
warden shell -c "while ! nc -z db 3306 </dev/null; do sleep 2; done"

:: Installing application
INSTALL_PARAMS=(
  --backend-frontname=backend
  --amqp-host=rabbitmq
  --amqp-port=5672
  --amqp-user=guest
  --amqp-password=guest
  --consumers-wait-for-messages=0
  --db-host=db
  --db-name=magento
  --db-user=app
  --db-password=app
  --http-cache-hosts=varnish:80
  --session-save=redis
  --session-save-redis-host=redis
  --session-save-redis-port=6379
  --session-save-redis-db=2
  --session-save-redis-max-concurrency=20
  --cache-backend=redis
  --cache-backend-redis-server=redis
  --cache-backend-redis-db=0
  --cache-backend-redis-port=6379
  --page-cache=redis
  --page-cache-redis-server=redis
  --page-cache-redis-db=1
  --page-cache-redis-port=6379
)

if test $(version ${MAGENTO_VERSION}) -ge $(version 2.4.0); then
    INSTALL_PARAMS+=(
      --search-engine=elasticsearch7
      --elasticsearch-host=elasticsearch
      --elasticsearch-port=9200
      --elasticsearch-index-prefix=magento2
      --elasticsearch-enable-auth=0
      --elasticsearch-timeout=15
    )
fi

warden env exec -- -T php-fpm bin/magento setup:install "${INSTALL_PARAMS[@]}"

:: Configuring application
warden env exec -T php-fpm bin/magento config:set -q --lock-env web/unsecure/base_url ${URL_FRONT}
warden env exec -T php-fpm bin/magento config:set -q --lock-env web/secure/base_url ${URL_FRONT}

warden env exec -T php-fpm bin/magento config:set -q --lock-env web/secure/use_in_frontend 1
warden env exec -T php-fpm bin/magento config:set -q --lock-env web/secure/use_in_adminhtml 1
warden env exec -T php-fpm bin/magento config:set -q --lock-env web/seo/use_rewrites 1

warden env exec -T php-fpm bin/magento config:set -q --lock-env system/full_page_cache/caching_application 2
warden env exec -T php-fpm bin/magento config:set -q --lock-env system/full_page_cache/ttl 604800

warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/enable_eav_indexer 1

if test $(version ${MAGENTO_VERSION}) -lt $(version 2.4.0); then
  warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/engine elasticsearch7
  warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch7_server_hostname elasticsearch
  warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch7_server_port 9200
  warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch7_index_prefix magento2
  warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch7_enable_auth 0
  warden env exec -T php-fpm bin/magento config:set -q --lock-env catalog/search/elasticsearch7_server_timeout 15
fi

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
    --admin-firstname="Local" \
    --admin-lastname="Admin" \
    --admin-email="${ADMIN_USER}@example.com"

OTPAUTH_QRI=
if test $(version $(warden env exec -T php-fpm bin/magento -V | awk '{print $3}')) -ge $(version 2.4.0); then
  TFA_SECRET=$(warden env exec -T php-fpm pwgen -A1 128)
  TFA_SECRET=$(
    warden env exec -T php-fpm python -c "import base64; print base64.b32encode('${TFA_SECRET}')" | sed 's/=*$//'
  )
  OTPAUTH_URL=$(printf "otpauth://totp/%s%%3Alocaladmin%%40example.com?issuer=%s&secret=%s" \
    "${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}" "${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}" "${TFA_SECRET}"
  )
  warden env exec -T php-fpm bin/magento config:set -q --lock-env twofactorauth/general/force_providers google
  warden env exec -T php-fpm bin/magento security:tfa:google:set-secret "${ADMIN_USER}" "${TFA_SECRET}"

  printf "%s\n\n" "${OTPAUTH_URL}"
  printf "2FA Authenticator Codes:\n%s\n" \
    "$(warden env exec -T php-fpm oathtool -s 30 -w 10 --totp --base32 "${TFA_SECRET}")"

  warden env exec -T php-fpm segno "${OTPAUTH_URL}" -s 4 -o "pub/media/${ADMIN_USER}-totp-qr.png"
  OTPAUTH_QRI="${URL_FRONT}media/${ADMIN_USER}-totp-qr.png?t=$(date +%s)"
fi

:: Initialization complete
function print_install_info {
    FILL=$(printf "%0.s-" {1..128})
    C1_LEN=8
    let "C2_LEN=${#URL_ADMIN}>${#ADMIN_PASS}?${#URL_ADMIN}:${#ADMIN_PASS}"
    let "C2_LEN=${C2_LEN}>${#OTPAUTH_QRI}?${C2_LEN}:${#OTPAUTH_QRI}"

    # note: in CentOS bash .* isn't supported (is on Darwin), but *.* is more cross-platform
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN FrontURL $C2_LEN "$URL_FRONT"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN AdminURL $C2_LEN "$URL_ADMIN"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    if [[ ${OTPAUTH_QRI} ]]; then
      printf "+ %-*s + %-*s + \n" $C1_LEN AdminOTP $C2_LEN "$OTPAUTH_QRI"
      printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    fi
    printf "+ %-*s + %-*s + \n" $C1_LEN Username $C2_LEN "$ADMIN_USER"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN Password $C2_LEN "$ADMIN_PASS"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
}
print_install_info
