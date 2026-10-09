#!/bin/sh

alias elevate="echo '$ELEVATE_PASS' | sudo -S "

get_prov_file()
{
	local path="$1"
	local output="$2"

	curl -s "http://$PACKER_HTTP_ADDR/provisioning/bind9/$path" -o "$output"
}

get_prov_file_sudo()
{
	get_prov_file "$1" /tmp/tmp_file
	elevate mv /tmp/tmp_file "$2"
}

printf "\n===============================\n"
printf "DNS SERVER SETUP"
printf "\n===============================\n"

get_prov_file_sudo named.conf.local /etc/bind/named.conf.local
get_prov_file_sudo named.conf.options /etc/bind/named.conf.options

get_prov_file zones/db.viscon.swiyu /tmp/db.viscon.swiyu
get_prov_file zones/db.mallory.swiyu /tmp/db.mallory.swiyu

ip_addr="$(ip -4 -br addr show | grep '\sUP\s' | awk '{ print $3 }' | cut -d/ -f1)"

printf "[+] viscon.swiyu will resolve to %s\n" "$ip_addr"
sed -i "s-{{REPLACE_ME}}-$ip_addr-g" /tmp/db.viscon.swiyu

printf "[+] mallory.swiyu will resolve to %s\n" "$ip_addr"
sed -i "s-{{REPLACE_ME}}-$ip_addr-g" /tmp/db.mallory.swiyu

elevate mkdir -p /etc/bind/zones
elevate cp /tmp/db.viscon.swiyu /etc/bind/zones/db.viscon.swiyu
elevate cp /tmp/db.mallory.swiyu /etc/bind/zones/db.mallory.swiyu

# No need to restart the server, the configuration will be reloaded when the user boots up the VM