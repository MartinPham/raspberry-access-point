. ./config.txt

WLAN0=$(cat /sys/class/net/wlan0/address)
WLAN1=$(cat /sys/class/net/wlan1/address)

echo "source $SOURCE"
echo "wlan0 $WLAN0"
echo "wlan1 $WLAN1"

if [ "$WLAN1" = "$SOURCE" ]; then
	echo "wlan1 as source"
	WLAN=wlan0
	ETH=wlan1
else
	echo "wlan0 as source"
	echo ""
	WLAN=wlan1
	ETH=wlan0
fi

echo "wlan -> $WLAN"
echo "eth -> $ETH"



if test -d /etc/NetworkManager; then
	echo "Backing up NetworkManager.cfg..."
	sudo cp /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf.backup

	cat <<- EOF > /etc/NetworkManager/NetworkManager.conf
		[main]
		plugins=keyfile

		[keyfile]
		unmanaged-devices=interface-name:$WLAN
	EOF

	echo "Restarting NetworkManager..."
	sudo service network-manager restart
fi
sudo ifconfig $WLAN up

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
	interface=$WLAN
	#Specify starting_range,end_range,lease_time
	dhcp-range=$DHCPRANGE

	# dns addresses to send to the clients
	server=$DNS1
	server=$DNS2
EOF

echo "Writing hostapd config file..."
cat <<- EOF >/etc/hostapd/hostapd.conf
	interface=$WLAN
	driver=nl80211
	ssid=$AP
	hw_mode=g
	channel=1
	macaddr_acl=0
	auth_algs=1
	ignore_broadcast_ssid=0
	wpa=2
	wpa_passphrase=$PASSWD
	wpa_key_mgmt=WPA-PSK
	wpa_pairwise=TKIP
	rsn_pairwise=CCMP
EOF

echo "Configuring AP interface..."
sudo ifconfig $WLAN up 10.10.10.1 netmask 255.255.255.0
echo "Applying iptables rules..."
sudo iptables --flush
sudo iptables --table nat --flush
sudo iptables --delete-chain
sudo iptables --table nat --delete-chain

if [ $NAT = "true" ]; then
	echo "NAT enabled"
	sudo iptables --table nat --append POSTROUTING --out-interface $ETH -j MASQUERADE
else
	echo "NAT disabled"
fi
sudo iptables --append FORWARD --in-interface $WLAN -j ACCEPT

echo "Starting DNSMASQ server..."
sudo /etc/init.d/dnsmasq stop > /dev/null 2>&1
sudo pkill dnsmasq
sudo dnsmasq

sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1

sudo ip route add 255.255.255.255 dev $WLAN


echo "Starting AP on $WLAN in screen terminal..."
sudo hostapd /etc/hostapd/hostapd.conf

if test -d /etc/NetworkManager; then
	sudo rm /etc/NetworkManager/NetworkManager.conf > /dev/null 2>&1
	sudo mv /etc/NetworkManager/NetworkManager.conf.backup /etc/NetworkManager/NetworkManager.conf
	sudo service network-manager restart
fi
sudo /etc/init.d/dnsmasq stop > /dev/null 2>&1
sudo pkill dnsmasq
sudo rm /etc/dnsmasq.conf > /dev/null 2>&1
sudo mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf > /dev/null 2>&1
sudo rm /etc/dnsmasq.hosts > /dev/null 2>&1
sudo iptables --flush
sudo iptables --flush -t nat
sudo iptables --delete-chain
sudo iptables --table nat --delete-chain
