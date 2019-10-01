#!/bin/bash

WOOCOMMERCE_URL="https://downloads.wordpress.org/plugin/woocommerce.3.7.0.zip";
WO2WE_URL="https://api.github.com/repos/cic1988/weorder-admin-docker/releases/latest";
JWT_URL="https://downloads.wordpress.org/plugin/jwt-authentication-for-wp-rest-api.1.2.6.zip";

# 1) .env
echo "creating .env file ..."
cat ".env.sample" | grep -v "#" | sed '/^[[:space:]]*$/d' > ".env"

while IFS="=" read -r key value; do
    case "$key" in
      "WP_PLUGINS") WP_PLUGINS="$value" ;;
      "WP_CONTENT") WP_CONTENT="$value" ;;
    esac
done < ".env"

if [ ! -d $WP_PLUGINS ]; then
    mkdir -p $WP_PLUGINS
fi

# 2) install woocommerce
echo "install woocommerce ..."
wget -O "$WP_PLUGINS/woocommerce.zip" $WOOCOMMERCE_URL && \
unzip "$WP_PLUGINS/woocommerce.zip" -d "$WP_PLUGINS/"

if [ $? -ne 0 ]; then
    exit 1
fi

# 3) install woocommerce-to-weorder
curl -s $WO2WE_URL | \
grep "browser_download_url.*zip" | \
cut -d '"' -f 4 | \
xargs wget -O "$WP_PLUGINS/woocomerce-to-weorder.zip" && \
unzip "$WP_PLUGINS/woocomerce-to-weorder.zip" -d "$WP_PLUGINS/"

if [ $? -ne 0 ]; then
    exit 1
fi

# 3) install JWT authentication
wget -O "$WP_PLUGINS/jwt-authentication.zip" $JWT_URL && \
unzip "$WP_PLUGINS/jwt-authentication.zip" -d "$WP_PLUGINS/"

rm -rf "$WP_PLUGINS/*.zip"

# final: start docker-compose
docker-compose up -d
