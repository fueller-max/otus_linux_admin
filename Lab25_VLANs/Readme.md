# VLAN и LACP

## Цель

Научиться настраивать VLAN и LACP

### Задание

1. В Office1 в тестовой подсетиимеются сервера с доп интерфейсами и адресами:
     
  * testClient1 - 10.10.10.100 
  * testClient2 - 10.10.20.100 
  * testServer1- 10.10.10.1  
  * testServer2- 10.10.20.1 
 
Развести вланами: 
testClient1 <-> testServer1 
testClient2 <-> testServer2 
 
2. Между centralRouter и inetRouter "пробросить" 2 линка (общая inernal сеть) и 
объединить их в бонд, проверить работу c отключением интерфейсов

### Решение

#### 0. Разворачиваем стенд в EVE-NG.

В соответствии со схемой и IP планом из задания разворачиваем стенд в EVE-NG c необходимыми виртуальными машинами c различными ОС (CentOS и Ubuntu):

![](/Lab25_VLANs/pics/lab.jpg)


#### 1. Настройка VLAN

Проведем настройку VLAN 1 для хостов testClient1, testServer1.

Для создания VLAN ов на хостах в CentOS необходимо наличие файла /etc/sysconfig/network-scripts/ifcfg-vlanX вида:

```bash
VLAN=yes   
TYPE=Vlan                          #Тип интерфейса - VLAN
PHYSDEV=ethX                       #Физическое устройство, через которое будет работать VLAN  
VLAN_ID=1                          #Указываем номер VLAN (VLAN_ID)
VLAN_NAME_TYPE=DEV_PLUS_VID_NO_PAD 
PROXY_METHOD=none 
BROWSER_ONLY=no 
BOOTPROTO=none 
IPADDR=xx.xx.xx.xx                 #IP-адрес интерфейса  
PREFIX=24 
NAME=vlan1                         #Указываем имя vlan 
DEVICE=eth1.1                      #Указываем имя подинтерфейса 
ONBOOT=yes
```

Для автоматизации будем использовать шаблонный файл ifcfg-vlan1.j2:

````bash
VLAN=yes 
TYPE=Vlan 
PHYSDEV=ens4 
VLAN_ID={{ vlan_id }} 
VLAN_NAME_TYPE=DEV_PLUS_VID_NO_PAD 
PROXY_METHOD=none 
BROWSER_ONLY=no 
BOOTPROTO=none 
IPADDR={{ vlan_ip }} 
PREFIX=24 
NAME=vlan{{ vlan_id }} 
DEVICE=ens4.{{ vlan_id }} 
ONBOOT=yes
````

Подставляемые данные ( {{}} ) будут забираться для каждого из хостов из файла hosts.ini: 

````bash
[routers]
inetRouter ansible_host=192.168.20.215 ansible_port=22 ansible_private_key_file=~/.ssh/id_rsa bond_ip=192.168.255.1
centralRouter ansible_host=192.168.20.216 ansible_port=22 ansible_private_key_file=~/.ssh/id_rsa bond_ip=192.168.255.2
officeRouter ansible_host=192.168.20.217 ansible_port=22 ansible_private_key_file=~/.ssh/id_rsa

[clients]
testClient1 ansible_host=192.168.20.218 ansible_port=22 ansible_private_key_file=~/.ssh/id_rsa vlan_id=1 vlan_ip=10.10.10.100
testClient2 ansible_host=192.168.20.220 ansible_port=22 ansible_private_key_file=~/.ssh/id_rsa vlan_id=2 vlan_ip=10.10.20.100

[servers]
testServer1 ansible_host=192.168.20.219 ansible_port=22 ansible_private_key_file=~/.ssh/id_rsa vlan_id=1 vlan_ip=10.10.10.1 
testServer2 ansible_host=192.168.20.221 ansible_port=22 ansible_private_key_file=~/.ssh/id_rsa vlan_id=2 vlan_ip=10.10.20.1
````

На хосте officeRouter для организации связности между портами создадим мост br0, куда включим порты, вхдящие в VLAN1. Подключим фильтрацию по номеру Vlan: 


```bash
[user@officeRouter ~]$ ip link add name br0 type bridge vlan_filtering 1
[user@officeRouter ~]$ sudo ip link set ens5 master br0
[user@officeRouter ~]$ sudo ip link set ens6 master br0
[user@officeRouter ~]$ sudo bridge vlan add dev ens5 vid 1
[user@officeRouter ~]$ sudo bridge vlan add dev ens6 vid 1
[user@officeRouter ~]$ ip link set up br0
```
Для постоянного хранения данного конфига и автоматизации создами файлы конфига для интерфейсов с настройками организации моста:

* ifcfg-br0
```bash
DEVICE=br0
TYPE=Bridge
BOOTPROTO=none
ONBOOT=yes
BRIDGE_VLAN_FILTERING=1
```
* ifcfg-ens5
````bash
DEVICE=ens5
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
MASTER=br0
SLAVE=yes
````
* ifcfg-ens6

````bash
DEVICE=ens6
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
MASTER=br0
SLAVE=yes
````

Запускаем плейбуки (все плейбуки находятся в папке ansible) и далее проверяем работу системы:

* На хосте testClient1 проверим наличие sub-интрфейса для Vlan1 ens4.1@ens4:
````bash
[user@testClient1 ~]$ ip a
4: ens4.1@ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 00:50:00:00:04:01 brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.100/24 brd 10.10.10.255 scope global noprefixroute ens4.1
       valid_lft forever preferred_lft forever
    inet6 fe80::250:ff:fe00:401/64 scope link
       valid_lft forever preferred_lft forever
````

* На хосте testServer1 проверим наличие sub-интрфейса для Vlan1 ens4.1@ens4:
```bash
[user@testServer1 ~]$ ip a
4: ens4.1@ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 00:50:00:00:05:01 brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.1/24 brd 10.10.10.255 scope global noprefixroute ens4.1
       valid_lft forever preferred_lft forever
    inet6 fe80::250:ff:fe00:501/64 scope link
       valid_lft forever preferred_lft forever
```

Видим, что на testClient1 и testServer1 создались sub-интрфейсы для Vlan1 на базе физического интерфеса ens4.

Также проверим состояние бриджа br0 на officeRouter:

```bash
[root@officeRouter ~]#  bridge link show
4: ens5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master br0 state forwarding priority 32 cost 100
5: ens6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master br0 state forwarding priority 32 cost 100
```

Проверим сетевую связность между testClient1 и testServer1:

```bash
[user@testClient1 ~]$ ping 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=3.35 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=6.21 ms
```
Видим, что testClient1(10.10.10.100) успешно пингует testServer1 (10.10.10.1).



````bash
[root@officeRouter ~]# ip link add name br1 type bridge vlan_filtering 2
[root@officeRouter ~]# ip link set ens7 master br1
[root@officeRouter ~]# ip link set ens8 master br1
[root@officeRouter ~]# bridge vlan add dev ens7 vid 2
[root@officeRouter ~]# bridge vlan add dev ens8 vid 2
[root@officeRouter ~]# ip link set up br1

````

Настройка testClient2 и testServer2 выполняется аналогичным образом. Разница лишь в том, что здесь в качестве ОС используется Ubuntu, что требует иного подхода к настройке сетевых настроек.

В Ubuntu 24 все сетевые настройки хранятся в файле 50-cloud-init.yaml, который необходимо подготовить для каждого из хоста.

Также будем использовать шаблонизатор для формирования файлов для каждого из хостов.

```bash
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    version: 2
    ethernets:
        ens3:
            dhcp4: false
            addresses: [{{ ansible_host }}/24]
            routes:
              - to: 0.0.0.0/0
                via: 192.168.20.1
            nameservers:
             addresses: [192.168.100.1]
        ens4: {}
    vlans: 
        vlan{{ vlan_id }}: 
          id: {{ vlan_id }} 
          link: ens4
          dhcp4: no 
          addresses: [{{ vlan_ip }}/24]   
```

После работы плейбуков также убеждаемся в корректности настройки интерфесов и проверяем связность:

````bash
user@testClient2:~$ ip a
4: vlan2@ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 00:50:00:00:06:01 brd ff:ff:ff:ff:ff:ff
    inet 10.10.20.100/24 brd 10.10.20.255 scope global vlan2
       valid_lft forever preferred_lft forever
    inet6 fe80::250:ff:fe00:601/64 scope link
       valid_lft forever preferred_lft forever
````

````bash
user@testServer2:~$ ip a
4: vlan2@ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 00:50:00:00:07:01 brd ff:ff:ff:ff:ff:ff
    inet 10.10.20.1/24 brd 10.10.20.255 scope global vlan2
       valid_lft forever preferred_lft forever
    inet6 fe80::250:ff:fe00:701/64 scope link
       valid_lft forever preferred_lft forever

````

````bash
user@testClient2:~$ ping 10.10.20.1
PING 10.10.20.1 (10.10.20.1) 56(84) bytes of data.
64 bytes from 10.10.20.1: icmp_seq=1 ttl=64 time=3.82 ms
64 bytes from 10.10.20.1: icmp_seq=2 ttl=64 time=4.44 ms

````


В данной схеме мы настроили порты на хостах для работы в режиме tagged (или trunk по терминологии Cisco), т.е. трафик из порта будет выходит тегированным. Это можно проверить, посмотрев дамп трафика на порту ens5 officeRouter, который подключен к хосту testClient1:

```bash
[user@officeRouter ~]$ sudo tcpdump -i ens5 -vvv ip -xX -e
dropped privs to tcpdump
tcpdump: listening on ens5, link-type EN10MB (Ethernet), snapshot length 262144 bytes
14:14:43.581903 00:50:00:00:04:01 (oui Unknown) > 00:50:00:00:05:01 (oui Unknown), ethertype 802.1Q (0x8100), length 102: vlan 1, p 0, ethertype IPv4 (0x0800), (tos 0x0, ttl 64, id 8068, offset 0, flags [none], proto ICMP (1), length 84)
    10.10.10.100 > 10.10.10.1: ICMP echo reply, id 2, seq 113, length 64
        0x0000:  4500 0054 1f84 0000 4001 32ad 0a0a 0a64  E..T....@.2....d
        0x0010:  0a0a 0a01 0000 9071 0002 0071 a301 e168  .......q...q...h 
```
Видим, что в заголовке присутствует запись "ethertype 802.1Q", а также номер VLAN: 1. 

Обычно для конечных хостов порты настраиваются untagged (или access по терминологии Cisco), т.е. не имеющими метки Vlan. А тегированный трафик настраивается на портах, где подразумевается хождение трафика из нескольких виланов (например путь свитч - роутер или сервера, к которому должен быть доступ из разных виланов).


#### 2. Настройка Bonding

Проведем настройку статчического агрегатирования в режиме active - backup для хостов centralRouter и inetRouter.

Для настройки необходимо провести настройку физических интерфейсов и создать интерфейс бондинга:

* ifcfg-ens4:

```bash
DEVICE=ens4     # Physical inetrface
ONBOOT=yes      # Switch on  the interface during boot 
BOOTPROTO=none  # No DHCP 
MASTER=bond0    # Interface belongs to bond-interface
SLAVE=yes       #Interface is a slave in bond
NM_CONTROLLED=yes 
USERCTL=no
```
* ifcfg-ens5
```bash
DEVICE=ens5     # Physical inetrface
ONBOOT=yes      # Switch on  the interface during boot 
BOOTPROTO=none  # No DHCP 
MASTER=bond0    # Interface belongs to bond-interface
SLAVE=yes       #Interface is a slave in bond
NM_CONTROLLED=yes 
USERCTL=no
```
* ifcfg-bond0.j2
```bash
DEVICE=bond0 
NAME=bond0 
TYPE=Bond 
BONDING_MASTER=yes 
IPADDR={{ bond_ip }} 
NETMASK=255.255.255.252 
ONBOOT=yes 
BOOTPROTO=static 
BONDING_OPTS="mode=1 miimon=100 fail_over_mac=1" 
NM_CONTROLLED=yes 
USERCTL=no
```

Для конфига ifcfg-bond0 также используем шаблонизатор (меняем IP для каждого из хостов)

Прописываем режим работы бонда:
```bash
BONDING_OPTS="mode=1 miimon=100 fail_over_mac=1"
```
* mode 1: active-backup означает один активный порт, другой в резерве (без балансировки),
* miimon=100: 100 мс время опроса состояния порта
* fail_over_mac=1 используется MAC активного slave.

После настройки ansible`ом, проверяем связность между ротуерами:

```bash
[user@centralRouter ~]$ ping 192.168.255.1
PING 192.168.255.1 (192.168.255.1) 56(84) bytes of data.
64 bytes from 192.168.255.1: icmp_seq=1 ttl=64 time=1.89 ms
64 bytes from 192.168.255.1: icmp_seq=2 ttl=64 time=1.70 ms
64 bytes from 192.168.255.1: icmp_seq=3 ttl=64 time=1.32 ms
```

Проверяем через какой интерфейс(ens4, ens5) реально проходит трафик на inetRouter:

```bash
[user@inetRouter ~]$ sudo tcpdump -i ens4
dropped privs to tcpdump
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on ens4, link-type EN10MB (Ethernet), snapshot length 262144 bytes
16:34:15.130664 IP 192.168.255.2 > inetRouter: ICMP echo request, id 1, seq 60, length 64
16:34:15.130725 IP inetRouter > 192.168.255.2: ICMP echo reply, id 1, seq 60, length 64
```

```bash
[user@inetRouter ~]$ sudo tcpdump -i ens5
[sudo] password for user:
dropped privs to tcpdump
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on ens5, link-type EN10MB (Ethernet), snapshot length 262144 bytes
```
Видим, что трафик проходит через ens4, а ens5 находится в режиме горячего резерва.

Имитируем отказ интерфейса ens4:

```bash
[user@inetRouter ~]$ sudo ip link set down ens4
```

Смотрим состояние бонда:

````bash
[user@inetRouter ~]$ cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v5.14.0-168.el9.x86_64

Bonding Mode: fault-tolerance (active-backup) (fail_over_mac active)
Primary Slave: None
Currently Active Slave: ens5
MII Status: up
MII Polling Interval (ms): 100
Up Delay (ms): 0
Down Delay (ms): 0
Peer Notification Delay (ms): 0

Slave Interface: ens4
MII Status: down
Speed: Unknown
Duplex: Unknown
Link Failure Count: 1
Permanent HW addr: 00:50:00:00:01:01
Slave queue ID: 0

Slave Interface: ens5
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 0
Permanent HW addr: 00:50:00:00:01:02
Slave queue ID: 0
````

Видим, что теперь активным портом стал ens5.
И через него теперь идет трафик:

````bash
[user@inetRouter ~]$ sudo tcpdump -i ens5
dropped privs to tcpdump
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on ens5, link-type EN10MB (Ethernet), snapshot length 262144 bytes
16:58:24.536837 IP 192.168.255.2 > inetRouter: ICMP echo request, id 10, seq 82, length 64
16:58:24.536882 IP inetRouter > 192.168.255.2: ICMP echo reply, id 10, seq 82, length 64
16:58:25.583756 IP 192.168.255.2 > inetRouter: ICMP echo request, id 10, seq 83, length 64
````

Таким образом, произошло автоматическое переключение канала без потери связности.

Стоит заметить, что статическое агрегатирование имеет свои недостатки и хорошо реагирует на физическое отключение канала. Однако в случае потери связности из-за проблем на промежуточном устройстве (если оно есть) такая схема может не отработать. Рекомендуется применять режим работы LACP, когда при резервировании проверяется не только состояние собственного порта, но и реальная доступность партнера.



