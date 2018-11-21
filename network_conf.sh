#!/bin/bash
#-------------------------------
#    Configuration du réseau
#-------------------------------

#prend le premiere parametre (variables env) et le met dans une autre variables pour falite le traitement
tab2=$1

#recuperation des donne tu tableau $tab2
j=0
for i in ${tab2[*]}

	do
		#creer un table data[] et insert chaque element dans le tableau
		data[$j]=$i
		((j++))
	done

	###################Contenue des variables ###########
	#																										#
	#		${data[0]}  	=	eth0 interface1									#
	#		${data[1]} 		= eth1 interface2									#
	#		${data[2]} 		=	dualeth0 interface_v						#
	#		${data[3]} 		=	RIP1 ip_add											#
	#		${data[4]} 		=	netmask													#
	#		${data[5]} 		=	gateway													#
	#		${data[7]} 		=	VIP ip_add_v										#
	#		${data[6]} 		=	nameserver											#
	#		${data[8]} 		=	interface3											#
	#		${data[9]}  	=	RIP3														#
	#		${data[10]} 	=	netmask3												#
	#		${data[11]} 	=	gateway3												#
	#																										#
	######################################################

cat << EOF
-------------------------------------
Configuration Ethernet N1
-------------------------------------

EOF

  ## On desactive les deux interface ultilisr pour l'adregation.
ifdown ${data[0]}
ifdown ${data[1]}

	## Copie des paramètres dans le fichier de configuration

echo "
source /etc/network/interfaces.d/*

## the loopback network interface
auto lo
iface lo inet loopback

## Configuration de ${data[2]} en mode Statique

auto ${data[2]}
iface ${data[2]} inet static
address ${data[3]}
netmask ${data[4]}
getway ${data[5]}
mtu 9000
slaves ${data[0]} ${data[1]}
bond_mode balance-rr
bond_miimons 100
bond_downdelay 200
bond_updelay 200

## Configuration de l'adresse IP virtuelle de ${data[2]} en mode Statique
auto ${data[2]}:0
iface ${data[2]}:0 inet static
address ${data[7]}
netmask 255.255.255.255 " > /etc/network/interfaces

	## Si la dernière commande est correctement exécutée, on affiche

		if [ $? = "0" ]; then
			echo "[INFO]: Configuration data was successfully written"

      ##puis on active l'interface virtual (carte reseau)
      ifup ${data[2]}
			##puis on active l'interface virtual de la VIP
			ifup ${data[2]}:0
			sleep 2
		fi

    ## redémarrage du service...
    echo "[INFO]: Restarting the service..."

/etc/init.d/networking restart
#	sleep 5
#		$0

cat << EOF
-----------------------------------
Configuration Ethernet N2
-----------------------------------

EOF

		echo "
## Configuration de ${data[8]} en mode dynamique
auto ${data[8]}
iface ${data[8]} inet static
	address ${data[9]}
	netmask ${data[10]}
	gateway ${data[11]}
	dns-nameservers ${data[6]}" >> /etc/network/interfaces


		if [ $? = "0" ]; then
			echo "Configuration data was successfully written"

      ## redémarrage du service...
			echo "[INFO]: Restarting the service..."

	/etc/init.d/networking restart

	sleep 5
			$0
		fi
