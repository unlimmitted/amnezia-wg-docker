## About The Project
Mikrotik compatible Docker image to run Amnezia WG on Mikrotik routers. As of now, support Arm v7 boards

## About The Project
This is a highly experimental attempt to run [Amnezia-WG](https://github.com/amnezia-vpn/amnezia-wg) on a Mikrotik router.

### Export Docker Image

Export to ARM64
```shell
docker buildx build --no-cache --platform linux/arm64 --output=type=docker --tag docker-awg:latest . && docker save docker-awg:latest > docker-awg-arm64.tar
```

Export to ARM V7
```shell
docker buildx build --no-cache --platform linux/arm/v7 --output=type=docker --tag docker-awg:latest . && docker save docker-awg:latest > docker-awg-arm7.tar
```

You will get the `docker-awg-arm<ver>.tar` archive ready to upload to the Mikrotik router.

### Running locally

Make sure to create a `awg` folder with the `wg0.conf` file.

Example `wg0.conf`:

```
[Interface]
PrivateKey = gG...Y3s=
Address = 10.0.0.1/32
ListenPort = 51820
Jc = 3
Jmin = 100
Jmax = 1000
# Parameters below will not work with the existing WireGuarg implementation.
# Use if your peer running Amnesia-WG
# S1 = 324
# S2 = 452
# H1 = 25

# IP masquerading
PreUp = ip route add <ENDPOINT IP> via 172.17.0.1 dev eth0
PreUp = ip route add 10.0.0.0/8 via 172.17.0.1 dev eth0
PreUp = ip route add <UR ROUTER NETWORK>/16 via 172.17.0.1 dev eth0

# Remote settings for my workstation
[Peer]
PublicKey = wx...U=
AllowedIPs = 0.0.0.0/1, 128.0.0.0/1
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

/container/add hostname=amnezia interface=veth1 logging=yes mounts=awg_config file=docker-awg-arm7.tar
```

To start the container run

```
/container/start 0
```

To get the container shell

```
/container/shell 0
```