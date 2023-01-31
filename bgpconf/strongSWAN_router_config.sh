#!/bin/bash

#
# StrongSWAN router configuration
#

#Tunnel Information

export ROUTER_PRIVATE_IP="<ROUTER_PRIVATE_IP>"

export CONN_TUNNEL1_ONPREM_OUTSIDE_IP="<ROUTER_PUBLIC_IP>"
export CONN_TUNNEL1_AWS_OUTSIDE_IP="<VPN_TUNNEL1_OUTSIDE_IP>"
export CONN_TUNNEL1_ONPREM_INSIDE_IP="<CGW_TUNNEL1_INSIDE_ADDRESS_WITH/30>"
export CONN_TUNNEL1_AWS_INSIDE_IP="<VPN_TUNNEL1_INSIDE_ADDRESS_WITH/30>"

export CONN_TUNNEL2_ONPREM_OUTSIDE_IP="<ROUTER_PUBLIC_IP>"
export CONN_TUNNEL2_AWS_OUTSIDE_IP="<VPN_TUNNEL2_OUTSIDE_IP>"
export CONN_TUNNEL2_ONPREM_INSIDE_IP="<CGW_TUNNEL2_INSIDE_ADDRESS_WITH/30>"
export CONN_TUNNEL2_AWS_INSIDE_IP="<VPN_TUNNEL2_INSIDE_ADDRESS_WITH/30>"

export PSK_KEY="strongswan_awsvpn"

echo "export ROUTER_PRIVATE_IP=${ROUTER_PRIVATE_IP}" | tee -a ~/.bash_profile

echo "export CONN_TUNNEL1_ONPREM_OUTSIDE_IP=${CONN_TUNNEL1_ONPREM_OUTSIDE_IP}" | tee -a ~/.bash_profile
echo "export CONN_TUNNEL1_AWS_OUTSIDE_IP=${CONN_TUNNEL1_AWS_OUTSIDE_IP}" | tee -a ~/.bash_profile
echo "export CONN_TUNNEL1_ONPREM_INSIDE_IP=${CONN_TUNNEL1_ONPREM_INSIDE_IP}" | tee -a ~/.bash_profile
echo "export CONN_TUNNEL1_AWS_INSIDE_IP=${CONN_TUNNEL1_AWS_INSIDE_IP}" | tee -a ~/.bash_profile

echo "export CONN_TUNNEL2_ONPREM_OUTSIDE_IP=${CONN_TUNNEL2_ONPREM_OUTSIDE_IP}" | tee -a ~/.bash_profile
echo "export CONN_TUNNEL2_AWS_OUTSIDE_IP=${CONN_TUNNEL2_AWS_OUTSIDE_IP}" | tee -a ~/.bash_profile
echo "export CONN_TUNNEL2_ONPREM_INSIDE_IP=${CONN_TUNNEL2_ONPREM_INSIDE_IP}" | tee -a ~/.bash_profile
echo "export CONN_TUNNEL2_AWS_INSIDE_IP=${CONN_TUNNEL2_AWS_INSIDE_IP}" | tee -a ~/.bash_profile

echo "export PSK_KEY=${PSK_KEY}" | tee -a ~/.bash_profile


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
         leftid=$CONN_TUNNEL1_ONPREM_OUTSIDE_IP
         # Virtual Private Gateway :
         right=$CONN_TUNNEL1_AWS_OUTSIDE_IP
         rightid=$CONN_TUNNEL1_AWS_OUTSIDE_IP
         auto=start
         mark=100
         #reqid=1
conn AWS-VPC-GW2
         # Customer Gateway: :
         left=$ROUTER_PRIVATE_IP
         leftid=$CONN_TUNNEL2_ONPREM_OUTSIDE_IP
         # Virtual Private Gateway :
         right=$CONN_TUNNEL2_AWS_OUTSIDE_IP
         rightid=$CONN_TUNNEL2_AWS_OUTSIDE_IP
         auto=start
         mark=200
EOF

cat <<EOF > /etc/ipsec.secrets
$CONN_TUNNEL1_ONPREM_OUTSIDE_IP $CONN_TUNNEL1_AWS_OUTSIDE_IP : PSK "$PSK_KEY"
$CONN_TUNNEL2_ONPREM_OUTSIDE_IP $CONN_TUNNEL2_AWS_OUTSIDE_IP : PSK "$PSK_KEY"
EOF


cat <<EOF > /etc/ipsec-vti.sh
#!/bin/bash

#
# /etc/ipsec-vti.sh
#
IP=$(which ip)
IPTABLES=$(which iptables)

PLUTO_MARK_OUT_ARR=(${PLUTO_MARK_OUT//// })
PLUTO_MARK_IN_ARR=(${PLUTO_MARK_IN//// })
case "$PLUTO_CONNECTION" in
AWS-VPC-GW1)
VTI_INTERFACE=vti1
VTI_LOCALADDR=$CONN_TUNNEL1_ONPREM_INSIDE_IP
VTI_REMOTEADDR=$CONN_TUNNEL1_AWS_INSIDE_IP
;;
AWS-VPC-GW2)
VTI_INTERFACE=vti2
VTI_LOCALADDR=$CONN_TUNNEL2_ONPREM_INSIDE_IP
VTI_REMOTEADDR=$CONN_TUNNEL2_AWS_INSIDE_IP
;;
esac

case "${PLUTO_VERB}" in
up-client)
#$IP tunnel add ${VTI_INTERFACE} mode vti local ${PLUTO_ME} remote ${PLUTO_PEER} okey ${PLUTO_MARK_OUT_ARR[0]} ikey ${PLUTO_MARK_IN_ARR[0]}
$IP link add ${VTI_INTERFACE} type vti local ${PLUTO_ME} remote ${PLUTO_PEER} okey ${PLUTO_MARK_OUT_ARR[0]} ikey ${PLUTO_MARK_IN_ARR[0]}
sysctl -w net.ipv4.conf.${VTI_INTERFACE}.disable_policy=1
sysctl -w net.ipv4.conf.${VTI_INTERFACE}.rp_filter=2 || sysctl -w net.ipv4.conf.${VTI_INTERFACE}.rp_filter=0
$IP addr add ${VTI_LOCALADDR} remote ${VTI_REMOTEADDR} dev ${VTI_INTERFACE}
$IP link set ${VTI_INTERFACE} up mtu 1436
$IPTABLES -t mangle -I FORWARD -o ${VTI_INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
$IPTABLES -t mangle -I INPUT -p esp -s ${PLUTO_PEER} -d ${PLUTO_ME} -j MARK --set-xmark ${PLUTO_MARK_IN}
$IP route flush table 220
#/etc/init.d/bgpd reload || /etc/init.d/quagga force-reload bgpd
;;
down-client)
#$IP tunnel del ${VTI_INTERFACE}
$IP link del ${VTI_INTERFACE}
$IPTABLES -t mangle -D FORWARD -o ${VTI_INTERFACE} -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
$IPTABLES -t mangle -D INPUT -p esp -s ${PLUTO_PEER} -d ${PLUTO_ME} -j MARK --set-xmark ${PLUTO_MARK_IN}
;;
esac

# Enable IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.ens5.disable_xfrm=1
sysctl -w net.ipv4.conf.ens5.disable_policy=1
EOF

chmod +x /etc/ipsec-vti.sh

sleep 5

systemctl restart strongswan
