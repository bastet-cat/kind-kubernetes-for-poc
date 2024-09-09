#!/bin/bash

# Update the package list
apt update

# Install Bind9
apt install bind9 -y

# Configure Bind9 to resolve bastet-cat.local
bash -c 'echo "zone \"bastet-cat.local\" {
    type master;
    file \"/etc/bind/db.bastet-cat.local\";
};" > /etc/bind/named.conf.local'

bash -c 'echo "$TTL 86400
@   IN  SOA ns.bastet-cat.local. admin.bastet-cat.local. (
            2022010101  ; Serial
            3600        ; Refresh
            1800        ; Retry
            604800      ; Expire
            86400       ; Minimum TTL
)
@   IN  NS  ns.bastet-cat.local.
@   IN  A   127.0.0.1" > /etc/bind/db.bastet-cat.local'

chown bind:bind /etc/bind/db.bastet-cat.local
chmod 644 /etc/bind/db.bastet-cat.local

# Restart Bind9 service
systemctl restart bind9

# Configure the machine to use Bind9 as the DNS resolver
sed -i 's/#DNS=/DNS=127.0.0.1/' /etc/systemd/resolved.conf
systemctl restart systemd-resolved.service
