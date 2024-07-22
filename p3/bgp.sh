#!/bin/bash

username=$HOST_USER
vtep1="router_${username}-1"
vtep2="router_${username}-2"
vtep3="router_${username}-3"
rr="router_${username}-4"
host1="host_${username}-1"
host2="host_${username}-2"
host3="host_${username}-3"

# Colors
RESET="\e[0m"
BLACK="\e[0;30m"
RED="\e[0;31m"
GREEN="\e[0;32m"
BLUE="\e[0;34m"
YELLOW="\e[0;33m"
PURPLE="\e[0;35m"
CYAN="\e[0;36m"
WHITE="\e[0;37m"

router_reset() {
	local container=$1

	echo -e "Reset Router Interface"$RESET

	cmd="
		ip addr flush dev eth0 2>/dev/null || true;
		ip addr flush dev eth1 2>/dev/null || true;
		ip link del vxlan10 2>/dev/null || true;
		ip link del br0 2>/dev/null || true
	"
	docker exec "$container" sh -c "$cmd"
}

host_reset() {
	local container=$1

	echo -e "Reset Host Interface"$RESET
	cmd="
		ip address flush dev eth0 2>/dev/null
	"
	docker exec "$container" sh -c "$cmd"
}
rr_reset () {
	local container=$1

	echo -e "Reset RR Interface"$RESET

	cmd="
        ip address flush dev eth0 2>/dev/null;
        ip address flush dev eth1 2>/dev/null;
        ip address flush dev eth2 2>/dev/null;
	"
	docker exec "$container" sh -c "$cmd"
}

vxlan_config() {
	local container=$1

	echo -e "VXLAN configuration"$RESET

	cmd="
		ip link add name vxlan10 type vxlan id 10 dstport 4789 dev eth0
		brctl addbr br0
		ip link set br0 up
		ip link set vxlan10 up
		brctl addif br0 vxlan10
		brctl addif br0 eth1
	"
	docker exec "$container" sh -c "$cmd"
}

vtep_bgp_config() {
	local container=$1
	local local_addr=$2
	local lo_ip=$3

	echo -e "VTEP Configuration BGP"$RESET

	docker exec "$container" "vtysh" \
		-c "config terminal" \
		-c "! Setup interfaces" \
		-c "interface eth0" \
		-c "	ip address $local_addr" \
		-c "	ip ospf area 0" \
		-c "interface lo" \
		-c "	ip address $lo_ip" \
		-c "	ip ospf area 0" \
		-c "! Setup BGP for AS of id 1" \
		-c "router bgp 1" \
		-c "! Add RR router as neighbor" \
		-c "	neighbor 1.1.1.4 remote-as 1" \
		-c "	neighbor 1.1.1.4 update-source lo" \
		-c "address-family l2vpn evpn" \
		-c "	neighbor 1.1.1.4 activate" \
		-c "	advertise-all-vni" \
		-c "exit-address-family" \
		-c "router ospf"
}

host_config() {
	local container=$1
	local ip_addr=$2

	echo -e "Host configuration"$RESET

	cmd="
		ip addr add $ip_addr dev eth0
	"
	docker exec "$container" sh -c "$cmd"
}

rr_config() {
	local container=$1
	local lo_ip=$2

	echo -e "Reflector configuration"$RESET

	docker exec "$container" "vtysh" \
		-c "config terminal" \
		-c "! Setup interfaces" \
		-c "interface eth0" \
		-c "	ip address 10.1.1.1/30" \
		-c "interface eth1" \
		-c "	ip address 10.1.1.5/30" \
		-c "interface eth2" \
		-c "	ip address 10.1.1.9/30" \
		-c "interface lo" \
		-c "	ip address $lo_ip" \
		-c "! Setup BGP for AS of id 1" \
		-c "router bgp 1" \
		-c "	neighbor ibgp peer-group" \
		-c "	neighbor ibgp remote-as 1" \
		-c "	neighbor ibgp update-source lo" \
		-c "	bgp listen range 1.1.1.0/29 peer-group ibgp" \
		-c "	address-family l2vpn evpn" \
		-c "		neighbor ibgp activate" \
		-c "		neighbor ibgp route-reflector-client" \
		-c "	exit-address-family" \
		-c "! Setup ospf for area id of 0" \
		-c "router ospf" \
		-c "	network 0.0.0.0/0 area 0"
}

main() {
	for container_id in $(docker ps -q); do
		container_hostname=$(docker exec -it "$container_id" hostname)
		container_hostname=${container_hostname::-1}

		prefix() { echo -en $BLUE"# "$GREEN"$container_hostname"$BLUE": "; }
		case "$container_hostname" in
		"$rr")
			prefix; rr_reset "$container_id"
			prefix; rr_config "$container_id" "1.1.1.4/32"
			;;
		"$vtep1")
			prefix; router_reset "$container_id"
			prefix; vxlan_config "$container_id"
			prefix; vtep_bgp_config "$container_id" "10.1.1.2/30" "1.1.1.1/32"
			;;
		"$vtep2")
			prefix; router_reset "$container_id"
			prefix; vxlan_config "$container_id"
			prefix; vtep_bgp_config "$container_id" "10.1.1.6/30" "1.1.1.2/32"
			;;
		"$vtep3")
			prefix; router_reset "$container_id"
			prefix; vxlan_config "$container_id"
			prefix; vtep_bgp_config "$container_id" "10.1.1.10/30" "1.1.1.3/32"
			;;
		"$host1")
			prefix; host_reset "$container_id"
			prefix; host_config "$container_id" "20.1.1.1/24"
			;;
		"$host2")
			prefix; host_reset "$container_id"
			prefix; host_config "$container_id" "20.1.1.2/24"
			;;
		"$host3")
			prefix; host_reset "$container_id"
			prefix; host_config "$container_id" "20.1.1.3/24"
			;;
		*)
			echo -e $RED"# No configuration for this container $container_hostname"$RESET
			;;
		esac
	done
}

main
