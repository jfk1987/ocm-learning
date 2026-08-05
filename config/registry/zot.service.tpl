[Unit]
Description=Zot OCI registry for the air-gapped platform
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=zot
Group=zot
ExecStart=/usr/local/bin/zot serve /etc/zot/config.json
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/var/lib/zot

[Install]
WantedBy=multi-user.target
