#!/bin/bash
set -e

DATE=`date '+%Y%m%d%H%M%S'`
HOME="/home/pi"
SERVICE="pinkcoin.service"

allowScripts() {
	FILE="/etc/sudoers.d/pinkpi"

	cat > "$FILE" << EOL
# Enable scripts controlled by user action (or crontab PHP)
www-data ALL=(ALL) NOPASSWD: /home/pi/scripts/network_*.sh
www-data ALL=(ALL) NOPASSWD: /home/pi/scripts/transactions_*.sh
www-data ALL=(ALL) NOPASSWD: /home/pi/scripts/wallet_*.sh
EOL

	# Correct permissions
	chmod 440 "$FILE"
}

configureHostname() {
	HOST="pinkpi.local"

	# Setup hostname resolve
	echo "172.24.1.2	$HOST" >> "/etc/hosts"

	# Change hostname
	hostnamectl set-hostname "$HOST"
}

configureSwap() {
	# 2GB swap allocation (default: 100MB)
	sed -i 's/.*CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' "/etc/dphys-swapfile"

	# Restart swap service
	"/etc/init.d/dphys-swapfile" restart
}

createPinkcoinService() {
	FILE="/etc/systemd/system/$SERVICE"

	cat > "$FILE" << EOL
[Unit]
Description=Pinkcoin Wallet
Wants=network.target
After=network.target

[Service]
User=pi
Group=pi
WorkingDirectory=~
RuntimeDirectory=pinkcoin
Type=forking
ExecStart=/usr/bin/pink2d
ExecStop=/usr/bin/pink2d stop
PIDFile=$HOME/.pink2/pinkcoind.pid
Restart=always
RestartSec=60
TimeoutStartSec=0
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOL

	# Correct file permissions
	chmod 664 "$FILE"

	# Refresh System Control
	systemctl daemon-reload

	# Enable the Pinkcoin Wallet
	systemctl enable "$SERVICE"
}

createWWW() {
	DIR="/etc/nginx"

	# Create include file dependencies
	cat > "$DIR/conf.d/upstream_php.conf" << EOL
upstream php {
	server unix:/run/php/php7.0-fpm.sock;
}
EOL

	cat > "$DIR/fastcgi" << EOL
include fastcgi_params;

fastcgi_index index.php;
fastcgi_param HTTP_MOD_REWRITE on;
fastcgi_pass php;
fastcgi_split_path_info ^(.+\.php)(/.+)$;
EOL

	cat > "$DIR/fastcgi_params" << EOL
fastcgi_param  SCRIPT_FILENAME		\$document_root\$fastcgi_script_name;
fastcgi_param  QUERY_STRING			\$query_string;
fastcgi_param  REQUEST_METHOD		\$request_method;
fastcgi_param  CONTENT_TYPE			\$content_type;
fastcgi_param  CONTENT_LENGTH		\$content_length;

fastcgi_param  SCRIPT_NAME			\$fastcgi_script_name;
fastcgi_param  REQUEST_URI			\$request_uri;
fastcgi_param  DOCUMENT_URI			\$document_uri;
fastcgi_param  DOCUMENT_ROOT		\$document_root;
fastcgi_param  SERVER_PROTOCOL		\$server_protocol;
fastcgi_param  REQUEST_SCHEME		\$scheme;
fastcgi_param  HTTPS				\$https if_not_empty;

fastcgi_param  GATEWAY_INTERFACE	CGI/1.1;
fastcgi_param  SERVER_SOFTWARE		nginx/\$nginx_version;

fastcgi_param  REMOTE_ADDR			\$remote_addr;
fastcgi_param  REMOTE_PORT			\$remote_port;
fastcgi_param  SERVER_ADDR			\$server_addr;
fastcgi_param  SERVER_PORT			\$server_port;
fastcgi_param  SERVER_NAME			\$server_name;

# PHP only, required if PHP was built with --enable-force-cgi-redirect
fastcgi_param  REDIRECT_STATUS    200;
EOL

	cat > "$DIR/sites-available/default" << EOL
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	server_name _;
	root /home/pi/html;
	index index.html index.php;
	location /generate_204 {
		return 302 http://pinkpi.local/settings/;
	}
	location / {
		try_files \$uri \$uri/ =404;
	}
	location ~* \.(css|gif|html|ico|js|jpg|jpeg|pdf|png|svg|txt|xml)$ {
		access_log off;
		expires 1m;
		log_not_found off;
	}
	location ~* \.php$ {
		try_files \$uri \$uri/ =404;
		include fastcgi;
	}
}
EOL

	# Restart Nginx to take effect
	systemctl restart nginx
}

installUi() {
	DIR="$HOME/pinkpiui"
	TAG="0.1.10"
	TARGET="$DIR/$DATE"
	URL_REPO="https://github.com/Pink2Dev/PinkPiUi"

	# Download latest version
	git clone --branch "$TAG" "$URL_REPO" "$TARGET"
	if [ $? -ne 0 ]
	then
		exit 0
	fi

	# Mark current version
	echo "$TAG" > "$TARGET/VERSION"

	# Correct permissions
	chown -R pi:pi "$DIR"
	chown -R pi:pi "$TARGET"

	# Install PinkPiUi
	"$TARGET/scripts/ui_upgrade.sh"

	# Correct permissions
	chown pi:pi "$DIR/VERSION"
}

installWallet() {
	DIR="$HOME/pinkcoin"
	TAG="2.1.0.4"
	TARGET="$DIR/$DATE"
	URL_REPO="https://github.com/Pink2Dev/Pink2"

	# Download latest version
	git clone --branch "$TAG" "$URL_REPO" "$TARGET"
	if [ $? -ne 0 ]
	then
		exit 0
	fi

	# Mark current version
	echo "$TAG" > "$TARGET/VERSION"

	# Create directory
	mkdir -p "$HOME/.pink2"

	# Placeholder cofiguration
	cat > "$HOME/.pink2/pinkconf.txt" << EOL
daemon=1

listen=1

rpcallowip="127.0.0.1"
rpcpassword="password"
rpcport=31415
rpcssl=0
rpcsslciphers="TLSv1.2+HIGH:TLSv1+HIGH:!SSLv2:!aNULL:!eNULL:!3DES:@STRENGTH"
rpcuser="username"

server=1
staking=1

txindex=1
EOL

	# Correct permissions
	chown -R pi:pi "$DIR"
	chown -R pi:pi "$TARGET"
	chown -R pi:pi "$HOME/.pink2"

	chmod 755 "$HOME/.pink2"
}

# Adjust swap size
configureSwap

# Configure hostname
configureHostname

# Update to latest
apt-get clean
apt-get update
apt-get dist-upgrade -y
apt-get autoclean

# Install dependencies
apt-get install -y dnsmasq hostapd samba git nginx php-fpm php-bcmath php-curl

# Install web server
createWWW

# Enable Pinkcoin Wallet
createPinkcoinService

# Install initial PinkPiUi version
installUi

# Install initial Pinkcoin Wallet version
installWallet

# Allow interface to execute scripts
allowScripts

# Setup Maintenance
ln -fns "$HOME/crontab/pinkpi" /etc/cron.d/pinkpi

# Self-destruct
rm "$0"
