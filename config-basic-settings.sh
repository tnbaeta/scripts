#!/bin/bash

#set hostname

echo "Enter the FQDN of the host:"
read hostname

hostnamectl set-hostname $hostname
echo "Hostname changed to" $hostname

#set ip configuration

echo "Enter the IP address in CDIR format:"
read ip_address

echo "Enter the default gateway:"
read gateway

echo "Enter the DNS Server"
read dns

echo "Enter the search domain"
read domain


nmcli c modify ens192 ipv4.addresses $ip_address
nmcli c modify ens192 ipv4.gateway $gateway
nmcli c modify ens192 ipv4.dns $dns
nmcli c modify ens192 ipv4.dns-search $domain
nmcli c modify ens192 ipv4.method manual

nmcli c down ens192
nmcli c up ens192

echo -e 'y\n' | ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
