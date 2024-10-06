## About The Project
Mikrotik compatible Docker image to run Amnezia WG on Mikrotik routers. As of now, support Arm v7 boards

## About The Project
This is a highly experimental attempt to run [Amnezia-WG](https://github.com/amnezia-vpn/amnezia-wg) on a Mikrotik router.

### Prerequisites

Follow the [Mikrotik guidelines](https://help.mikrotik.com/docs/display/ROS/Container) to enable container support.

Install [Docker buildx](https://github.com/docker/buildx) subsystem, make and go.


### Building Docker Image

To build a Docker container for the ARM7 run
```
make build-arm7
```
This command should cross-compile amnezia-wg locally and then build a docker image for ARM7 arch.

To export a generated image, use
```
make export-arm7
```

You will get the `docker-awg-arm7.tar` archive ready to upload to the Mikrotik router.

### Running locally

Just run `docker compose up`

Make sure to create a `awg` folder with the `wg0.conf` file.

Example `wg0.conf`:

```
[Interface]
PrivateKey = gG...Y3s=
Address = 10.0.0.1/32
ListenPort = 51820
# Jc лучше брать в интервале [3,10], Jmin = 100, Jmax = 1000,
Jc = 3
Jmin = 100
Jmax = 1000
# Parameters below will not work with the existing WireGuarg implementation.
# Use if your peer running Amnesia-WG
# S1 = 324
# S2 = 452
# H1 = 25

# IP masquerading
PreUp = ip route add <ENDPOINT IP> via <CONTAINER IP> dev eth0
PreUp = ip route add 10.0.0.0/8 via <CONTAINER IP> dev eth0
PreUp = ip route add <UR ROUTER NETWORK>/16 via <CONTAINER IP> dev eth0

# Remote settings for my workstation
[Peer]
PublicKey = wx...U=
AllowedIPs = 0.0.0.0/1, 128.0.0.0/1
# Your existing Wireguard server
Endpoint=xx.xx.xx.xx:51820
PersistentKeepalive = 25

```

### Mikrotik Configuration

Set up interface and IP address for the containers

```
/interface bridge
add name=containers

/interface veth
add address=172.17.0.2/24 gateway=172.17.0.1 gateway6="" name=veth1

/interface bridge port
add bridge=containers interface=veth1

/ip address
add address=172.17.0.1/24 interface=containers network=172.17.0.0
```
Set up masquerading for the outgoing traffic and dstnat

```
/ip firewall nat
add action=masquerade chain=srcnat comment="Outgoing NAT for containers" src-address=172.17.0.0/24
/ip firewall nat
add action=dst-nat chain=dstnat comment=amnezia-wg dst-port=51820 protocol=udp to-addresses=172.17.0.2 to-ports=51820
```

Set up mount with the Wireguard configuration

```
/container mounts
add dst=/etc/amnezia/amneziawg/ name=awg_config src=/awg

/container/add cmd=/sbin/init hostname=amnezia interface=veth1 logging=yes mounts=awg_config file=docker-awg-arm7.tar
```

To start the container run

```
/container/start 0
```

To get the container shell

```
/container/shell 0
```

To make it work in tandem with WireGuard you should write the following:
```
iptables-legacy -A FORWARD -i wg1 -o wg0 -j ACCEPT
iptables-legacy -A FORWARD -i wg0 -o wg1 -j ACCEPT
iptables-legacy -t nat -A POSTROUTING -o wg0 -j MASQUERADE
iptables-legacy -t nat -A POSTROUTING -o <INPUT-INTERFACE> -j MASQUERADE
```
wg0 - Amnezia
wg1 - WireGuard
INPUT-INTERFACE - Main container interface
