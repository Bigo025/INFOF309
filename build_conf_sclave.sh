#!/bin/bash
#-------------------------------
# script pour configurer automatiquement les machine secondaire (esclaves)
#-------------------------------

#-----------------------------------------------------------
#  partie 1: installation des dependencies necessaire
#-----------------------------------------------------------
apt-get update

cat << EOF
-----------------------------------
[INFO]:wait to installing dependencies
-----------------------------------

EOF

sleep 4

echo "[INFO]: ifenslave installation for Ethernet link aggregation"
apt-get install -y ifenslave

echo "[INFO]: ipvsadm installation for Load balancing"
apt-get install -y ipvsadm

echo "[INFO]: heartbeat installation for High availability"
apt-get install -y heartbeat

echo "[INFO]: drbd8 installation to replicate data from one disk via an Ethernet network."
apt-get install -y drbd8-utils

#--------------------------------------------------------------------
#  partie 2: Configuration des interfaces reseaux via network_conf.sh
#--------------------------------------------------------------------
cp dual_ethernet_slave.conf /etc/modprobe.d/

modprobe -v bonding mode=0 arp_interval=2000 arp_ip_target=192.168.122.2
/network_conf_slave.sh

#--------------------------------------------------------------------
#  partie 3: Configuration ARP loopback pour le Load balancing
#--------------------------------------------------------------------
clear

cat << EOF
---------------------------------------------
Configuration ARP loopback for Load balancing
---------------------------------------------

EOF

sleep 3

    echo -n "Virtual adress :"
    read $VIP
    echo -n "adress Server_1 :"
    read $RIP1
    echo -n "adress Server_2 :"
    read $RIP2

echo "
net.ipv4.conf.all.arp_ignore=1
net.ipv4.conf.all.arp_announce=2
net.ipv4.conf.lo.arp_ignore=1
net.ipv4.conf.lo.arp_announce=2" >> /etc/sysctl.conf

#Recharge de la configuration ARP
sysctl -p

echo "
## Configuration de l'adresse IP virtuelle sur loopback en mode Statique
auto lo:0
iface lo:0 inet static
address $VIP
netmask 255.255.255.255 " >> /etc/network/interfaces

## redémarrage du service...
echo "[INFO]: Restarting the service..."

/etc/init.d/networking restart

#activation de la VIP sur lo:0
ifup lo:0
