#!/bin/bash
# Raspberry Pi 3 Kiosk Setup with Auto-Update, SD Wear Reduction, and Pause Before Reboot
# Run as root or with sudo

# CONFIGURATION VARIABLES
WIFI_SSID="YourSSID"
WIFI_PASS="YourPassword"
WEB_URL="http://your-web-page-url"

# 1. Update system now
apt update && apt full-upgrade -y

# 2. Install minimal GUI and Chromium
apt install --no-install-recommends xserver-xorg x11-xserver-utils xinit openbox chromium-browser unclutter -y

# 3. Configure Wi-Fi auto-connect
cat <<EOF > /etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=NZ

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASS"
}
EOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
systemctl enable wpa_supplicant.service
systemctl enable dhcpcd.service

# 4. Disable screen blanking globally
echo -e "@xset s off\n@xset -dpms\n@xset s noblank" >> /etc/xdg/lxsession/LXDE/autostart

# 5. Create systemd service for kiosk mode
cat <<EOF > /etc/systemd/system/kiosk.service
[Unit]
Description=Chromium Kiosk
After=graphical.target

[Service]
User=pi
Environment=XAUTHORITY=/home/pi/.Xauthority
Environment=DISPLAY=:0
ExecStart=/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk $WEB_URL
Restart=always

[Install]
WantedBy=graphical.target
EOF

systemctl enable kiosk.service

# 6. Auto-update on reboot (OS + Chromium)
cat <<'EOF' > /etc/systemd/system/auto-update.service
[Unit]
Description=Auto Update OS and Chromium
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/apt-get update
ExecStart=/usr/bin/apt-get -y upgrade chromium-browser
ExecStart=/usr/bin/apt-get -y upgrade
ExecStart=/usr/bin/apt-get -y autoremove
ExecStart=/usr/bin/apt-get -y clean

[Install]
WantedBy=multi-user.target
EOF

systemctl enable auto-update.service

# 7. Reduce SD wear
dphys-swapfile swapoff
systemctl disable dphys-swapfile.service
echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0" >> /etc/fstab
echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,size=50m 0 0" >> /etc/fstab
systemctl disable rsyslog.service
systemctl disable logrotate.service
systemctl mask systemd-journald.service
echo "Storage=none" >> /etc/systemd/journald.conf
systemctl restart systemd-journald

# 8. Pause before reboot
echo "Setup complete. Press ENTER to reboot or CTRL+C to cancel."
read
reboot
