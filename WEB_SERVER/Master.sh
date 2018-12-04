#!/bin/bash

read -p "do you want to installing dependencies [Y/N] :" reponse

if [ $reponse = "y" ]
  then


apt-get update

cat << EOF
----------------------------------------------------------------
[INFO]: wait to installing dependencies
----------------------------------------------------------------

EOF

echo "[INFO]: ifenslave installation for Ethernet link aggregation"
apt-get install -y apache2

echo "[INFO]: drbd8 installation to replicate data from one disk via an Ethernet network."
apt-get install -y drbd8-utils

elif [ $reponse = "n" ]

then

echo "OK Continue configuration"

fi

#--------------------------------------------------------------------
#  partie 2: Configuration des interfaces reseaux
#--------------------------------------------------------------------
clear

cat << EOF
------------------------------------------------------------------
Configuration Ethernet N1
------------------------------------------------------------------

EOF

# echo -n "Name of the Ethernet interface n1 :"
# read interface1
# echo -n "IP adress of  interface $interface1 :"
# read RIP1
# echo -n "Network adress N1:"
# read network
# echo -n "Netmask :"
# read netmask
# echo -n "Gateway :"
# read gateway
# echo -n "DNS Server :"
# read nameserver
#
#
# echo -n "Name of the Ethernet interface n2 :"
# read interface2
# echo -n "IP adress of  interface $interface2 :"
# read RIP2
# echo -n "Network adress N2:"
# read network2
# echo -n "Netmask :"
# read netmask2
# echo -n "Gateway :"
# read gateway2
# echo -n "DNS Server :"
# read nameserver2
#
# echo -n "VIP adress  :"
# read VIP
#
#
# clear
#
# ###############################
# interface1=enp0s3
# RIP1=172.16.1.4
# netmask=255.255.255.0
# gateway=172.16.1.4
# nameserver=8.8.8.8
# network=172.16.1.0
#
# interface2=enp0s8
# RIP2=172.16.10.1
# netmask2=255.255.255.0
# gateway2=172.16.10.1
# nameserver2=8.8.8.8
# network2=172.16.10.0
#
# VIP=172.16.1.1
#
# interface3=enp0s9
############################

cat << EOF
------------------------------------------------------
[INFO]:Configuration Ethernet N1
------------------------------------------------------

EOF

#configuration ARP

echo "
net.ipv4.conf.all.arp_ignore=1
net.ipv4.conf.all.arp_announce=2
net.ipv4.conf.lo.arp_ignore=1
net.ipv4.conf.lo.arp_announce=2" >> /etc/sysctl.conf

#Recharge de la configuration ARP
sysctl -p


	## Copie des paramètres dans le fichier de configuration

# echo "
# source /etc/network/interfaces.d/*
#
# ## the loopback network interface
# auto lo
# iface lo inet loopback
#
# ## Configuration de $interface1 en mode Statique
# auto $interface1
# iface $interface1 inet static
# address $RIP1
# netmask $netmask
# getway $getway
#
# ## Configuration de $interface2 en mode Statique
# auto $interface2
# iface $interface2 inet static
# address $RIP2
# netmask $netmask2
# getway $getway2
#
# auto $interface3
# iface $interface3 inet dhcp

echo "
## Configuration de l'adresse IP virtuelle sur loopback en mode Statique
auto lo:0
iface lo:0 inet static
address 127.16.1.1
netmask 255.255.255.255 " >> /etc/network/interfaces


## redémarrage du service...
echo "[INFO]: Restarting the service..."

/etc/init.d/networking restart

#activation de la VIP sur lo:0
ifup lo:0

sleep 5

cat << EOF
-------------------------------------------------------------
[OK]:CONFIGURATION NETWORK
-------------------------------------------------------------

EOF


#--------------------------------------------------------------
#  partie 4: Configuration de drbd8 pour le partage du stocage
#--------------------------------------------------------------

clear

cat << EOF
-----------------------------------------------------------------
configuration of data sharing stored
-----------------------------------------------------------------
*** VOUS DEVEZ VALITER LES ETAPE EN PARRALLELE AVEC LE SECONDAIRE ***
veillez taper sur ENTRE pour commencer :
EOF

cat << EOF
-------------------------------------------------------------
[INFO]:storage device detection
-------------------------------------------------------------
wait....

EOF

sleep 3

fdisk -l

sleep 3

read -p "[1]:saisir de donnee | ENTRE pour continue " continu

echo -n "select device (example :sdb,sdc,sda...) :"
read dev

name_s1=$(uname -n)
echo -n "Name of the secondary Node Web server (uname -n) :"
read name_s2

echo -n "password to secure the exchange (must be the same on the secondary host) :"
read password

########################
dev=xvdb
name_s1=ip-172-16-5-162
name_s2=ip-172-16-5-149
password=acme
#######################


  #si c'est le disk principale ne rien faire
  if [$dev = "xvda"]

    then

      echo " partition principal "

    else

      clear

      cat << EOF
-----------------------------------------------------------------------------
[INFO]:creating a partition on the second disks
-----------------------------------------------------------------------------
list of parameters to enter :
* command           : "n"
* Partition type    : "p"
* Partition number  : enter for defaul value
* First sector      : enter for defaul value
* Last sector       : enter for defaul value
* command           : "w"

EOF

    # création d'une partition sur le second disque
fdisk /dev/$dev

un=1
dev1=$dev$un
    #creation du fichier de configuration pour la resource
    echo "

resource r0 {
        protocol C;


        startup {
                degr-wfc-timeout 120;
                wfc-timeout 30 ;
        }

        disk {
                on-io-error detach;
        }

        net {
                cram-hmac-alg sha1;
                shared-secret $password;
                after-sb-0pri disconnect;
                after-sb-1pri disconnect;
                after-sb-2pri disconnect;
                rr-conflict disconnect;
        }

        syncer {
                rate 100M;
                verify-alg sha1;
                al-extents 257;
        }

        on $name_s1 {
                device /dev/drbd0;
                disk /dev/$dev1;
                address $RIP1:7788;
                meta-disk internal;
        }

        on $name_s2 {
                device /dev/drbd0;
                disk /dev/$dev1;
                address $RIP2:7788;
                meta-disk internal;
        }
}
    " > /etc/drbd.d/drbd0.res

    read -p "[2]:create-md r0| ENTRE pour continue " continu
    #
    drbdadm create-md r0

    read -p "[3]:activation du module drbd : ENTRE pour continue" continu
    #activation du module drbd
    modprobe drbd

    read -p "[4]:demarrage drbd : ENTRE pour continue" continu
    #demarrage de la configuration de la resource
    drbdadm up r0

    read -p "[5]:overview drbd : ENTRE pour continue" continu
    #
    drbd-overview

    read -p "[6]:synchronisation drbd : ENTRE pour continue" continu

    ##########uniquemet sur le primay#3#####################
    #on defini ce noeud comme etant le Primary (noeud master) & debut de la synchronisation
    drbdadm -- --overwrite-data-of-peer primary r0

    cat << EOF
--------------------------------------------------------
[INFO]:in 100% enter "Crlt+c" to continue configuration
-------------------------------------------------------
    wait....
EOF

    sleep 10

    #evolution de la synchronisation
    watch -n 1 cat /proc/drbd

    sleep 3

    #uniquement sur le noeud principale
    ##formater du lecteur drbd0, en ext4 :
    mkfs.ext4 /dev/drbd0

    cat << EOF
-------------------------------------------------------------
[OK]: configuration data sharing stored
-------------------------------------------------------------

EOF

fi
