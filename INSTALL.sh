#!/bin/bash

#read -p "entre le nom :" name

#echo "$name" > /etc/hostname

#echo "

#  GNU nano 2.9.3                      /etc/hosts

#127.0.0.1       localhost
#127.0.1.1       $name

# The following lines are desirable for IPv6 capable hosts
#::1     ip6-localhost ip6-loopback
#fe00::0 ip6-localnet
#ff00::0 ip6-mcastprefix
#ff02::1 ip6-allnodes
#ff02::2 ip6-allrouters " > /etc/hosts

git clone https://github.com/prettyHello/INFOF309

cd INFOF309

git pull origin High_availability

echo " [OK] FINISH"

