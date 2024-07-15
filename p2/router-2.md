## Router
# Clean
ip address flush dev eth0
ip link del vxlan10
ip link del br0
# Add ipv4 to switch port
ip addr add 10.1.1.2/24 dev eth0
# Create vxlan10 static
ip link add name vxlan10 type vxlan id 10 remote 10.1.1.1 dstport 4789 dev eth0
ip link add name br0 type bridge
ip link set br0 up
ip link set vxlan10 up
ip link set vxlan10 master br0
ip link set eth1 master br0



## Host
ip addr add 30.1.1.1/24 dev eth0
ip addr add 30.1.1.2/24 dev eth0

ping 30.1.1.2
