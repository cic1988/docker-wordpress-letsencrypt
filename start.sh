#!/bin/bash
#set -x
#******************************************************************************
# @file    : start.sh
# @author  : Yuan Gao
# @date    : 2019-10-05 10:18:43
#
# @brief   : start the docker-compose
# history  : init
#******************************************************************************

usage() {
    echo ""
    echo "Usage: $0 --url <SITE_URL>"
    echo -e "\n"
    echo -e "\t-u, --url         URL for the site. E.g --url http://<YOUR DOMAIN>"
    echo -e "\t-p, --no-plugin   only setup an empty site without plugins. Default false"
    echo -e "\t-f, --force       shutdown compose and remove wordpress local files"
    echo -e "\t-h, --help        print help information"
    exit 1
}

declare URL
declare NO_PLUGIN
declare WP_CORE
declare WP_CONTENT
declare FORCE
declare LETSENCRYPT_EMAIL

while [ "$1" != "" ]; do
    case $1 in
    -u | --url)
        shift
        URL=$1
        ;;
    -p | --no-plugin)
        NO_PLUGIN=1
        ;;
    -f | --force)
        FORCE=1
        ;;
    -h | --help)
        usage
        exit
        ;;
    *)
        usage
        exit 1
        ;;
    esac
    shift
done

init_before_build() {
    if [ "$URL" == "" ]; then
        echo 'site url is empty, specify one via --url <SITE URL>'
        exit 1
    fi

    echo "creating .env file ..."
    cat ".env.sample" | grep -v "#" | sed '/^[[:space:]]*$/d' >".env"

    while IFS="=" read -r key value; do
        case "$key" in
        "WP_CORE") WP_CORE="$value" ;;
        "WP_CONTENT") WP_CONTENT="$value" ;;
        "LETSENCRYPT_EMAIL") LETSENCRYPT_EMAIL="$value" ;;
        esac
    done <".env"

    if [ $FORCE ]; then
        docker-compose down
    fi
}

wait_for_build() {
    docker-compose up -d
    echo 'waiting for init ...'

    while ! (docker-compose logs | grep 'web service started ...') &>/dev/null; do
        # sleep 2 seconds
        echo 'waiting...' && sleep 2
    done
    echo 'finished init'
}

# no plugins
if [ $NO_PLUGIN ]; then
    init_before_build
    wait_for_build

    # 2) wordpress installation
    # --url parameter (The address of the new site.)
    # --title parameter (The title of the new site.)
    # --admin_user parameter (The name of the admin user.)
    # --admin_password parameter (The password for the admin user.)
    # --admin_email parameter (The email address for the admin user.)
    docker-compose run --rm wpcli core install \
        --url="$URL" \
        --title="Demo" \
        --admin_user="admin" \
        --admin_password="admin" \
        --admin_email="$LETSENCRYPT_EMAIL"
    exit 0

else
    init_before_build
    wait_for_build

    # 2) wordpress installation
    # --url parameter (The address of the new site.)
    # --title parameter (The title of the new site.)
    # --admin_user parameter (The name of the admin user.)
    # --admin_password parameter (The password for the admin user.)
    # --admin_email parameter (The email address for the admin user.)
    docker-compose run --rm wpcli core install \
        --url="$URL" \
        --title="Demo" \
        --admin_user="admin" \
        --admin_password="admin" \
        --admin_email="$LETSENCRYPT_EMAIL"

    # 3) install all-in-one-migration
    docker-compose run --rm wpcli plugin install "all-in-one-wp-migration" --activate

    if [ $? ]; then
        echo "<IfModule mod_rewrite.c>
RewriteEngine on
RewriteCond %{HTTP:Authorization} ^(.*)
RewriteRule ^(.*) - [E=HTTP_AUTHORIZATION:%1]
</IfModule>" >>"$WP_CORE/.htaccess"

        
    fi

    exit 0
fi
