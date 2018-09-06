#!/bin/bash

HOME="/home/pi"
SERVICE="pinkcoin.service"

createPinkconf() {
	DAYS=120
	DIR="$HOME/.pink2"
	FILE="$DIR/pinkconf.txt"

	# Generate random 64 character alphanumeric string (upper and lower case)
	RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)

	# Generate random 32 character alpha string (lowercase only)
	RPCUSERNAME=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 32 | head -n 1)

	# Create initial Pinkcoin Wallet directory
	mkdir -p "$DIR"

	# Create Pinkcoin Wallet configuration
	# Note: File should read as an INI (i.e. PHP)
	cat > "$FILE" << EOL
daemon=1

listen=1

rpcallowip="127.0.0.1"
rpcpassword="$RPCPASSWORD"
rpcport=31415
rpcssl=1
rpcsslciphers="TLSv1.2+HIGH:TLSv1+HIGH:!SSLv2:!aNULL:!eNULL:!3DES:@STRENGTH"
rpcuser="$RPCUSERNAME"

server=1
staking=1

txindex=1
EOL

	# Correct file permissions
	chmod 644 "$FILE"

	# Generate (sef-signed) SSL Certificate
	"$HOME/scripts/wallet_ssl.sh"
}

createSSHCredentials() {
	DIR="$HOME/.ssh"
	FILE="$DIR/id_rsa"

	# Clear any existing setup
	rm -fR "$DIR"

	# (Re-)Create directory
	mkdir -p "$DIR"
	chmod 700 "$DIR"

	# Generate new SSH Public/Private pair
	# TODO Provide access via PinkPiUi
	ssh-keygen -b 4096 -t rsa -f "$FILE" -N ""

	# Allow this key access
	cat "$FILE.pub" >> "$DIR/authorized_keys"

	# Remove default password
	sudo passwd -d pi
}


# Generate SSH Key (overwrite)
createSSHCredentials

# Generate RPC Credentials (i.e. pinkconf.txt)
createPinkconf

# Self-destruct
sudo sed -i "/once.sh/d" "$HOME/crontab/pinkpi"
sudo rm "$0"
