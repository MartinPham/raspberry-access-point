. ./config.txt

WLAN0=$(cat /sys/class/net/wlan0/address)
WLAN1=$(cat /sys/class/net/wlan1/address)

echo "source $SOURCE"
echo "wlan0 $WLAN0"
echo "wlan1 $WLAN1"

if [ "$WLAN1" == "$SOURCE" ]
then
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
