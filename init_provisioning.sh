#!/bin/sh

alias elevate="echo '$ELEVATE_PASS' | sudo -S "

get_prov_file()
{
	local path="$1"
	local output="$2"

	curl -s "http://$PACKER_HTTP_ADDR/$path" -o "$output"
}

get_prov_file_sudo()
{
	get_prov_file "$1" /tmp/tmp_file
	elevate mv /tmp/tmp_file "$2"
}

printf "\n===============================\n"
printf "STARTING e-ID INFRA PROVISIONER"
printf "\n===============================\n"

# Small pet-peeve of mine
printf "alias l='ls -al --color'\n" >> ~/.bashrc

printf "\n--------\n"
printf "Installing VSCode"
printf "\n--------\n"

cd "$(mktemp -d)"
arch="$(  ([ "_$(uname -m)" = "_aarch64" ] && printf "arm64") || printf "x64"  )"
curl -sL "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-$arch" -o vscode.deb

elevate env DEBIAN_FRONTEND=noninteractive \
	apt-get install -y ./vscode.deb

code --install-extension vscjava.vscode-java-pack
code --install-extension trailofbits.sarif-explorer
code --install-extension trailofbits.weaudit

# Setup VSCode configuration
mkdir -p ~/.config/Code/User/
get_prov_file /provisioning/vscode/settings.json ~/.config/Code/User/settings.json
mkdir -p ~/Documents/
get_prov_file /provisioning/vscode/swiyu.code-workspace ~/Documents/swiyu.code-workspace

# I'm doing it in multiple steps because I need `sudo`
cp /etc/hosts tmp_hosts
printf "127.0.0.1\tviscon.swiyu\n" >> tmp_hosts
elevate cp tmp_hosts /etc/hosts

printf "\n--------\n"
printf "Generating certs and nginx config"
printf "\n--------\n"

elevate openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
	-keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt \
	-subj "/C=CH/ST=Zurich/L=Zurich/O=VIScon/OU=Swiyu Pentest/CN=viscon.swiyu" 2>/dev/null

# Some operations (e.g. fetching the DID log via https) would fail due to the self-signed cert
elevate cp /etc/ssl/certs/nginx-selfsigned.crt /usr/local/share/ca-certificates/
elevate update-ca-certificates 2>&1

get_prov_file_sudo /provisioning/nginx/viscon.swiyu /etc/nginx/sites-available/viscon.swiyu
elevate ln -fs /etc/nginx/sites-available/viscon.swiyu /etc/nginx/sites-enabled/viscon.swiyu

# Apparently, the SSL settings must be removed to avoid a config due to duplicate settings
get_prov_file /provisioning/nginx/nginx.conf.patch /tmp/nginx.conf.patch
elevate patch -bi /tmp/nginx.conf.patch /etc/nginx/nginx.conf
elevate rm -f /etc/nginx/sites-enabled/default

elevate systemctl restart nginx.service

printf "\n--------\n"
printf "Generating DID logs"
printf "\n--------\n"

mkdir -p ~/Documents/didlogs/issuer
mkdir -p ~/Documents/didlogs/verifier
mkdir -p ~/Documents/didlogs/mallory

# https://github.com/swiyu-admin-ch/didtoolbox-java
# Generated with:
# java -jar didtoolbox.jar create \
#  --identifier-registry-url "https://viscon.swiyu/static/issuer" > issuer_did.jsonl
get_prov_file /provisioning/issuer/issuer_did.jsonl	~/Documents/didlogs/issuer/issuer_did.jsonl
cd ~/Documents/didlogs/issuer/
mkdir .didtoolbox && cd .didtoolbox
wget --recursive "http://$PACKER_HTTP_ADDR/provisioning/issuer/.didtoolbox/" --no-directories --no-verbose --execute=robots=off 2>&1


#  --identifier-registry-url "https://viscon.swiyu/static/verifier" > verifier_did.jsonl
get_prov_file /provisioning/verifier/verifier_did.jsonl	~/Documents/didlogs/verifier/verifier_did.jsonl
cd ~/Documents/didlogs/verifier/
mkdir .didtoolbox && cd .didtoolbox
wget --recursive "http://$PACKER_HTTP_ADDR/provisioning/verifier/.didtoolbox/" --no-directories --no-verbose --execute=robots=off 2>&1


# --identifier-registry-url https://viscon.swiyu/static/mallory > mallory_did.jsonl
get_prov_file /provisioning/mallory/mallory_did.jsonl	~/Documents/didlogs/mallory/mallory_did.jsonl
cd ~/Documents/didlogs/mallory/
mkdir .didtoolbox && cd .didtoolbox
wget --recursive "http://$PACKER_HTTP_ADDR/provisioning/mallory/.didtoolbox/" --no-directories --no-verbose --execute=robots=off 2>&1

elevate mkdir -p /var/www/html/static/issuer
elevate mkdir -p /var/www/html/static/verifier

elevate cp ~/Documents/didlogs/issuer/issuer_did.jsonl     /var/www/html/static/issuer/did.jsonl
elevate cp ~/Documents/didlogs/verifier/verifier_did.jsonl /var/www/html/static/verifier/did.jsonl

#############
# Mount the parallels guest tools
if [ "x$PACKER_BUILDER_TYPE" = "xparallels-iso" ]
then

	printf "\n--------\n"
	printf "Installing Parallels guest tools"
	printf "\n--------\n"

	elevate mount -o ro /tmp/parallels_guest.iso /mnt
	elevate cp -r /mnt /tmp/guest-tools
	elevate umount /mnt
	elevate /tmp/guest-tools/install --install-unattended
	elevate rm -rf /tmp/guest-tools
	# A reboot will be required, but we can continue with the provisioning for now
fi

#############
# Mount and install the vmware guest tools
if [ "x$PACKER_BUILDER_TYPE" = "xvmware-iso" ]
then
	elevate mount -o ro /tmp/vmware_tools.iso /mnt
	elevate cp -r /mnt /tmp/guest-tools
	elevate umount /mnt
	elevate /tmp/guest-tools/run_upgrader.sh
	elevate rm -rf /tmp/guest-tools
	# A reboot will be required, but we can continue with the provisioning for now
fi

