#!/bin/bash

#
# StrongSWAN router configuration
#

#Tunnel Information

export ROUTER_PRIVATE_IP="<ROUTER_PRIVATE_IP>"
export ROUTER_PUBLIC_IP="<ROUTER_PUBLIC_IP>"

export CONN_TUNNEL1_AWS_OUTSIDE_IP="<VPN_TUNNEL1_OUTSIDE_IP>"
export CONN_TUNNEL2_AWS_OUTSIDE_IP="<VPN_TUNNEL2_OUTSIDE_IP>"

export PSK_KEY="strongswan_awsvpn"

echo "export ROUTER_PRIVATE_IP=${ROUTER_PRIVATE_IP}" | tee -a ~/.bash_profile
echo "export ROUTER_PUBLIC_IP=${ROUTER_PUBLIC_IP}" | tee -a ~/.bash_profile

echo "export CONN_TUNNEL1_AWS_OUTSIDE_IP=${CONN_TUNNEL1_AWS_OUTSIDE_IP}" | tee -a ~/.bash_profile
echo "export CONN_TUNNEL2_AWS_OUTSIDE_IP=${CONN_TUNNEL2_AWS_OUTSIDE_IP}" | tee -a ~/.bash_profile

echo "export PSK_KEY=${PSK_KEY}" | tee -a ~/.bash_profile

source ~/.bash_profile

cat <<EOF > /etc/ipsec.conf
conn %default
         # Authentication Method : Pre-Shared Key
         leftauth=psk
         rightauth=psk
         # Encryption Algorithm : aes-128-cbc
         # Authentication Algorithm : sha1
         # Perfect Forward Secrecy : Diffie-Hellman Group 2
         ike=aes128-sha1-modp1024!
         # Lifetime : 28800 seconds
         ikelifetime=28800s
         # Phase 1 Negotiation Mode : main
         aggressive=no
         # Protocol : esp
         # Encryption Algorithm : aes-128-cbc
         # Authentication Algorithm : hmac-sha1-96
         # Perfect Forward Secrecy : Diffie-Hellman Group 2
         esp=aes128-sha1-modp1024!
         # Lifetime : 3600 seconds
         lifetime=3600s
         # Mode : tunnel
         type=tunnel
         # DPD Interval : 10
         dpddelay=10s
         # DPD Retries : 3
         dpdtimeout=30s
         # Tuning Parameters for AWS Virtual Private Gateway:
         keyexchange=ikev1
         rekey=yes
         reauth=no
         dpdaction=restart
         closeaction=restart
         leftsubnet=0.0.0.0/0,::/0
         rightsubnet=0.0.0.0/0,::/0
         leftupdown=/etc/ipsec-vti.sh
         installpolicy=yes
         compress=no
         mobike=no
conn AWS-VPC-GW1
         # Customer Gateway: :
         left=$ROUTER_PRIVATE_IP
         leftid=$ROUTER_PUBLIC_IP
         # Virtual Private Gateway :
         right=$CONN_TUNNEL1_AWS_OUTSIDE_IP
         rightid=$CONN_TUNNEL1_AWS_OUTSIDE_IP
         auto=start
         mark=100
         #reqid=1
conn AWS-VPC-GW2
         # Customer Gateway: :
         left=$ROUTER_PRIVATE_IP
         leftid=$ROUTER_PUBLIC_IP
         # Virtual Private Gateway :
         right=$CONN_TUNNEL2_AWS_OUTSIDE_IP
         rightid=$CONN_TUNNEL2_AWS_OUTSIDE_IP
         auto=start
         mark=200
EOF

cat <<EOF > /etc/ipsec.secrets
$ROUTER_PUBLIC_IP $CONN_TUNNEL1_AWS_OUTSIDE_IP : PSK "$PSK_KEY"
$ROUTER_PUBLIC_IP $CONN_TUNNEL2_AWS_OUTSIDE_IP : PSK "$PSK_KEY"
EOF


cp ipsec-vti.sh /etc/ipsec-vti.sh
chmod +x /etc/ipsec-vti.sh
