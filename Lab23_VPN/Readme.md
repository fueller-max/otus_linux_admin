# VPN

## Цель

Научиться настраивать VPN-сервер в Linux-based системах.

### Задание

1. Настроить VPN между двумя ВМ в tun/tap режимах, замерить скорость в туннелях, сделать вывод об отличающихся показателях
2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на ВМ

### Решение


#### 1. Настройка VPN между двумя ВМ в tun/tap режимах, замеры скорости в туннелях.

В данном пункте, для аутентификации упрощения используется PSK (Preshared Key). Стоит отметить, что данный подход на сегодняшний момент считается устаревшим и небезопасным. Более того, в современных версиях OpenVPN (начиная с 2.6) данный метод помечается как "deprecated" или не поддерживается вовсе (с версии 2.8), также данный метод не поддерживается современными версиями OpenSSL, входящих в состав дистрибутивов Linux. Для данной лабы будем использовать версию дистрибутива 22.04, с установкой версии OpenVPN 2.5.11, где использование PSK еще  возможно без ограничений.

Разворачиваем две ВМ в EVE-NG, которые будем использовать для настройки VPN туннеля.

![](/Lab23_VPN/pics/TUN_TAP_VPN.jpg)


Делаем первичную настройку с установкой OpenVPN и iperf3 на хосты:

```bash
---
- name: Basic setup of VPN server/client
  hosts: vpn_server 
  become: yes

  tasks:
  - name: Update package list
    apt:
       update_cache: yes

  - name: Install openvpn, iperf3
    apt:
        name:
          - openvpn
          - iperf3
        state: present
```

Для дальнейшей настройки сервера будем использовать следующий конфиг:

```bash
dev tap 
ifconfig 10.10.10.1 255.255.255.0 
topology subnet 
secret /etc/openvpn/static.key
data-ciphers-fallback BF-CBC
comp-lzo 
status /var/log/openvpn-status.log 
log /var/log/openvpn.log 
verb 3
```
В данном конфиге в качестве интерфейса используется TAP - L2 интерфейс, создающий сетевой мост, задаем IP адрес хоста; в качесте аутетификации используется PSK (secret ...)


На клиенте используем аналогичный конфиг:

```bash
dev tap 
remote 192.168.20.208 
ifconfig 10.10.10.2 255.255.255.0 
topology subnet 
route 192.168.20.0 255.255.255.0 
secret /etc/openvpn/static.key 
comp-lzo 
status /var/log/openvpn-status.log 
log /var/log/openvpn.log 
verb 3
```

Прогоняем настроечный плейбук на сервере:

```bash
---
- name: Setup OpenVPN on server
  hosts: vpn_server
  become: yes
  
  tasks:

  - name: Ensure the OpenVPN directory exists
    file:
      path: /etc/openvpn
      state: directory

  - name: Generate OpenVPN  secret key
    command: openvpn --genkey secret static.key
    register: key_generation_result    
  
  - name: copy secret key file
    command: cp static.key /etc/openvpn/
  
  - name: copy server.conf file
    template:
        src: server/server.conf
        dest: /etc/openvpn/
        mode: 0644 

  - name: copy service unit file file
    template:
        src: server/openvpn@server
        dest: /etc/systemd/system/
        mode: 0644 

  - name: Start OpenVPN service
    systemd:
        name: openvpn@server
        state: started
        enabled: yes
```

После убеждаемся, что OpenVPN стартовал на сервере:


```bash
user@ubuntu22-server:~$ systemctl status openvpn@server
● openvpn@server.service - OpenVPN connection to server
     Loaded: loaded (/lib/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2025-09-22 08:10:54 UTC; 29s ago
       Docs: man:openvpn(8)
             https://community.openvpn.net/openvpn/wiki/Openvpn24ManPage
             https://community.openvpn.net/openvpn/wiki/HOWTO
   Main PID: 4594 (openvpn)
     Status: "Pre-connection initialization successful"
      Tasks: 1 (limit: 4579)
     Memory: 1.6M
        CPU: 21ms
     CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
             └─4594 /usr/sbin/openvpn --daemon ovpn-server --status /run/openvpn/server.status 10 --cd /etc/openvpn --script-security 2 --config /e>

Sep 22 08:10:54 ubuntu22-server systemd[1]: Starting OpenVPN connection to server...
Sep 22 08:10:54 ubuntu22-server systemd[1]: Started OpenVPN connection to server.

```

Аналогичные действия делаем на клиенте и убеждаемся, что OpenVPN стартовал на клиенте, а также проверим пинг до сервера:

```bash

root@ubuntu22-server:/home/user# systemctl status openvpn@client
● openvpn@client.service - OpenVPN connection to client
     Loaded: loaded (/lib/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2025-09-22 09:00:50 UTC; 8s ago
       Docs: man:openvpn(8)
             https://community.openvpn.net/openvpn/wiki/Openvpn24ManPage
             https://community.openvpn.net/openvpn/wiki/HOWTO
   Main PID: 4908 (openvpn)
     Status: "Pre-connection initialization successful"
      Tasks: 1 (limit: 4579)
     Memory: 1.6M
        CPU: 19ms
     CGroup: /system.slice/system-openvpn.slice/openvpn@client.service
             └─4908 /usr/sbin/openvpn --daemon ovpn-client --status /run/openvpn/client.status 10 --cd /etc/openvpn --script-security 2 --config /e>

Sep 22 09:00:50 ubuntu22-server systemd[1]: Starting OpenVPN connection to client...
Sep 22 09:00:50 ubuntu22-server ovpn-client[4908]: WARNING: Compression for receiving enabled. Compression has been used in the past to break encry>
Sep 22 09:00:50 ubuntu22-server systemd[1]: Started OpenVPN connection to client.
lines 1-17/17 (END)

root@ubuntu22-server:/home/user# ping 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=1.94 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=5.65 ms
```
Далее проверим скорость работы туннеля с использованием tap интерфейса:

````bash
root@ubuntu22-server:/home/user# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 38706 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  97.3 MBytes   163 Mbits/sec    0   3.15 MBytes
[  5]   5.00-10.00  sec   124 MBytes   208 Mbits/sec  2526    249 KBytes
[  5]  10.00-15.00  sec   124 MBytes   208 Mbits/sec    0    485 KBytes
[  5]  15.00-20.00  sec   125 MBytes   210 Mbits/sec   57    332 KBytes
[  5]  20.00-25.00  sec   126 MBytes   212 Mbits/sec   65    108 KBytes
[  5]  25.00-30.00  sec   126 MBytes   212 Mbits/sec   15    303 KBytes
[  5]  30.00-35.00  sec   122 MBytes   206 Mbits/sec  117    239 KBytes
[  5]  35.00-40.00  sec   126 MBytes   212 Mbits/sec   28    273 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.00  sec   971 MBytes   204 Mbits/sec  2808             sender
[  5]   0.00-40.01  sec   968 MBytes   203 Mbits/sec                  receiver

iperf Done.
````

После замеров проводом перенастройку сервера/клиента на использование интерфейса tun - L3 интерфейса.

Разница в конфигруации заключается в изменении директивы dev:

```bash
dev tun
```
После конфигруации (плейбуки приложены) выполним также проверку скорости работы туннеля, теперь с использованием интерфейса tun:

````bash
root@ubuntu22-server:/home/user# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 38720 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec   132 MBytes   222 Mbits/sec  632    370 KBytes
[  5]   5.00-10.00  sec   129 MBytes   216 Mbits/sec   28    324 KBytes
[  5]  10.00-15.00  sec   121 MBytes   203 Mbits/sec  124    365 KBytes
[  5]  15.00-20.00  sec   116 MBytes   195 Mbits/sec  133    279 KBytes
[  5]  20.00-25.00  sec   128 MBytes   214 Mbits/sec   88    320 KBytes
[  5]  25.00-30.00  sec   128 MBytes   214 Mbits/sec   38    309 KBytes
[  5]  30.00-35.00  sec   130 MBytes   218 Mbits/sec   48    275 KBytes
[  5]  35.00-40.00  sec   128 MBytes   214 Mbits/sec    8    453 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.00  sec  1011 MBytes   212 Mbits/sec  1099             sender
[  5]   0.00-40.01  sec  1008 MBytes   211 Mbits/sec                  receiver

````

Выводы:

* Как видим, скорость работы с интерфейсом tun чуть выше (хотя и весьма незначительно). Теоретически, скорость работы tun выше, чем tap по той причине, что при использовании tun выполняется только формирование IP пакета (L3 уровень), а при использовании tap формируется весь Ethernet фрейм (L2 уровень), что несет определенный оверхед.

* В целом, использование tun предпочтительнее в использовании. Следует использовать tun всегда, когда нет причин явно использовать tap.

* Причинами использовать tap может быть требование "прозрачного" VPN, когда сегменты одной подсети могут быть объеденены в одну общую сеть через VPN туннель за счет бриджа L2 уровня. Сам туннель при этом будет прозрачным для хостов, не требующий доп. маршрутизации.



#### 2. Настройка RAS на базе OpenVPN с клиентскими сертификатами, настройка доступа в сеть через RAS

Поставим задачу обеспечить доступ к сети 172.12.10.0.24 через RAS сервер, за которым находится данная сеть для клиентов RAS сервера, использующую сеть 192.168.20.0/24 как показано на рисунке:

![](/Lab23_VPN/pics/RAS_VPN.jpg)

Настройку RAS сервера выполним в два этапа с ипользованием Ansible:

```bash
---
- name: Basic setup of VPN server using PKI
  hosts: ras_server 
  become: yes

  tasks:
  - name: Update package list
    apt:
       update_cache: yes

  - name: Install openvpn, easy-rsa
    apt:
        name:
          - openvpn
          - easy-rsa
        state: present

  - name: Change directory to /etc/openvpn and initialize PKI
    shell: |
        cd /etc/openvpn
        /usr/share/easy-rsa/easyrsa init-pki
    args:
        chdir: /etc/openvpn  # Change directory to /etc/openvpn 

  - name: Generate a request for the server certificate
    shell: |
        echo 'rasvpn' | /usr/share/easy-rsa/easyrsa gen-req server nopass

  - name: Create  Certificate Authority. 
    shell: |
        /usr/share/easy-rsa/easyrsa build-ca   

  - name: Sign the server certificate request
    shell: |
        echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req server server
    
  - name: Generate Diffie-Hellman parameters
    shell: /usr/share/easy-rsa/easyrsa gen-dh
          
  - name: Generate a secret key for the CA
    shell: openvpn --genkey secret ca.key
    
  - name: Generate a request for the client certificate
    shell: |
        echo 'client' | /usr/share/easy-rsa/easyrsa gen-req client nopass
    
  - name: Sign the client certificate request
    shell: |
        echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req client client
```
Здесь мы последовательно проводим инциализацию PKI (Public Key Infrastructure), генерируем сертификаты и ключи для самого сервера, а также ключи для клиента, которые потом нужно будет перенести на клиентскую машину.

Далее запускаем настройку сервера, используя следующий конфиг для сервера:

````bash
port 1207
proto udp
dev tun
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/server.crt
key /etc/openvpn/pki/private/server.key
dh /etc/openvpn/pki/dh.pem
server 10.10.11.0 255.255.255.0
route-gateway 10.10.11.1
push "route 172.12.10.0 255.255.255.0"
ifconfig-pool-persist ipp.txt
client-to-client
client-config-dir /etc/openvpn/client
keepalive 10 120
comp-lzo
persist-key
persist-tun
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3
````

Основные моменты здесь:

* Используем работу с PKI - указываем пути до всех необходимых файлов
* Сеть VPN 10.10.11.0/24
* Пушим сеть 172.12.10.0 клиенту с роутом через туннель

Запускаем плейбук и проверяем, что сервер запустился и создался TUN интерфейс с 
PtP(Point-to-Point) соединением:

````bash
root@ubuntu22-server:/etc/openvpn# systemctl status openvpn@server.service
● openvpn@server.service - OpenVPN connection to server
     Loaded: loaded (/lib/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2025-09-22 11:36:12 UTC; 12s ago
       Docs: man:openvpn(8)
             https://community.openvpn.net/openvpn/wiki/Openvpn24ManPage
             https://community.openvpn.net/openvpn/wiki/HOWTO
   Main PID: 5186 (openvpn)
     Status: "Initialization Sequence Completed"
      Tasks: 1 (limit: 4579)
     Memory: 1.8M
        CPU: 15ms
     CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
             └─5186 /usr/sbin/openvpn --daemon ovpn-server --status /run/openvpn/server.status 10 --cd /etc/openvpn --script-security 2 --config /e>

Sep 22 11:36:12 ubuntu22-server systemd[1]: Starting OpenVPN connection to server...
Sep 22 11:36:12 ubuntu22-server ovpn-server[5186]: WARNING: Compression for receiving enabled. Compression has been used in the past to break encry>
Sep 22 11:36:12 ubuntu22-server systemd[1]: Started OpenVPN connection to server.
lines 1-17/17 (END)

root@ubuntu22-server:/etc/openvpn# ip a

4: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none
    inet 10.10.11.1 peer 10.10.11.2/32 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::886b:4231:222a:6fd6/64 scope link stable-privacy
       valid_lft forever preferred_lft forever

````


Настройку RAS клиента выполним в ручном режиме.

* Устанавливаем OpenVPN и easy-rsa:

````bash
user@ubuntu22-server:~$ sudo apt update
user@ubuntu22-server:~$ sudo apt install openvpn easy-rsa

user@ubuntu22-server:~$ cd /etc/openvpn
user@ubuntu22-server:/etc/openvpn$ sudo /usr/share/easy-rsa/easyrsa init-pki

````
* Берем необходиыме файлы PKI, сгенерированные на сервере выше и копируем их в /etc/openvpn:

````bash
/etc/openvpn/pki/ca.crt 
/etc/openvpn/pki/issued/client.crt 
/etc/openvpn/pki/private/client.key
````

* Конфиг для Openvpn используем следующий:

````bash
dev tun
proto udp
remote 192.168.20.205 1207
client
resolv-retry infinite
remote-cert-tls server
ca ./ca.crt
cert ./client.crt
key ./client.key
persist-key
persist-tun
comp-lzo
verb 3
````

* Здесь мы указываем адрес сервера ("белый IP" в данном случае), пути до PKI файлов. Маршрутная информация ожидаем, что придет от сервера.

* Запускаем OpenVPN c данным конфигом:

````bash
user@ubuntu22-server:/etc/openvpn$ openvpn --config client.conf
````

* Cервер запускаем и далее проверяем, что интерфейс TUN создался:

```bash
user@ubuntu22-server:/etc/openvpn$ ip a

3: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none
    inet 10.10.11.6 peer 10.10.11.5/32 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::a0cd:7351:102d:d859/64 scope link stable-privacy
       valid_lft forever preferred_lft forever

```

* Смотрим маршрутизацию на клиенте:

```bash
user@ubuntu22-server:~$ ip r
default via 192.168.20.1 dev ens3 proto static
10.10.11.5 dev tun0 proto kernel scope link src 10.10.11.6
172.12.10.0/24 via 10.10.11.5 dev tun0
192.168.20.0/24 dev ens3 proto kernel scope link src 192.168.20.206
```
* Как и ожидалось  маршрут до сети 172.12.10.0/24 появился и она доступна через туннель со входом 10.10.11.6.

* Пробуем пинг хоста 172.12.10.2

````bash
user@ubuntu22-server:~$ ping 172.12.10.2
PING 172.12.10.2 (172.12.10.2) 56(84) bytes of data.
64 bytes from 172.12.10.2: icmp_seq=1 ttl=63 time=1.67 ms
64 bytes from 172.12.10.2: icmp_seq=2 ttl=63 time=4.55 ms
````

* Проверим маршрут прохождения трафика и убеждаемся, что трафик до сети 172.12.10.0 идет через VPN туннель:

```bash
user@ubuntu22-server:~$ traceroute 172.12.10.2
traceroute to 172.12.10.2 (172.12.10.2), 30 hops max, 60 byte packets
 1  10.10.11.1 (10.10.11.1)  1.436 ms  1.391 ms  1.365 ms
 2  172-12-10-2.lightspeed.mssnks.sbcglobal.net (172.12.10.2)  2.927 ms  2.692 ms  2.491 ms
```

Таким образом, мы обеспечили доступ к  внутренней сети через VPN туннель, работающий поверх "открытой сети" для хоста (клиента RAS сервера.) 

