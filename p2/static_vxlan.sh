#!/bin/bash

username=$HOST_USER
router1="router_${HOST_USER}-1"
router2="router_${HOST_USER}-2"
host1="host_${HOST_USER}-1"
host2="host_${HOST_USER}-2"

echo $router1 $router2 $host1 $host2

router_reset() {
	local container=$1

	cmd="
		ip addr flush dev eth0 2>/dev/null || true &&
		ip link del vxlan10 2>/dev/null || true && 
		ip link del br0 2>/dev/null || true
	"
	echo "\"$container\": docker exec is running"
	docker exec $container sh -c "$cmd"
}

host_reset() {
	local container=$1

	cmd="
		ip address flush dev eth0 2>/dev/null
	"

	echo "\"$container\": docker exec is running"
	docker exec $container sh -c "$cmd"
}


router_config() {
	local container=$1
	local local_addr=$2
	local remote_addr=$3

	cmd="
		ip address add $local_addr dev eth0
		ip link add name vxlan10 type vxlan id 10 remote $remote_addr dstport 4789 dev eth0
		# ip link add name br0 type bridge
		brctl addbr br0
		ip link set br0 up
		ip link set vxlan10 up
		# ip link set vxlan10 master br0
		# ip link set eth1 master br0
		brctl addif br0 vxlan10
		brctl addif br0 eth1
	"

	echo "\"$container\": docker exec is running"
	docker exec $container sh -c "$cmd"
}

host_config() {
	local container=$1
	local ip_addr=$2

	cmd="
		ip addr add $ip_addr dev eth0
	"

	echo "\"$container\": docker exec is running"
	docker exec $container sh -c "$cmd"
}

main() {
	for container_id in $(docker ps -q); do
		container_hostname=$(docker exec -it $container_id hostname)
		container_hostname=${container_hostname::-1}
			
		echo "$container_hostname"
		case "$container_hostname" in
			$router1)
			router_reset $container_id
			router_config $container_id "10.1.1.1/24" "10.1.1.2"
			;;
			$router2)
			router_reset $container_id
			router_config $container_id "10.1.1.2/24" "10.1.1.1"
			;;
			$host1)
			host_reset $container_id
			host_config $container_id "30.1.1.1/24"
			;;
			$host2)
			host_reset $container_id
			host_config $container_id "30.1.1.2/24"
			;;
		*)
		echo "DEFAULT"
		esac
	done
}

main