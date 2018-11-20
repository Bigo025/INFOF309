#!/bin/bash
#-------------------------------
#    script pour configurer automatiquement les machine
#-------------------------------

#-----------------------------------------------------------
#  partie 1: installation des dependencies necessaire
#-----------------------------------------------------------
apt-get update

cat << EOF
-----------------------------------
[INFO]: wait to installing dependencies
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
cp dual_ethernet.conf /etc/modprobe.d/

modprobe -v bonding mode=0 arp_interval=2000 arp_ip_target=192.168.122.1
/network_conf.sh

#--------------------------------------------------------------------
#  partie 3: Configuration du Load balancing
#--------------------------------------------------------------------
clear

cat << EOF
-----------------------------------
Configuration Load balancing
-----------------------------------

EOF

sleep 3

    echo -n "Virtual adress :"
    read $VIP
    echo -n "adress Server_1 :"
    read $RIP1
    echo -n "adress Server_2 :"
    read $RIP2

    ipvsadm -A -t $VIP:80 -s rr
    ipvsadm –a –t $VIP:80 –r $RIP1:80 –g
    ipvsadm –a –t $VIP:80 –r $RIP2:80 –g

#configuration a effectuer sur les deux serveur web

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

#sauvegarde des configuration de ipvsadm pour etre effectif lors du reboot
ipvsadm -Sn > /etc/ipvsadm_rules

#affiche les informations à propos du resume du Load balancing
ipvsadm -Ln
sleep 7


#--------------------------------------------------------------
#  partie 4: Configuration de drbd8 pour le partage du stocage
#--------------------------------------------------------------

cat << EOF
------------------------------------
configuration of data sharing stored
------------------------------------

EOF

sleep 3

drbd0.res
