![Logo](https://github.com/user-attachments/assets/f159b438-0d89-4832-94c5-d66ba6e95000)

## О проекте

В текущем варианте `Amnezia WG` используется в роли клиента который подключается к внешнему серверу `Amnezia WG`. Доступ к контейнеру осуществляется через `WireGuard`, трафик из которого уходит в `Amnezia WG`

### Экспорт Docker Image

Экспорт для ARM v7
```bash
docker buildx build --no-cache --platform linux/arm/v7 --output=type=docker --tag docker-awg:latest . && docker save docker-awg:latest > docker-awg-arm7.tar
```

Экспорт для ARM64
```bash
docker buildx build --no-cache --platform linux/arm64 --output=type=docker --tag docker-awg:latest . && docker save docker-awg:latest > docker-awg-arm64.tar
```

Вы получите `docker-awg-arm<ver>.tar` архив готовый для загрузки на роутер Mikrotik.

### Настройки на Mikrotik

#### Конфигурация `Amnezia WG`

Обязательно создайте папку `awg` с файлом `wg0.conf` внутри.

Пример `wg0.conf`:

```
[Interface]
PrivateKey = UEjfSk...
Address = XX.XX.XX.XX/24
DNS = 1.1.1.1
Jc = ...
Jmin = ...
Jmax = ...
S1 = ...
S2 = ...
H1 = ...
H2 = ...
H3 = ...
H4 = ...

PreUp = ip route add <ENDPOINT IP> via 172.17.0.1 dev eth0
PreUp = ip route add 10.0.0.0/8 via 172.17.0.1 dev eth0
PreUp = ip route add <UR ROUTER NETWORK>/16 via 172.17.0.1 dev eth0

[Peer]
PublicKey = 5h6...
AllowedIPs = 0.0.0.0/1, 128.0.0.0/1
PersistentKeepalive = 0
Endpoint = XXX.XXX.XXX.XXX:XXXXX
```
#### Конфигурация `WireGuard`

Создайте интерфейс `WireGuard`
```
/interface wireguard
add name="toAmneziaWG"
```
Определите IP адрес для интерфейса
```
/ip address 
add address=10.0.0.2/24 network=10.0.0.0 interface="toAmneziaWG"
```
Создайте `Peer` для `WireGuard` на MikroTik
```
/interface wireguard peers
add name="toAmnezia" interface="toAmneziaWG" endpoint-address=172.17.0.2 endpoint-port=51820 allowed-address=0.0.0.0/0 public-key=<PUBLIC KEY интерфейса WireGuard в контейнере>
```
Создайте файл `wg1.conf` в папке `wg` для входящего `WireGuard`

Пример `wg1.conf`
```
[Interface]
ListenPort = 51820
PrivateKey = SLu8a...
Address = 10.0.0.1/24

[Peer]
PublicKey = <PublicKey интерфейса MikroTik>
AllowedIPs = 10.0.0.2/32
```
#### Настройка NAT

Настройте интерфейс и IP-адрес для контейнера

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
Настройте masquerading для исходящего трафика и dstnat

```
/ip firewall nat
add action=masquerade chain=srcnat comment="Outgoing NAT for containers" src-address=172.17.0.0/24
/ip firewall nat
add action=dst-nat chain=dstnat comment=amnezia-wg dst-port=51820 protocol=udp to-addresses=172.17.0.2 to-ports=51820
```

#### Настройка контейнера

Установите mounts для `WireGuard` и `Amnezia WG`
```
/container mounts
add dst=/etc/amnezia/amneziawg/ name=awg_config src=/awg

/container mounts
add dst=/etc/wireguard/ name=wg_config src=/wg

/container/add hostname=amnezia interface=veth1 logging=yes mounts=awg_config file=docker-awg-arm<ver>.tar
```

Запуск контейнера

```
/container/start 0
```

Для того чтобы попасть в терминал контейнера

```
/container/shell 0
```
