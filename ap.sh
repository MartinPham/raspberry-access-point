. ./config.txt

cat <<- EOF >/etc/dhcpd-ap.conf
interface $AP
static ip_address=10.10.10.1/24
nohook wpa_supplicant
EOF

sed -i 's/interface.*#@ap//g' /etc/dhcpcd.conf
sed -i 's/static.*#@ap//g' /etc/dhcpcd.conf
sed -i 's/nohook.*#@ap//g' /etc/dhcpcd.conf

echo "Add dhcpcd rule"
cat <<EOT >> /etc/dhcpcd.conf
interface $AP #@ap
static ip_address=10.10.10.1/24 #@ap
nohook wpa_supplicant #@ap
EOT

systemctl daemon-reload
service dhcpcd restart

if test -d /etc/NetworkManager; then
	echo "Backing up NetworkManager.cfg..."
	sudo cp /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf.backup

	cat <<- EOF > /etc/NetworkManager/NetworkManager.conf
		[main]
		plugins=keyfile

		[keyfile]
		unmanaged-devices=interface-name:$AP
	EOF

	echo "Restarting NetworkManager..."
	sudo service network-manager restart
fi
sudo ifconfig $AP up

echo "Backing up /etc/dnsmasq.conf..."
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup


echo "Writing dnsmasq config file..."
echo "Creating new /etc/dnsmasq.conf..."

DHCPRANGE="10.10.10.10,10.10.10.100,3650d"

if [ $SINGLE = "true" ]; then
	echo "Single client accepted"
        DHCPRANGE="10.10.10.10,10.10.10.10,1m"
else
        echo "Multiple clients accepted"
        DHCPRANGE="10.10.10.10,10.10.10.100,3650d"
fi

cat <<- EOF >/etc/dnsmasq.conf
	# disables dnsmasq reading any other files like /etc/resolv.conf for nameservers
	no-resolv
	# Interface to bind to
	interface=$AP
	#Specify starting_range,end_range,lease_time
	dhcp-range=$DHCPRANGE

	# dns addresses to send to the clients
	server=$DNS1
	server=$DNS2
EOF

echo "Writing hostapd config file..."
cat <<- EOF >/etc/hostapd/hostapd.conf
	interface=$AP
	driver=nl80211
	ssid=$SSID
	hw_mode=g
	channel=1
	macaddr_acl=0
	auth_algs=1
	ignore_broadcast_ssid=0
	wpa=2
	wpa_passphrase=$PASSWORD
	wpa_key_mgmt=WPA-PSK
	wpa_pairwise=TKIP
	rsn_pairwise=CCMP
EOF

echo "Configuring AP interface..."
sudo ifconfig $AP up 10.10.10.1 netmask 255.255.255.0
echo "Applying iptables rules..."
sudo iptables --flush
sudo iptables --table nat --flush
sudo iptables --delete-chain
sudo iptables --table nat --delete-chain

if [ $NAT = "true" ]; then
	echo "NAT enabled"
	sudo iptables --table nat --append POSTROUTING --out-interface $CLIENT -j MASQUERADE
	sudo iptables -A FORWARD -i $CLIENT -o $AP -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -i $AP -o $CLIENT -j ACCEPT
else
	echo "NAT disabled"
fi
#sudo iptables --append FORWARD --in-interface $AP -j ACCEPT

echo "Starting DNSMASQ server..."
sudo /etc/init.d/dnsmasq stop > /dev/null 2>&1
sudo pkill dnsmasq
sudo dnsmasq

sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1

sudo ip route add 255.255.255.255 dev $AP


echo "Starting AP on $AP..."
sudo hostapd /etc/hostapd/hostapd.conf

if test -d /etc/NetworkManager; then
	sudo rm /etc/NetworkManager/NetworkManager.conf > /dev/null 2>&1
	sudo mv /etc/NetworkManager/NetworkManager.conf.backup /etc/NetworkManager/NetworkManager.conf
	sudo service network-manager restart
fi
sudo /etc/init.d/dnsmasq stop > /dev/null 2>&1
sudo pkill dnsmasq

sed -i 's/interface.*#@ap//g' /etc/dhcpcd.conf 
sed -i 's/static.*#@ap//g' /etc/dhcpcd.conf 
sed -i 's/nohook.*#@ap//g' /etc/dhcpcd.conf 
systemctl daemon-reload
service dhcpcd restart

sudo rm /etc/dnsmasq.conf > /dev/null 2>&1
sudo mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf > /dev/null 2>&1
sudo rm /etc/dnsmasq.hosts > /dev/null 2>&1
sudo iptables --flush
sudo iptables --flush -t nat
sudo iptables --delete-chain
sudo iptables --table nat --delete-chain