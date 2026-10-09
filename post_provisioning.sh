#!/bin/sh

alias elevate="echo '$USER_PASS' | sudo -S "

# So the user gets automatically logged-in
cat > /tmp/99_autologin.conf << EOF
[Seat:*]
autologin-user=lab-user
autologin-user-timeout=0
EOF

elevate mkdir -p /usr/share/lightdm/lightdm.conf.d/
elevate mv /tmp/99_autologin.conf /usr/share/lightdm/lightdm.conf.d/

# Disable sleep on inactivity (I'm not entriely sure these are the correct keys to change, tbh...)
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled                -ns 0     -t int
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-ac-off              -ns 0     -t int
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-ac-sleep            -ns 0     -t int
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-battery-off         -ns 0     -t int
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-battery-sleep       -ns 0     -t int
xfconf-query -c xfce4-terminal      -p /misc-show-unsafe-paste-dialog                   -ns false -t bool
# Disable screensaver
cat >> ~/.bashrc << EOF
# Disable screensaver
xset s 0 0
EOF

# Automatically start VSCode after login
mkdir -p ~/.config/autostart/
cat > ~/.config/autostart/vscode.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=VSCode
Comment=VSCode
Exec=code Documents/swiyu.code-workspace
StartupNotify=false
Terminal=false
Hidden=false
Categories=Utility;
EOF
elevate chmod 644 ~/.config/autostart/vscode.desktop

# A bit of housekeeping...
cd ~
rm -rf .cache \
	.dotnet \
	Downloads \
	.gnupg \
	.local \
	Music \
	Pictures \
	.pki \
	Public \
	.sudo_as_admin_successful \
	Templates \
	Videos \
	.xsession-errors

printf "

=====================
|| SETUP COMPLETED ||
=====================

[+] Credentials to log in:
	-> Username: %s
	-> Password: %s
" "$USER" "$USER_PASS"

printf "
After logging-in, you can simply execute
	\`code Documents/swiyu.code-workspace\`
then go to 'Run and debug' (CTRL+Shift+D) and you can launch the issuer and the verifier

	!!! ATTENTION !!! -> If the first lunch fails, try again. I don't know why (maybe it's pulling some dependencies or smth), but running the Issuer/Verifier always fails at first.
"

printf "
[!] --> To access the VM from the outside (i.e.: to test from your device), remember to set the network in bridged mode (i.e.: \`prlctl set eID_testlab --device-set net0 --type bridged\`, for parallels).
		If you do so, remember to check that the correct address is on /etc/bind9/zones/db.viscon.swiyu

If you're using an external device to test the wallet, you might want to set the DNS server to the VM's IP address, to resolve viscon.swiyu:

	* On Android you need to manually specify the connection details to the network (static IP address, network mask, etc.)

	* On iOS you can simply edit the nameservers directly when editing the network properties, you can let DHCP do the rest
"


if [ "x$PACKER_BUILDER_TYPE" = "xparallels-iso" ]
then
	printf "
	======================

	If you want to import the VM directly into this Parallels installation again, run
		\`prlctl register output-eID/eID_testlab.pvm/\`

	======================
	"
fi
