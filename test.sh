#!/bin/bash
###################################################
#######          iIot online store          #######
###################################################
####### Stretch Linaro                      #######
####### Raspberry Pi 3 Plex Media Server    #######
####### Netgear Package                     #######
####### Kevern Upton - 01  Nov  2017        #######
###################################################
calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error 
  # output from tput. However in this case, tput detects neither stdout or 
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}
do_finish() {


  exit 0

}
do_exit() {

  exit 0

}
do_raspi_config(){
sudo raspi-config
}
do_reboot() {

sudo reboot
 exit 0

}
reboot_message(){
whiptail --msgbox "\
Changes sucessfully completed!

Your Raspberry Pi now needs to be rebooted
for the configuration to take effect.

Please select OK to return to the main menu
then select Exit & Reboot to reboot.
\
" 20 70 1
}
change_plex_media_server_version(){
echo "Setting temporary variables and asigning values."
PMS_LIB_DIR=/usr/lib/plexmediaserver
PMS_DOWNLOAD_DIR=/tmp/plex_tmp_download
echo "Creating directories."
#create dirs
mkdir -p $PMS_DOWNLOAD_DIR
mkdir -p $PMS_LIB_DIR
echo "Input new plex debian package download shortcut"
echo "for example;"
echo "https://downloads.plex.tv/plex-media-server/1.3.3.3148-b38628e/plexmediaserver-ros6-binaries-annapurna_1.3.3.3148-b38628e_armel.deb"
echo "to get this link goto http://www.plex.tv, click on downloads link, click on download plex media server."
echo "Click the drop down and select Netgear, click the download button, left click ARM 6.x RN2xx, click copy link."
echo "Paste the copied link here then press enter."
read PMS_URL

	echo "Downloading Plex.tv package ..."
	cd $PMS_DOWNLOAD_DIR
	curl --progress-bar -o plex.deb $PMS_URL

	local PMS_DOWNLOAD_HASH=`sha256sum plex.deb | cut -d' ' -f1`
        local PMS_HASH=`sha256sum plex.deb | cut -d' ' -f1`
	
	if [ "$PMS_HASH" != "$PMS_DOWNLOAD_HASH" ]
	then
		echo "Checksum mismatch. Downloaded file does not match this package."
		exit 1
	else
		echo "Passed checksum test."
	fi
	echo "Extracting Plex.tv package ..."
	ar p plex.deb data.tar.gz | tar -xzf - -C $PMS_LIB_DIR/ --strip-components=4 ./apps/plexmediaserver-annapurna/Binaries
	#if ar command does not work install bin utilities using apt-get install binutils
	# remove not unused files and temp directory
	rm $PMS_LIB_DIR/config.xml
        rm -r $PMS_DOWNLOAD_DIR/
	#chown plex -R /usr/lib/plexmediaserver
        reboot_message
}
install_dnsmasq() {
echo "Checking for installed packages..."
CHECK_DNSMASQ_PACKAGE=$(dpkg -l | awk '{print $2}' | grep dnsmasq)
 if [[ "$CHECK_DNSMASQ_PACKAGE" != "" ]]
then
echo  $CHECK_DNSMASQ_PACKAGE "packages already installed."
 fi
 if [[ "$CHECK_DNSMASQ_PACKAGE" = "" ]]
then
echo "Installing dnsmasq packages..."
sudo apt-get -yqq install dnsmasq-base dnsmasq --install-suggests --force-yes
 fi
}
install_hostapd() {
echo "Checking for installed packages..."
CHECK_HOSTAPD_PACKAGE=$(dpkg -l | awk '{print $2}' | grep hostapd)
 if [[ "$CHECK_HOSTAPD_PACKAGE" != "" ]]
then
echo  $CHECK_HOSTAPD_PACKAGE "packages already installed."
fi
 if [[ "$CHECK_HOSTAPD_PACKAGE" = "" ]]
then
echo "Installing hostapd packages..."
sudo apt-get -yqq install hostapd --install-suggests --force-yes
 fi
}
do_wireless_ap(){
install_dnsmasq
install_hostapd
echo "checking for existing installation..."
EXISTING_AP_INSTALL=$(grep "hostapd" /etc/network/interfaces)
 if [[ "$EXISTING_AP_INSTALL" != "" ]]
then
echo "This is not the first time this has been run..."
echo "SSID and Password will only be changed, please reboot your device when completed."
echo -e "Your password must be a minimum of 8 and max 63 characters."
echo -e  "Enter your password?"
read APPASS
echo -e "Enter your SSID"
read APSSID
OLD_APSSID='ssid'
#NEW_APSSID='ssid="'"$APSSID"'"'
NEW_APSSID='ssid='"$APSSID"
OLD_APPASS='wpa_passphrase'
#NEW_APPASS='wpa_passphrase="'"$APPASS"'"'
NEW_APPASS='wpa_passphrase='"$APPASS"
echo "New SSID set to:"$NEW_APSSID
echo "New Passphrase set to:"$NEW_APPASS
sudo sed -i '/'"$OLD_APSSID*"'/ c\'"$NEW_APSSID"''   /etc/hostapd/hostapd.conf
sudo sed -i '/'"$OLD_APPASS*"'/ c\'"$NEW_APPASS"''   /etc/hostapd/hostapd.conf
sudo systemctl daemon-reload
sudo service hostapd restart
sudo service networking restart
reboot_message
fi
 if [[ "$EXISTING_AP_INSTALL" = "" ]]
then
echo "This is the first time this has been run..."
echo "SSID, Password, Wireless IPv4 IP, DHCP, DNS servers" 
echo "and host access point daemon will be installed and configured."
echo -e "Your AP SSID password must be a minimum of 8 and max 63 characters."
echo -e "NB!! If you do not make this password long enough host access point services"
echo "will not start!!!!."
echo "Please enter your password?"
read APPASS
echo -e "Please enter your SSID?"
read APSSID
echo -e "Please enter the fixed IPv4 address for your wireless AP."
echo -e "For example 10.0.0.1"
echo -e "Please enter a IP address?"
read IP_ADDRESS
echo -e "Please enter a DHCP start and finish IP address seperated by a comma."
echo -e "For example 10.0.0.2,10.0.0.100"
echo -e "in the example above there will be 98 available IP addresses."
echo -e "Please enter the DHCP IPv4 scope or range?"
read DHCP_RANGE
echo -e "Checking and installing packages..."
install_dnsmasq
install_hostapd
DNSMASQ_CHECK_2=$(ls /etc/init.d/dnsmasq)
if [[ "$DNSMASQ_CHECK_2" = "" ]]
then
sudo apt-get -yqq install dnsmasq
fi
sudo cat > /etc/dnsmasq.conf <<DNS_EOF
interface=wlan0
dhcp-range=$DHCP_RANGE,255.255.255.0,24h
DNS_EOF
cd /etc/init.d && sudo /usr/sbin/update-rc.d dnsmasq defaults
sudo cat > /etc/hostapd/hostapd.conf <<HOSTAPD_EOF
interface=wlan0
hw_mode=g
channel=6
ieee80211n=1
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=$APPASS
ssid=$APSSID
HOSTAPD_EOF
#sudo cat > /etc/network/interfaces <<INTERFACES_EOF
#source-directory /etc/network/interfaces.d

#auto lo
#iface lo inet loopback

#iface eth0 inet manual

#allow-hotplug wlan0
#iface wlan0 inet manual
    #wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

#allow-hotplug wlan1
#iface wlan1 inet manual
   # wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
#auto wlan0
sudo cat <<EOT >> /etc/network/interfaces
iface wlan0 inet static
        address $IP_ADDRESS
        netmask 255.255.255.0
        pre-up ifconfig wlan0
        hostapd /etc/hostapd/hostapd.conf
EOT
#INTERFACES_EOF
OLD11='iface wlan0 inet manual'
NEW11='#iface wlan0 inet manual'
OLD12='wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf'
NEW12='#wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf'
sudo sed -i 's,'"$OLD11"','"$NEW11"',g' /etc/network/interfaces
sudo sed -i 's,'"$OLD12"','"$NEW12"',g' /etc/network/interfaces
echo "All done!"
reboot_message
 fi
}
do_wireless_client(){
echo -e  "Enter the SSID you wish to join?"
read YOUR_SSID
echo -e "Set your AP key management to WPA-PSK and enter your password or key?"
read YOUR_PASSWORD
sudo /usr/sbin/update-rc.d -f hostapd remove
sudo rm -rf /etc/hostapd/hostapd.conf
sudo rm -rf /etc/dnsmasq.conf
echo -e "Setting up WPA Supplicant config using WPA-Personal(PSK)"
sudo cat > /etc/wpa_supplicant/wpa_supplicant.conf <<WPA_EOF
network={
	ssid="$YOUR_SSID"
        psk="$YOUR_PASSWORD"
        key_mgmt=WPA-PSK
}
WPA_EOF
echo "All done!"
reboot_message
}
do_static_eth0(){
echo -e "Please enter the fixed IPv4 address for your ethernet LAN."
echo -e "For example 192.168.4.3"
read IP_ADDRESS
echo -e "Please enter a subnet mask for your ethernet LAN."
echo -e "For example 255.255.255.0"
read IP_NETMASK
echo -e "Please enter a gateway address for your ethernet LAN."
echo -e "For example 192.168.4.1"
read IP_GATEWAY
echo -e "Please enter a DNS address for your ethernet LAN."
echo -e "For example 8.8.8.8"
read IP_DNS
OLD41='iface eth0 inet manual'
NEW41='#iface eth0 inet manual'
sudo sed -i 's,'"$OLD41"','"$NEW41"',g' /etc/network/interfaces
sudo cat <<EOT >> /etc/network/interfaces
auto eth0
iface eth0 inet static
        address $IP_ADDRESS
        netmask $IP_NETMASK
        gateway $IP_GATEWAY
        pre-up ifconfig eth0

EOT
RESOLVCONF_CHECK_1=$(ls /etc/resolvconf/resolv.conf.d/head)
if [[ "$RESOLVCONF_CHECK_1" = "" ]]
then
apt-get install resolvconf -yqq 
fi
sudo cat <<EOT_DNS >> /etc/resolvconf/resolv.conf.d/head
nameserver $IP_DNS

EOT_DNS
sudo /sbin/resolvconf -u
echo "All done!"
reboot_message
}
do_ethernet_server(){
install_dnsmasq
DNSMASQ_CHECK_2=$(ls /etc/init.d/dnsmasq)
 if [[ "$DNSMASQ_CHECK_2" = "" ]]
then
sudo apt-get -yqq install dnsmasq
 fi
DNSMASQ_CHECK_2=$(ls /etc/init.d/dnsmasq)
 if [[ "$DNSMASQ_CHECK_2" != "" ]]
then
echo -e "Please enter the fixed IPv4 address for your ethernet LAN."
echo -e "For example 192.168.4.1"
echo -e "Please enter a IP address?"
read IP_ADDRESS
echo -e "Please enter a DHCP start and finish IP address seperated by a comma."
echo -e "For example 192.168.4.2,192.168.4.100"
echo -e "in the example above there will be 98 available IP addresses."
echo -e "Please enter the DHCP IPv4 scope or range?"
read DHCP_RANGE
sudo cat <<EOT >> /etc/dnsmasq.conf
interface=eth0
dhcp-range=$DHCP_RANGE,255.255.255.0,24h
EOT
sudo cat <<EOT >> /etc/network/interfaces
auto eth0
iface eth0 inet static
        address $IP_ADDRESS
        netmask 255.255.255.0
        pre-up ifconfig eth0

EOT
OLD31='iface eth0 inet manual'
NEW31='#iface eth0 inet manual'
sudo sed -i 's,'"$OLD31"','"$NEW31"',g' /etc/network/interfaces
echo "All done!"
fi
reboot_message
}
install_enhanced_networking(){
CRON_ROOT_CHECK=$(ls /var/spool/cron/root)
 if [[ "$CRON_ROOT_CHECK" = "" ]]
then
sudo touch /var/spool/cron/root
sudo chown root:root /var/spool/cron/root
 fi
#Check for and remove enhance setting in crontab of root
CHECK_ENHANCED=$(crontab -u root -l | grep '@reboot sudo /etc/enhance_network.sh')
 if [[ "$CHECK_ENHANCED" != "" ]]
then
LINE0='@reboot sudo /etc/enhance_network.sh'
crontab -u root -l | grep -v "$LINE0"  | crontab -u root -
 fi
#Add IPv4 forwarding and masquerading
IPV4_FORWARDING_0=$(crontab -u root -l | grep '#@reboot sudo echo 1 > /proc/sys/net/ipv4/ip_forward')
 if [[ "$IPV4_FORWARDING_0" != "" ]]
then
LINE_0='#@reboot sudo echo 1 > /proc/sys/net/ipv4/ip_forward'
crontab -u root -l | grep -v "$LINE_0"  | crontab -u root -
fi
IPV4_FORWARDING_1=$(crontab -u root -l | grep '@reboot sudo echo 1 > /proc/sys/net/ipv4/ip_forward')
 if [[ "$IPV4_FORWARDING_1" = "" ]]
then
LINE_1='@reboot sudo echo 1 > /proc/sys/net/ipv4/ip_forward'
(crontab -u root -l; echo $LINE_1 ) | crontab -u root -
 fi
MASQ_CHECK_0=$(crontab -u root -l | grep '#@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE')
 if [[ "$MASQ_CHECK_0" != "" ]]
then
LINE_2='#@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE'
crontab -u root -l | grep -v "$LINE_2"  | crontab -u root -
fi
MASQ_CHECK_1=$(crontab -u root -l | grep '@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE')
 if [[ "$MASQ_CHECK_1" = "" ]]
then
LINE_3='@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE'
(crontab -u root -l; echo $LINE_3) | crontab -u root -
 fi
MASQ_CHECK_2=$(crontab -u root -l | grep '@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE')
 if [[ "$MASQ_CHECK_2" != "" ]]
then
crontab -u root -l | grep -v "$MASQ_CHECK_2"  | crontab -u root -
 fi
}
do_masq_eth0(){
install_enhanced_networking
MASQ_CHECK_3=$(crontab -u root -l | grep '@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE')
if [[ "$MASQ_CHECK_3" = "" ]]
then
(crontab -u root -l; echo $MASQ_CHECK_3) | crontab -u root -
 fi
echo "All done!.."
reboot_message
}
do_masq_wlan0(){
install_enhanced_networking
LINE3='@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE'
LINE4='@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE'
crontab -u root -l | grep -v "$LINE3"  | crontab -u root -
(crontab -u root -l; echo $LINE4) | crontab -u root -
echo "All done!.."
reboot_message
}
do_about() {
  whiptail --msgbox "\
This tool provides a straight-forward way of doing storage and 
network configuration of the Raspberry Pi 3. Although it can be run
at any time, some of the options may have difficulties if
you have heavily customised your installation.

The tool was built for a Raspberry Pi 3 Model B SBC.

Wireless adapter can be configured in access point or
client configuration. The onboard ethernet adapter can 
be configured in dhcp or configured with a static 
IPv4 address and provide a dhcp service. 
USB drives and shares should rather be configured through Open Media Vault interface. \
" 20 70 1
}
do_restore(){
echo "Stopping services..."
sudo service dnsmasq stop
sudo service hostapd stop
echo "Removing autostart of DNS and DHCP services..."
cd /etc/init.d && sudo /usr/sbin/update-rc.d -f dnsmasq remove
echo "Backing up old configuration files int.., dns.., hos..." 
sudo cp /etc/network/interfaces /etc/network/int.$RANDOM
sudo cp /etc/dnsmasq.conf /etc/dns.$RANDOM
sudo cp /etc/hostapd/hostapd.conf /etc/hos.$RANDOM
echo "Deleting configuration files..." 
sudo rm -rf /etc/network/interfaces
sudo rm -rf /etc/dnsmasq.conf
sudo rm -rf /etc/hostapd/hostapd.conf
touch /etc/dnsmasq.conf
touch /etc/hostapd/hostapd.conf
echo "Rebuilding original /etc/network/interfaces file..."
sudo cat > /etc/network/interfaces <<'INTERFACES_EOF'
# interfaces(5) file used by ifup(8) and ifdown(8)

# Please note that this file is written to be used with dhcpcd
# For static IP, consult /etc/dhcpcd.conf and 'man dhcpcd.conf'

# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

iface eth0 inet manual

allow-hotplug wlan0
iface wlan0 inet manual
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

allow-hotplug wlan1
iface wlan1 inet manual
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

INTERFACES_EOF

RESOLVCONF_CHECK_2=$(ls /etc/resolvconf/resolv.conf.d/head)
if [[ "$RESOLVCONF_CHECK_2" != "" ]]
then
sudo cat > /etc/resolvconf/resolv.conf.d/head <<'RESOLVCONF_HEAD' 
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN

RESOLVCONF_HEAD
fi
rm -rf /etc/wpa_supplicant/wpa_supplicant.conf
touch /etc/wpa_supplicant/wpa_supplicant.conf
#Check for and remove enhance setting in crontab of root
CHECK_ENHANCED=$(crontab -u root -l | grep '@reboot sudo /etc/enhance_network.sh')
 if [[ "$CHECK_ENHANCED" != "" ]]
then
LINE0='@reboot sudo /etc/enhance_network.sh'
crontab -u root -l | grep -v "$LINE0"  | crontab -u root -
 fi
IPV4_FORWARDING_0=$(crontab -u root -l | grep '#@reboot sudo echo 1 > /proc/sys/net/ipv4/ip_forward')
 if [[ "$IPV4_FORWARDING_0" != "" ]]
then
LINE_1='#@reboot sudo echo 1 > /proc/sys/net/ipv4/ip_forward'
crontab -u root -l | grep -v "$LINE_1"  | crontab -u root -
fi
IPV4_FORWARDING_1=$(crontab -u root -l | grep '@reboot sudo echo 1 > /proc/sys/net/ipv4/ip_forward')
 if [[ "$IPV4_FORWARDING_1" != "" ]]
then
LINE_2='@reboot sudo echo 1 > /proc/sys/net/ipv4/ip_forward'
crontab -u root -l | grep -v "$LINE_2" | crontab -u root -
 fi
MASQ_CHECK_0=$(crontab -u root -l | grep '#@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE')
 if [[ "$MASQ_CHECK_0" != "" ]]
then
LINE_3='#@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE'
crontab -u root -l | grep -v "$LINE_3"  | crontab -u root -
fi
MASQ_CHECK_1=$(crontab -u root -l | grep '@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE')
 if [[ "$MASQ_CHECK_1" != "" ]]
then
LINE_4='@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE'
crontab -u root -l | grep -v "$LINE_4"  | crontab -u root -
 fi
MASQ_CHECK_2=$(crontab -u root -l | grep '@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE')
 if [[ "$MASQ_CHECK_2" != "" ]]
then
crontab -u root -l | grep -v "$MASQ_CHECK_2"  | crontab -u root -
 fi
MASQ_CHECK_3=$(crontab -u root -l | grep '#@reboot sudo /sbin/iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE')
 if [[ "$MASQ_CHECK_3" != "" ]]
then
crontab -u root -l | grep -v "$MASQ_CHECK_3"  | crontab -u root -
 fi
whiptail --msgbox "\
The original default Network configuration
has been restored!

Your Raspberry Pi now needs to be rebooted
for the configuration to take effect.
Please select OK to return to the main menu 
then select finish to reboot. 
\
" 20 70 1
}
mount_usb_a_drive_ntfs(){
NTFS_PACKAGE=ntfs-3g
echo "Checking for attached drives..."
USB_A_DRIVE=$(sudo fdisk -l | grep sda | grep sda1 | grep NTFS | awk '{print $1}')
USB_B_DRIVE=$(sudo fdisk -l | grep sdb | grep sdb1 | grep NTFS | awk '{print $1}')
echo "Found the following USB drives:" $USB_A_DRIVE "and" $USB_B_DRIVE
echo "Checking for installed packages..."
NTFS_3G_PACKAGE=$(sudo apt list ntfs-3g &> /dev/null)
if [[ "$NTFS_3G_PACKAGE" = "" ]]
then
sudo apt-get install ntfs-3g -y
fi
if [[ "$USB_A_DRIVE" != "" ]]
then
echo "Found USB drive A, checking for existing congigurations..."
USB_A_DRIVE_FSTAB=$(sudo cat /etc/fstab | grep $USB_A_DRIVE | awk '{print $1}')
if [[ "$USB_A_DRIVE_FSTAB" = "" ]]
then
cp /etc/fstab /etc/fstab.$RANDOM
echo "Enter a folder name for your drive..."
read MOUNT_NAME_A
sudo mkdir -p /$MOUNT_NAME_A && sudo chown root:root /$MOUNT_NAME_A
sudo echo $USB_A_DRIVE   /$MOUNT_NAME_A   $NTFS_PACKAGE "   defaults   0    0" >> /etc/fstab
MOUNT_TEST=$(sudo mount -a)
if [[ "$MOUNT_TEST" != "" ]]
then
echo "Mounting failed backing out changes..."
sudo cat /etc/fstab | grep -v "$USB_A_DRIVE" > /etc/clean.fstab
sudo rm -rf /etc/fstab && sudo mv /etc/clean.fstab /etc/fstab && sudo chown root:root /etc/fstab
exit
fi
echo "Mounting suceeded exit and reboot..."
reboot_message
fi
echo "All done!..."
fi
if [[ "$USB_A_DRIVE" = "" && "$USB_B_DRIVE" != "" ]]
then
echo "There is no USB first drive, trying USB second drive option..."
mount_usb_b_drive_ntfs
fi
echo "There are no USB drives to configure or a configration already exists...."
echo "All done!..."
}
mount_usb_b_drive_ntfs(){
USB_A_DRIVE=$(sudo fdisk -l | grep sda | grep sda1 | grep NTFS | awk '{print $1}')
USB_B_DRIVE=$(sudo fdisk -l | grep sdb | grep sdb1 | grep NTFS | awk '{print $1}')
if [[ "$USB_B_DRIVE" != "" ]]
then
echo "Found USB drive B, checking for existing congigurations..."
USB_B_DRIVE_FSTAB=$(sudo cat /etc/fstab | grep $USB_B_DRIVE | awk '{print $1}')
if [[ "$USB_B_DRIVE_FSTAB" = "" ]]
then
cp /etc/fstab /etc/fstab.$RANDOM
echo "Enter a folder name for your drive..."
read MOUNT_NAME_B
sudo mkdir -p /$MOUNT_NAME_B && sudo chown root:root /$MOUNT_NAME_B
sudo echo $USB_B_DRIVE   /$MOUNT_NAME_B   $NTFS_PACKAGE "   defaults   0    0" >> /etc/fstab
MOUNT_TEST=$(mount -a)
if [[ "$MOUNT_TEST" != "" ]]
then
echo "Mounting failed backing out changes..."
sudo cat /etc/fstab | grep -v "$USB_B_DRIVE" > /etc/clean.fstab
sudo rm -rf /etc/fstab && sudo mv /etc/clean.fstab /etc/fstab && sudo chown root:root /etc/fstab
exit
fi
echo "Mounting suceeded..."
reboot_message
fi
echo "All done!..."
fi
}
mount_shares(){
CIFS_PACKAGE=cifs
echo "Here you need to enter the share credentials and details"
echo "To access the share, CIFS, NAS or windows share you have already setup."
echo ""
echo "Enter your share username."
read USER_NAME
echo "Enter your share password."
read USER_PASSWORD
echo "Enter a local folder name you would like to use to mount your share e.g. my_share."
read MOUNT_FOLDER_NAME
echo "Enter your path to your share for example //192.168.2.10/movies"
read SHARE_FOLDER_NAME
echo "Checking for installed packages..."
CHECK_CIFS_PACKAGE=$(sudo apt list $CIFS_PACKAGE &> /dev/null)
if [[ "$CHECK_CIFS_PACKAGE" = "" ]]
then
apt-get install cifs -y
fi
CHECK_FSTAB_CONFIG=$(sudo cat /etc/fstab | grep $SHARE_FOLDER_NAME | awk '{print $1}')
echo "Checking for existing configuration with this share..."
if [[ "$CHECK_FSTAB_CONFIG" = "" ]]
then
sudo mkdir -p /$MOUNT_FOLDER_NAME
sudo echo $SHARE_FOLDER_NAME /$MOUNT_FOLDER_NAME "cifs credentials=/home/pi/credentials,iocharset=utf8,gid=0,uid=0,file_mode=0777,dir_mode=0777  0  0" >> /etc/fstab
sudo touch /home/pi/credentials
sudo echo "username="$USER_NAME >> /home/pi/credentials
sudo echo "password="$USER_PASSWORD >> /home/pi/credentials
MOUNT_CHECK=$(mount -a)
if [[ "$MOUNT_CHECK" != "" ]]
then
echo "Mounting failed backing out changes..."
sudo rm -rf /home/pi/credentials
sudo rm -rf /$MOUNT_FOLDER_NAME
sudo cat /etc/fstab | grep -v "$SHARE_FOLDER_NAME" > /etc/cleanShare.fstab
sudo rm -rf /etc/fstab && sudo mv /etc/cleanShare.fstab /etc/fstab && sudo chown root:root /etc/fstab
fi
echo "Mounting succeeded.."
reboot_message
fi
}
do_media_configuration_menu(){
 FUN=$(whiptail --title "Raspberry Pi Media Configuration Tool (media-config)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "A1 USB Drives (NTFS)" "Mount ntfs usb drives and make it persistent." \
    "A2 Shared Drives" "Mount NAS, CIFS or Windows Shares." \
    "A3 Exit" "Return to main menu without rebooting." \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      A1\ *) mount_usb_a_drive_ntfs ;;
      A2\ *) mount_shares ;;
      A3\ *) echo ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
fi
}
do_network_configuration_menu(){
 FUN=$(whiptail --title "Raspberry Pi Network Configuration Tool (network-config)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "B1 Install Wireless AP" "Setup Raspberry Pi onboard Wi-Fi as wireless hotspot." \
    "B2 Install Wireless client" "Connect Raspberry Pi to existing network (WPA-PSK)." \
    "B3 Set static LAN IP" "Setup a static Ethernet IPv4 address." \
    "B4 Install DNS/DHCP Server" "Setup Raspberry Pi as DNS and DHCP server (Ethernet)." \
    "B5 IP Forward & Masquerade (Ethernet)" "When onboard ethernet adapter is connected to internet." \
    "B6 IP Forward & Masquerade (Wi-Fi)" "When onboard wireless adapter is connected to internet." \
    "B7 Restore Network Config" "Restores the original default raspbian os network configurations." \
    "B8 Exit" "Return to main menu without rebooting." \
     3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      B1\ *) do_wireless_ap ;;
      B2\ *) do_wireless_client ;;
      B3\ *) do_static_eth0 ;;
      B4\ *) do_ethernet_server ;;
      B5\ *) do_masq_eth0 ;;
      B6\ *) do_masq_wlan0 ;;
      B7\ *) do_restore ;;
      B8\ *) echo ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
fi
}
# Interactive use loop
#
calc_wt_size
while true; do
  FUN=$(whiptail --title "www.iIot.co.za - www.aseasyaspi.co.za Main Menu" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "1 Network Configuration" "Configure network options." \
    "2 Media Configuration" "Add drives and shares etc."\
    "3 Plex Configuration" "Upgrade or change PMS version." \
    "4 Raspi Config" "Run Raspi-Config Menu." \
    "5 Exit" "Exit this menu without rebooting." \
    "6 Exit & Reboot" "Exit and reboot your Raspberry Pi." \
    "7 About" "About this configuration tool." \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) do_network_configuration_menu ;;
      2\ *) do_media_configuration_menu ;;
      3\ *) change_plex_media_server_version ;;
      4\ *) do_raspi_config ;;
      5\ *) do_exit ;;
      6\ *) do_reboot ;;
      7\ *) do_about ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  else
    exit 1
  fi
done