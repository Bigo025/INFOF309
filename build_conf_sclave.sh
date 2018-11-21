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
clear

cat << EOF
-------------------------------------
Configuration Ethernet N1
-------------------------------------

EOF

echo -n "Name of the Ethernet interface n1 :"
read interface1
echo -n "Name of the Ethernet interface n2 :"
read interface2
echo -n "Name of the Ethernet interface virtual (dualeth0) :"
#nterface_v=dualeth0
read interface_v
echo -n "IP adress of  interface :"
read RIP1
echo -n "Netmask :"
read netmask
echo -n "Gateway :"
read gateway
echo -n "DNS Server :"
read nameserver
echo -n "IP adress of  Master server :"
read RIP2
echo -n "VIP(Virtual IP) adress of virtual interface :"
read VIP

clear
cat << EOF
-----------------------------------
Configuration Ethernet N2
-----------------------------------

EOF
    echo -n "Name of the Ethernet interface n3"
    read interface3
    echo -n "IP adress:"
    read RIP3
    echo -n "Netmask:"
    read netmask3
    echo -n "Gateway:"
    read gateway3

#creation du fichier de configuration du bonding

echo "
alias $interface_v dual_ethernet
options dual_ethernet mode=0 arp_interval=2000 arp_ip_target=$RIP1

" > /etc/modprobe.d/dual_ethernet.conf

#execusion de la commande, Si jamais le pilote n’est pas chargé automatiquement
modprobe -v bonding mode=0 arp_interval=2000 arp_ip_target=$RIP1

#creation d'un tableau pour mieux ramger les donnee saisi par le user
tab=('$interface1' '$interface2' '$interface_v' '$RIP1' '$netmask' '$gateway' '$nameserver' '$VIP' '$interface3' '$RIP3' 'netmask3' 'gateway3')

/network_conf_slave.sh "${tab[*]}"


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

cat << EOF
--------------------------------
[OK]:CONFIGURATION NETWORK
--------------------------------
Dans cette partie les deux serveur ddoivent etres synchone

taper "ENTRE" pour continuer
EOF

read continu



#--------------------------------------------------------------
#  partie 4: Configuration de drbd8 pour le partage du stocage
#--------------------------------------------------------------

cat << EOF
------------------------------------
configuration of data sharing stored
------------------------------------

EOF

cat << EOF
--------------------------------
[INFO]:storage device detection
--------------------------------
wait....

EOF

sleep 3

fdisk -l

sleep 3

echo -n "select device (example :sdb,sdc,sda...) :"
read $dev

echo -n "Master server name (run the \"uname -n\" command on this host) :"
read $name_s2

echo -n "password to secure the exchange (must be the same on the secondary host) :"
read $password

name_s1=$(uname -n)

  #si c'est le disk principale ne rien faire
  if [$dev = "sda"]

    then

      echo " partition principal "

    else

      clear

      cat << EOF
------------------------------------------------
[INFO]:creating a partition on the second disks
------------------------------------------------
list of parameters to enter :
* command           : "n"
* Partition type    : "p"
* Partition number  : enter for defaul value
* First sector      : enter for defaul value
* Last sector       : enter for defaul value
* command           : "w"

EOF

    read -p " ENTRE pour continue" continu

    # création d'une partition sur le second disque
    fdisk /dev/$dev

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
                shared-secret \"$password\";
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
                disk /dev/\"$dev\"1;
                address $RIP1:7788;
                meta-disk internal;
        }

        on $name_s2 {
                device /dev/drbd0;
                disk /dev/\"$dev\"1;
                address $RIP2:7788;
                meta-disk internal;
        }
}
    " >> /etc/drbd.d/drbd0.res

    read -p "create-md r0 : ENTRE pour continue" continu
    #
    drbdadm create-md r0

    read -p "activation du module drbd : ENTRE pour continue" continu
    #activation du module drbd
    modprobe drbd

    read -p "demarrage drbd : ENTRE pour continue" continu
    #demarrage de la configuration de la resource
    drbdadm up r0

    read -p "overview drbd : ENTRE pour continue" continu
    #
    drbd-overview

    read -p "synchronisation drbd : ENTRE pour continue" continu

    ##########uniquemet sur le secondary #######################
    #on defini ce noeud comme etant le secondary  & debut de la synchronisation
    # drbdadm secondary r0

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

fi
