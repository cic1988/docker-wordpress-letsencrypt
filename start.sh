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

    echo "creating .env file ..." &&
        cat ".env.sample" | grep -v "#" | sed '/^[[:space:]]*$/d' >".env"

    echo "replace domain via given URL ..." &&
        domain="$URL" && domain=${domain#*//}

    if [ "$?" == 0 ]; then
        sed '/DOMAINS=/d' ".env" >".env.tmp" && mv ".env.tmp" ".env" && echo "DOMAINS=$domain" >>".env"
    else
        echo "error by replacing domain, exit" && exit 1
    fi

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

add_config_jwt() {
    if [ -e "$WP_CORE/wp-config.php" ]; then
        echo "add jwt config ..."
        cat "$WP_CORE/wp-config.php" | grep "JWT_AUTH_SECRET_KEY" >/dev/null

        if [ "$?" == "0" ]; then
            echo "JWT_AUTH_SECRET_KEY already set, ignored ..."
        else
            #TODO: need to add the config before this line, see: https://github.com/Tmeister/wp-api-jwt-auth/issues/59
            ln=$(cat "$WP_CORE/wp-config.php" | grep -n "require_once( ABSPATH . 'wp-settings.php' );" | cut -d":" -f1)

            if [ "$?" == 0 ]; then
                rand=$(openssl rand -base64 12)
                jwt_config="define('JWT_AUTH_SECRET_KEY', '$rand');"

                sed -i "$ln"i" $jwt_config" "$WP_CORE/wp-config.php"
            else
                echo "error by adding jwt config, exit"
                exit 1
            fi
        fi
    fi
}

wait_for_build() {
    docker-compose up -d
    echo 'waiting for init ...'

    while ! (docker-compose logs | grep 'web service started ...') &>/dev/null; do
        # sleep 2 seconds
        echo 'waiting...' && sleep 2
    done

    #TODO: why the access right is modified? in centos7
    chown 33:tape -R "$WP_CONTENT"
    echo 'finished init'

    echo "copy .htaccess to $WP_CORE"
    cp .htaccess "$WP_CORE/"

    add_config_jwt;
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

    exit 0
fi
