## Router
# Add ipv4 to switch port
ip addr add 10.1.1.1/24 dev eth0
# ip addr add 10.1.1.2/24 dev eth0
# Create vxlan10 static
ip link add name vxlan10 type vxlan id 10 dev eth0 remote 10.1.1.2 dstport 4789
# ip link add name vxlan10 type vxlan id 10 dev eth0 remote 10.1.1.1 dstport 4789
ip addr add 30.1.1.1/24 dev vxlan10
# Start vxlan
ip link set dev vxlan10 up
# Create bridge
brctl addbr br0
	or
ip link add br0 type bridge
# Start bridge
ip link set dev br0 up
# Link bridge to vxlan and host port
brctl addif br0 eth1
brctl addif br0 vxlan10



## Host
ip addr add 30.1.1.1/24 dev eth0
ip addr add 30.1.1.2/24 dev eth0

ping 30.1.1.2
