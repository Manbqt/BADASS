#!/bin/bash

username=$HOST_USER
vtep1="router_${username}-1"
vtep2="router_${username}-2"
vtep3="router_${username}-3"
rr="router_${username}-4"
host1="host_${username}-1"
host2="host_${username}-2"
host3="host_${username}-3"

router_reset() {
	local container=$1

	cmd="
		ip addr flush dev eth0 2>/dev/null || true &&
		ip link del vxlan10 2>/dev/null || true &&
		ip link del br0 2>/dev/null || true
	"
	echo "\"$container\": Reset Router Interface"
	docker exec "$container" sh -c "$cmd"
}

host_reset() {
	local container=$1

	cmd="
		ip address flush dev eth0 2>/dev/null
	"

	echo "\"$container\": Reset Host Interface"
	docker exec "$container" sh -c "$cmd"
}
rr_reset () {
	local container=$1

	cmd="
        ip address flush dev eth0 2>/dev/null;
        ip address flush dev eth1 2>/dev/null;
        ip address flush dev eth2 2>/dev/null;
	"
	echo "\"$container\": Reset RR Interface"
	docker exec "$container" sh -c "$cmd"
}

vxlan_config() {
	local container=$1

	cmd="
		ip link add name vxlan10 type vxlan id 10 dstport 4789 dev eth0
		brctl addbr br0
		ip link set br0 up
		ip link set vxlan10 up
		brctl addif br0 vxlan10
		brctl addif br0 eth1
	"

	echo "\"$container\": Router configuration"
	docker exec "$container" sh -c "$cmd"
}

vtep_bgp_config() {
	local container=$1
	local local_addr=$2
	local lo_ip=$3

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
		-c "exit-address-family" \
		-c "router ospf"
}

host_config() {
	local container=$1
	local ip_addr=$2

	cmd="
		ip addr add $ip_addr dev eth0
	"

	echo "\"$container\": Host configuration"
	docker exec "$container" sh -c "$cmd"
}

rr_config() {
	local container=$1
	local lo_ip=$2

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

	echo "\"$container\": Reflector configuration"
}

main() {
	for container_id in $(docker ps -q); do
		container_hostname=$(docker exec -it "$container_id" hostname)
		container_hostname=${container_hostname::-1}

		echo "$container_hostname"
		case "$container_hostname" in
		"$rr")
			rr_reset "$container_id"
			rr_config "$container_id" "1.1.1.4/32"
			;;
		"$vtep1")
			router_reset "$container_id"
			vxlan_config "$container_id"
			vtep_bgp_config "$container_id" "10.1.1.1/30" "1.1.1.1/32"
			;;
		"$vtep2")
			router_reset "$container_id"
			vxlan_config "$container_id"
			vtep_bgp_config "$container_id" "10.1.1.5/30" "1.1.1.2/32"
			;;
		"$vtep3")
			router_reset "$container_id"
			vxlan_config "$container_id"
			vtep_bgp_config "$container_id" "10.1.1.9/30" "1.1.1.3/32"
			;;
		"$host1")
			host_reset "$container_id"
			host_config "$container_id" "30.1.1.1/24"
			;;
		"$host2")
			host_reset "$container_id"
			host_config "$container_id" "30.1.1.2/24"
			;;
		"$host3")
			host_reset "$container_id"
			host_config "$container_id" "30.1.1.3/24"
			;;
		*)
			echo "No configuration for this container $container_hostname"
			;;
		esac
	done
}

main
