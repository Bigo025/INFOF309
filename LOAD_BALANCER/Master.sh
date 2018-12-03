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
----------------------------------------------------------------
[INFO]: wait to installing dependencies
----------------------------------------------------------------

EOF

sleep 4

echo "[INFO]: ipvsadm installation for Load balancing"
apt-get install -y ipvsadm

echo "[INFO]: heartbeat installation for High availability"
apt-get install -y heartbeat

echo "[INFO]: ldirectord "
apt-get install -y ldirectord

#--------------------------------------------------------------------
#  partie 2: Configuration des interfaces reseaux
#--------------------------------------------------------------------
clear

read -p "do you want to configured network [Y/N] :" reponse

if [ $reponse = "y" ]
  then

cat << EOF
------------------------------------------------------------------
Configuration Ethernet N1
------------------------------------------------------------------

EOF

echo -n "Name of the Ethernet interface n1 :"
read interface1
echo -n "IP adress of  interface $interface1 :"
read RIP1
echo -n "Network adress N1:"
read network
echo -n "Netmask :"
read netmask
echo -n "Gateway :"
read gateway
echo -n "DNS Server :"
read nameserver


echo -n "Name of the Ethernet interface n2 :"
read interface2
echo -n "IP adress of  interface $interface2 :"
read RIP2
echo -n "Network adress N2:"
read network2
echo -n "Netmask :"
read netmask2
echo -n "Gateway :"
read gateway2
echo -n "DNS Server :"
read nameserver2

echo -n "VIP adress  :"
read VIP

echo -n "IP adress of Web server N1 :"
read WEP_IP1
echo -n "IP adress of Web server N2 :"
read WEP_IP2


clear

###############################
interface1=enp0s3
RIP1=172.16.1.2
netmask=255.255.255.0
gateway=172.16.1.2
nameserver=8.8.8.8
network=172.16.1.0

interface2=enp0s8
RIP2=172.16.5.1
netmask2=255.255.255.0
gateway2=172.16.5.1
nameserver2=8.8.8.8
network2=172.16.5.0

VIP=172.16.1.1
WEP_IP1=172.16.1.5
WEP_IP2=172.16.1.6

interface3=enp0s9
############################

cat << EOF
------------------------------------------------------
[INFO]:Configuration Ethernet N1
------------------------------------------------------

EOF

	## Copie des paramètres dans le fichier de configuration

echo "
source /etc/network/interfaces.d/*

## the loopback network interface
auto lo
iface lo inet loopback

## Configuration de $interface1 en mode Statique
auto $interface1
iface $interface1 inet static
address $RIP1
netmask $netmask
#getway $getway

## Configuration de $interface2 en mode Statique
auto $interface2
iface $interface2 inet static
address $RIP2
netmask $netmask2
#getway $getway2

auto $interface3
iface $interface3 inet dhcp " > /etc/network/interfaces


#	echo "[INFO]: Restarting the service..."

/etc/init.d/networking restart

sleep 5

cat << EOF
-------------------------------------------------------------
[OK]:CONFIGURATION NETWORK
-------------------------------------------------------------

EOF

reboot

elif [ $reponse = "n" ]

then

echo "OK Continue configuration"

fi

#--------------------------------------------------------------------
#  partie 3: Configuration du Load balancing
#--------------------------------------------------------------------

clear

cat << EOF
----------------------------------------------------------------
Configuration Load balancing
----------------------------------------------------------------
EOF

name_LB1=$(uname -n)
echo -n "Name of the secondary Node Load balancer (uname -n) :"
read name_LB2

####################
name_LB1=load1
name_LB2=load2
###################

echo "
#################################################
# virtual = x.y.z.w:p                           #
# protocol = tcp|udp                            #
# scheduler = rr|wrr|lc|wlc                     #
# real = x.y.z.w:p gate|masq|ipip [weight]      #
#################################################

checkinterval = 5
checktimeout = 10
autoreload = no
logfile = \"/var/log/ldirectord.log\"
#logfile=\"local0\"
quiescent = yes


# Virtual Server for HTTP
virtual = $VIP:80
  real = $WEP_IP1:80 gate 1
	real = $WEP_IP2:80 gate 1
	service = http
	protocol = tcp
#	request = \"lbcheck.html\"
#	receive = \"found\"
	scheduler = rr
	checktype = negotiate " > /etc/ha.d/ldirectord.cf

#demarrage du service ldirectord

/etc/init.d/ldirectord stop

sleep 3

#configuration a effectuer sur les deux serveur web

echo "
net.ipv4.ip_forward = 1 " >> /etc/sysctl.conf

sleep 1

#Recharge de la configuration ARP
sysctl -p

echo "

logfile /var/log/ha.log
logfacility local0
debug 0

# Disable the Pacemaker cluster manager
# crm off|on|respawn
crm off

# Interval between heartbeat packets
keepalive 2
# How quickly Heartbeat should decide that a node in a cluster is dead
deadtime 6

# Which port Heartbeat should listen on
udpport 694
# Which interfaces Heartbeat sends UDP broadcast traffic on

#ucast $interface1 172.16.1.3
bcast $interface1

# Automatically fail back to a primary node
auto_failback on

# What machines are in the cluster. Use
node $name_LB1
node $name_LB2 " >  /etc/ha.d/ha.cf


#creation des ressources a surveiller
echo "
$name_LB1 IPaddr2::$VIP ldirectord::ldirectord.cf
" > /etc/ha.d/haresources


#creation du fichier pour l'authetification

echo "
auth 2
 1 md5 \"password\"
 2 crc
" > /etc/ha.d/authkeys

chmod 600 /etc/ha.d/authkeys

#Configuration de la synchronisation de la table des sessions
#copier le fichier "lvsstate" dans init.d

cp lvsstate /etc/init.d/

#donne les droit d'execution au fichier

chmod +x /etc/init.d/lvsstate
chmod 777 /etc/init.d/lvsstate

#mettre ce script au demarrage du server
#
#
#
####################@@@@@@@@@@@@@#@#@#@##@#@#@#@#@@#

#demarrage du script
/etc/init.d/lvsstate start

#conf du fireware pour laiser passer le traffic

iptables -A INPUT -s $network/24 -p udp --dport 694 -j ACCEPT
iptables -A INPUT -s $network/24 -p tcp --dport 80 -j ACCEPT

iptables -A INPUT -s $network2/24 -p udp --dport 694 -j ACCEPT
iptables -A INPUT -s $network2/24 -p tcp --dport 80 -j ACCEPT


cat << EOF
------------------------------------------------------------------
Sve configuration of fireware
------------------------------------------------------------------
EOF
#savegarder des CONFIGURATION
iptables-save


#demarrage de heartbeat
/etc/init.d/heartbeat start


sleep 7

cat << EOF
------------------------------------------------------------------------
[INFO] : list of load-balancing rules
------------------------------------------------------------------------
EOF
#affiche les informations à propos du resume du Load balancing
ipvsadm -Ln

echo "------------------------------------------------------------------"

sleep 7
