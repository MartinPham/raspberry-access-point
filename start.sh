
bold=$(tput bold)
normal=$(tput sgr0)
screen_minor=`screen --version | cut -d . -f 2`
if [ $screen_minor -gt 5 ]; then
    screen_with_log="sudo screen -L -Logfile"
elif [ $screen_minor -eq 5 ]; then
    screen_with_log="sudo screen -L"
else
    screen_with_log="sudo screen -L -t"
fi
. ./config.txt

./stop.sh >/dev/null



echo "======================================================"
echo "  Starting AP in a screen"
$screen_with_log ap.log -S ap -m -d ./ap.sh
echo "======================================================"

#tail -f ./ap.log
