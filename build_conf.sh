#!/bin/bash
#-------------------------------
#    script pour configurer automatiquement les machine
#
#  information a avoir avant de lancer le script:
# * adresse IP reel (physique) des deux serveur
# * adresse IP virtual du serveur master
# * nom machine du serveur secondaire : executer la cmd  "uname -n"
# * nom du deuxieme disk de sauvegarde du master executer la cmd  "fdisk -l"
# * un mot de passe pour lechange de fichier entes les serveur
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

echo -n "secondary server name (run the \"uname -n\" command on this host) :"
read $name_s2

echo -n "password to secure the exchange (must be the same on the secondary host) :"
read $password

name_s1=$(uname -n)

  #si c'est le disk principale ne rien faire
  if [$dev = "sda"]

    then

      echo ""

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

    sleep 5

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
                address $RIP1:7788;
                meta-disk internal;
        }
}
    " >> /etc/drbd.d/drbd0.res

    #
    drbdadm create-md r0

    #activation du module drbd
    modprobe drbd

    #demarrage de la configuration de la resource
    drbdadm up r0

    #
    drbd-overview

    sleep 3

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

    ##formater du lecteur drbd0, en ext4 :
    mkfs.ext4 /dev/drbd0

    ##########uniquemet sur le secondaire######################
    drbdadm secondary r0


fi
