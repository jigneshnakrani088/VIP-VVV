#!/usr/bin/env bash

DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}
DOMAIN=`get_primary_host "${VVV_SITE_NAME}".dev`
DOMAINS=`get_hosts "${DOMAIN}"`

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/error.log
touch ${VVV_PATH_TO_SITE}/log/access.log

# Install and configure the latest stable version of WordPress
if [[ ! -d "${VVV_PATH_TO_SITE}/wordpress" ]]; then
	wp core download --path="${VVV_PATH_TO_SITE}/wordpress" --allow-root
fi

cd ${VVV_PATH_TO_SITE}/wordpress

if [[ ! -f "${VVV_PATH_TO_SITE}/wordpress/wp-config.php" ]]; then
	echo "Configuring VIP..."
	noroot wp core config --dbname=${DB_NAME} --dbuser=wp --dbpass=wp --quiet --allow-root --extra-php <<PHP
define( 'WP_CONTENT_DIR', dirname( __DIR__ ) . '/wp-content' );

if ( ! isset( \$_SERVER['HTTP_HOST'] ) ) {
	\$_SERVER['HTTP_HOST'] = '${DOMAIN}';
}
/** Disable Automatic core updates. */
define( 'WP_AUTO_UPDATE_CORE', false );
define( 'QUICKSTART_ENABLE_CONCAT', true );

/**
 * WordPress Localized Language, defaults to English.
 *
 * Change this to localize WordPress. A corresponding MO file for the chosen
 * language must be installed to wp-content/languages. For example, install
 * de_DE.mo to wp-content/languages and set WPLANG to 'de_DE' to enable German
 * language support.
 */
if ( ! defined( 'WPLANG' ) ) {
	define( 'WPLANG', '' );
}
define( 'WP_DEBUG', true );
define( 'SAVEQUERIES', true );
if ( ! defined( 'JETPACK_DEV_DEBUG' ) ) {
	define( 'JETPACK_DEV_DEBUG', true );
}
// Put Keyring into headless mode
define( 'KEYRING__HEADLESS_MODE', true );

//if ( ! defined( 'DOMAIN_CURRENT_SITE' ) ) {
//	define( 'DOMAIN_CURRENT_SITE', \$_SERVER['HTTP_HOST'] );
//}

define( 'WP_MEMORY_LIMIT', '64M' );
define( 'WP_MAX_MEMORY_LIMIT', '256M' );

require __DIR__.'/../config/roles.php';
require __DIR__.'/../config/vip-config.php';

PHP
fi

plugins=(
	query-monitor
	debug-bar
	vip-scanner
)

function update_plugins {
	for i in ${plugins[@]}; do
  		if ! $(noroot wp plugin is-installed ${i}); then
  			echo "Installing plugin: ${i}"
  			noroot wp plugin install ${i} --activate-network
  		else
  			echo "Updating plugin: ${i}"
  			noroot wp plugin update ${i}
  		fi
	done
}

if ! $(noroot wp core is-installed --allow-root); then
	echo "Installing VIP..."
	noroot wp core multisite-install --subdomains --url=${DOMAIN} --quiet --title="VIP" --admin_name=admin --admin_email="admin@local.dev" --admin_password="password"
	#noroot wp core install --url=vip.localhost --quiet --title="VIP" --admin_name=admin --admin_email="admin@local.dev" --admin_password="password"
	echo "Installing twentyseventeen..."
	# we don't need to activate this as it's activated on install, although it isn't included, hence the install
	noroot wp theme install twentyseventeen
	echo "Installing VIP default plugins..."

	update_plugins

	echo "Installing VIP Shared Plugins..."
	mkdir -p ${VVV_PATH_TO_SITE}/wp-content/themes/vip/plugins/
	svn co https://vip-svn.wordpress.com/plugins/ ${VVV_PATH_TO_SITE}/wp-content/themes/vip/plugins/

	echo "Installing VIP MU Plugins..."
	git clone --recursive https://github.com/automattic/vip-wpcom-mu-plugins ${VVV_PATH_TO_SITE}/wp-content/mu-plugins

	echo "Installing Minimum Viable VIP Theme..."
	git clone https://github.com/Automattic/Minimum-Viable-VIP.git ${VVV_PATH_TO_SITE}/wp-content/themes/vip/minimumviablevip

	echo "Installing _s Theme..."
	git clone https://github.com/Automattic/_s.git ${VVV_PATH_TO_SITE}/wp-content/themes/_s

	echo "Completed Initial VIP Install script"
else
	echo "Updating VIP..."
	noroot wp core update
	echo "Updating VIP default themes"
	noroot wp theme update twentyseventeen

	update_plugins

	echo "Updating VIP Shared plugins..."
	svn up ${VVV_PATH_TO_SITE}/wp-content/themes/vip/plugins/

	echo "Updating VIP MU Plugins..."
	cd ${VVV_PATH_TO_SITE}/wp-content/mu-plugins
	git pull
	
	echo "Updating Minimum Viable VIP theme..."
	cd ${VVV_PATH_TO_SITE}/wp-content/themes/vip/minimumviablevip
	git pull
	cd -;

	echo "Updating _s theme..."
	cd ${VVV_PATH_TO_SITE}/wp-content/themes/_s
	git pull
	cd -;
	echo "Finished Update VIP script"
fi

echo "Setting up Nginx configs"
cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
sed -i "s#{{DOMAINS_HERE}}#${DOMAINS}#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
echo "Finished Nginx config setup"

echo "All done setting up ${DOMAIN}. Remember to checkout your VIP theme to ${VVV_PATH_TO_SITE}/wp-content/themes/vip/{your-theme}"