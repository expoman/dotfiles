gnome-screensaver &
gnome-settings-daemon &

export $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg)

xset s off

nm-applet&

sudo powertop --auto-tune

exec awesome
