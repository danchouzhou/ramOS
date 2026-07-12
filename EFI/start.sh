#!/bin/bash

## User ##
USER=user
PASSWD=user
useradd -m -s /bin/bash ${USER} -G sudo
echo -e "${PASSWD}\n${PASSWD}" | passwd ${USER}

## Network ##
sed -in '/enp/d' /etc/network/interfaces
for i in $(ip link show | grep enp | cut -f2 -d' ' | sed 's/://g'); do
	echo "" >> /etc/network/interfaces
	echo "auto ${i}" >> /etc/network/interfaces
	echo "allow-hotplug ${i}" >> /etc/network/interfaces
	echo "iface ${i} inet dhcp" >> /etc/network/interfaces
done
systemctl restart networking.service

nft flush ruleset
nft add table inet my_table
nft add chain inet my_table input "{ type filter hook input priority 0 ; policy drop ; }"
nft add chain inet my_table output "{ type filter hook output priority 0 ; policy accept ; }"
nft add chain inet my_table forward "{ type filter hook forward priority 0 ; policy drop ; }"
nft add rule inet my_table input ct state invalid drop
nft add rule inet my_table input ct state established,related accept
nft add rule inet my_table input iifname "lo" accept
