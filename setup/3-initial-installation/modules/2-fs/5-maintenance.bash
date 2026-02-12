## Configure trim/discard
echo ':: Scheduling trim...'
systemctl enable fstrim.timer ## Auto-trims everything in /etc/fstab
cat > /etc/systemd/system/zfstrim.service <<'EOF'
[Unit]
Description=Trim ZFS pools
After=zfs.target
[Service]
Type=oneshot
ExecStart=/usr/sbin/zpool trim -a
IOSchedulingClass=idle
EOF
cat > /etc/systemd/system/zfstrim.timer <<'EOF'
[Unit]
Description=Periodic ZFS trim
[Timer]
OnCalendar=*-*-* 03:00
Persistent=true
AccuracySec=1min
[Install]
WantedBy=timers.target
EOF
systemctl enable zfstrim.timer

## Configure scrubs
#TODO

## Configure SMART
#TODO
