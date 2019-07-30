echo "Stopping AP"
sudo screen -S ap         -X stuff '^C'

echo "" > ap.log