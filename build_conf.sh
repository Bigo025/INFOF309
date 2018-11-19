#!/bin/bash
#-------------------------------
#    script pour configurer automatiquement les machine
#-------------------------------

echo "first test"
apt-get update

echo "[INFO]: installing dependencies"

echo "[INFO]: ifenslave installation for Ethernet link aggregation"
apt-get install -y ifenslave

echo "[INFO]: ipvsadm installation for Load balancing"
apt-get install -y ipvsadm

echo "[INFO]: heartbeat installation for High availability"
apt-get install -y heartbeat


cp dual_ethernet.conf /etc/modprobe.d/

modprobe -v bonding mode=0 arp_interval=2000 arp_ip_target=192.168.122.1
/network_conf.sh

cat << EOF
-----------------------------------
Configuration Load balancing
-----------------------------------

EOF
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
###############################################################
                                                              #
                                                              #

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
                                                              #
                                                              #
###############################################################

ipvsadm -Ln
sleep 7
