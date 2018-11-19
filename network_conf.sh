#!/bin/bash
#-------------------------------
#    Configuration du réseau
#-------------------------------
clear
cat << EOF
--------------------------------------
Network configuration
--------------------------------------

Ethernet configuration

EOF

	read choix

	clear
cat << EOF
-------------------------------------
Configuration Ethernet
-------------------------------------

EOF

	read choix_eth

	choix_eth1()
	{
		clear
cat << EOF
-------------------------------------
Configuration Ethernet N1
-------------------------------------

EOF
		echo -n "Name of the Ethernet interface n1"
		read interface1
    echo -n "Name of the Ethernet interface n2"
		read interface2
    echo -n "Name of the Ethernet interface virtual (dualeth0)"
		read interface_v
		echo -n "IP adress of virtual interface:"
		read ip_add
		echo -n "Netmask:"
		read netmask
		echo -n "Gateway:"
		read gateway
		echo -n "DNS Server:"
		read nameserver

  ## On desactive les deux interface ultilisr pour l'adregation.
ifdow $interface1
ifdow $interface2

	## Copie des paramètres dans le fichier de configuration

echo "
## Configuration de $interface_v en mode Statique
auto $interface_v
iface $interface_v inet static
	address $ip_add
	netmask $netmask
	gateway $gateway
  slaves $interface1 $interface2
  bond_mode balance-rr
  bond_miimon 100
  bond_downdelay 200
  bond_updelay 200
  mtu 9000
	dns-nameservers $nameserver

  auto $interface1
  iface $interface1 inet manual

  auto $interface2
  iface $interface2 inet manual" >> /etc/network/interfaces

	## Si la dernière commande est correctement exécutée, on affiche

		if [ $? = "0" ]; then
			echo "[INFO]: Configuration data was successfully written"

      ##puis on active l'interface virtual
      ifdow $interface_v
			sleep 1
		fi

    ## redémarrage du service...
    echo "[INFO]: Restarting the service..."

/etc/network/interfaces
		sleep 5
		$0

	}
	choix_eth2()
	{
		clear
cat << EOF
-----------------------------------
Configuration Ethernet N2
-----------------------------------

EOF
    echo -n "Name of the Ethernet interface n3"
    read interface
    echo -n "IP adress:"
    read ip_add
    echo -n "Netmask:"
    read netmask
    echo -n "Gateway:"
    read gateway

		echo "
## Configuration de $interface en mode dynamique
auto $interface
iface $interface inet static
	address $ip_add
	netmask $netmask
	gateway $gateway
	dns-nameservers $nameserver" >> /etc/network/interfaces


		if [ $? = "0" ]; then
			echo "Configuration data was successfully written"

      ## redémarrage du service...
			echo "[INFO]: Restarting the service..."

	/etc/network/interfaces
			sleep 5
			$0
		fi
	}

	case $choix_eth in
		1) choix_eth1
		;;
		2) choix_eth2
		;;
		3) $0
		;;
	esac
