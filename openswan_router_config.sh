export AWS_VPN_TUNNEL_IP1="13.209.92.248"
export AWS_VPN_TUNNEL_IP2="54.180.176.79"
export CGW_IP="43.201.103.149"
export CGW_CIDR="172.16.0.0/16"
export AWS_VPC_CIDR="10.0.0.0/16"
export PSK_KEY="s2svpn_openswan"
echo "export AWS_VPN_TUNNEL_IP1=${AWS_VPN_TUNNEL_IP1}" | tee -a ~/.bash_profile
echo "export AWS_VPN_TUNNEL_IP2=${AWS_VPN_TUNNEL_IP2}" | tee -a ~/.bash_profile
echo "export CGW_IP=${CGW_IP}" | tee -a ~/.bash_profile
echo "export CGW_ID=${CGW_ID}" | tee -a ~/.bash_profile
echo "export CGW_CIDR=${CGW_CIDR}" | tee -a ~/.bash_profile
echo "export AWS_VPC_CIDR=${AWS_VPC_CIDR}" | tee -a ~/.bash_profile
echo "export PSK_KEY=${PSK_KEY}" | tee -a ~/.bash_profile

cat <<EOF > /etc/ipsec.d/tunnel.conf
conn tunnel1
        authby=secret
        auto=start
        left=%defaultroute
        leftid=$CGW_IP
        right=$AWS_VPN_TUNNEL_IP1
        type=tunnel
        ikelifetime=8h
        keylife=1h
        phase2alg=aes128-sha1;modp1024
        ike=aes128-sha1;modp1024
        keyingtries=%forever
        keyexchange=ike
        leftsubnet=$CGW_CIDR
        rightsubnet=$AWS_VPC_CIDR
        dpddelay=10
        dpdtimeout=30
        dpdaction=restart_by_peer
        overlapip=yes
conn tunnel2
        authby=secret
        auto=start
        left=%defaultroute
        leftid=$CGW_IP
        right=$AWS_VPN_TUNNEL_IP2
        type=tunnel
        ikelifetime=8h
        keylife=1h
        phase2alg=aes128-sha1;modp1024
        ike=aes128-sha1;modp1024
        keyingtries=%forever
        keyexchange=ike
        leftsubnet=$CGW_CIDR
        rightsubnet=$AWS_VPC_CIDR
        dpddelay=10
        dpdtimeout=30
        dpdaction=restart_by_peer
        overlapip=yes
EOF

cat <<EOF > /etc/ipsec.d/tunnel.secrets
$CGW_IP $AWS_VPN_TUNNEL_IP1: PSK "$PSK_KEY"
$CGW_IP $AWS_VPN_TUNNEL_IP2: PSK "$PSK_KEY"
EOF

cat <<EOF > /etc/sysctl.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.accept_source_route = 0
EOF

sudo sysctl --system
sudo systemctl start ipsec.service
sudo systemctl enable ipsec.service
sudo service network restart
sudo service ipsec restart
sleep 5
ipsec status
sudo systemctl status ipsec.service

