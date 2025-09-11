# OSPF

## Цель

Научится настраивать протокол OSPF в Linux-based системах

### Задание

1. Развернуть 3 виртуальные машины
2. Объединить их разными vlan
 - настроить OSPF между машинами на базе FRR;
3. Изобразить ассиметричный роутинг;
  - сделать один из линков "дорогим", но что бы при этом роутинг был симметричным.


### Решение

#### 1. Разворачиваем сетевой стенд

Как и в прошлом задании задании стенд развернем на базе системы виртуализации EVE-NG.

Имеем 3 роутера на базе Ubuntu 24. Между роутерами имеются линки с VLANми:

* 10.0.10.0/30  (r1-r2)
* 10.0.11.0/30  (r2-r3)
* 10.0.12.0/30  (r3-r1)

Также у каждого роутера имеется внешная сеть NetXX сVLANми:

* 172.10.10.0/24  (r1)
* 172.10.10.0/24  (r2)
* 172.10.10.0/24  (r3)

Также в топологии имеется сеть "Bridge", преднзначенная для доступа извне к каждому роутеру, доступа  Ansible (находится в сегменте за пределами стенда). 

![](/Lab22_OSPF/pics/EVE_Topology.jpg)

Задача настроить динамическую маршрутизацию, чтобы сети NetXX имели сетевую связность.

#### 1.2 Provisioning

Выполняем предварительную подготовку роутеров 1-3 с установкой необходимых общих утилит для работы с сетью. Используем Ansible playbook provision.yaml. Все playbook и находятся в отдельной папке ansible/playbooks.

````bash
ansible@ansible:~/PROJECTS/OSPF$ ansible-playbook playbooks/provision.yaml

PLAY [Make provisionig of all routers] ****************************************************************************************************************

TASK [Gathering Facts] ********************************************************************************************************************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [install base tools] *****************************************************************************************************************************
changed: [router2]
changed: [router1]
changed: [router3]

PLAY RECAP ********************************************************************************************************************************************
router1                    : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
router2                    : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
router3                    : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

````


#### 2. Настройка OSPF
#### 2.1 Ручная настройка OSPF

Для начала выполним настройку OSPF вручную, чтобы проверить настройки и убедиться в работоспобности решения.

* Останаливаем работу ufw

````bash
root@router1:~# systemctl stop ufw
root@router1:~# systemctl disable ufw
Synchronizing state of ufw.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install disable ufw
Removed "/etc/systemd/system/multi-user.target.wants/ufw.service".

````
* Добавляем gpg ключ

````bash
root@router1:~# curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -
````
* Добавляем репозиторий c пакетом FRR
````bash
root@router1:~# echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) frr-stable > /etc/apt/sources.list.d/frr.list
````
* Обновляем пакеты и устанавливаем FRR:
````bash
root@router1:~# sudo apt update
root@router1:~# sudo apt install frr frr-pythontools
````
* Разрешаем (включаем) маршрутизацию транзитных пакетов:

````bash
root@router1:~# sysctl net.ipv4.conf.all.forwarding=1
````
* Включаем демон ospfd в FRR
````bash
root@router1:~# nano /etc/frr/daemons
#################
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
##################
````

````bash
root@router1:~# ip a | grep "inet "
    inet 127.0.0.1/8 scope host lo
    inet 192.168.20.201/24 brd 192.168.20.255 scope global ens3
    inet 10.0.12.1/30 brd 10.0.12.3 scope global ens4
    inet 10.0.10.1/30 brd 10.0.10.3 scope global ens5
    inet 172.10.10.2/24 brd 172.10.10.255 scope global ens6

````
Далее, используя оболочку vtysh выполним настройку OSPF cisco-like командами.
````bash
root@router1:~# vtysh

Hello, this is FRRouting (version 10.4.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router1# show interface brief
Interface       Status  VRF             Addresses
---------       ------  ---             ---------
ens3            up      default         192.168.20.201/24
                                        fe80::250:ff:fe00:100/64
ens4            up      default         10.0.12.1/30
                                        fe80::250:ff:fe00:101/64
ens5            up      default         10.0.10.1/30
                                        fe80::250:ff:fe00:102/64
ens6            up      default         172.10.10.2/24
                                        fe80::250:ff:fe00:103/64
ens7            down    default
lo              up      default
````

````bash
router1(config)# router ospf
router1(config-router)# network 10.0.12.1/30 area 0
router1(config-router)# network 10.0.10.1/30 area 0
router1(config-router)# network 172.10.10.2/24 area 0
router1(config-router)# router-id 1.1.1.1
router1(config-router)# neighbor 10.0.12.2
router1(config-router)# neighbor 10.0.10.2
````

В данных настройках для router1 мы: 
* активировали OSPF
* сделали анонс сетей 10.0.0.x/30, а также 172.10.10.0/24
* задали router-id 1.1.1.1 
* задали соседей

На роутерах 2-3 выполняем аналогичные действия, с коррекцией сетей.


Далее, после настройки всех трех роутеров проверяем состояние OSPF:

Состояние:

````bash
router1# sh ip ospf neighbor

Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
1.1.1.3           1 Full/Backup     34.409s           39.695s 10.0.12.2       ens4:10.0.12.1                       0     0     0
1.1.1.2           1 Full/DR         30m06s            33.416s 10.0.10.2       ens5:10.0.10.1                       0     0     0

router2# sh ip ospf neighbor

Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
1.1.1.3           1 Full/Backup     32.104s           33.196s 10.0.11.1       ens4:10.0.11.2                       0     0     0
1.1.1.1           1 Full/Backup     30m03s            36.920s 10.0.10.1       ens5:10.0.10.2                       0     0     0

router3# sh ip ospf neighbor

Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
1.1.1.1           1 Full/DR         27.758s           32.231s 10.0.12.1       ens4:10.0.12.2                       0     0     0
1.1.1.2           1 Full/DR         28.961s           31.038s 10.0.11.2       ens5:10.0.11.1                       0     0     0
````

Видим, что все три роутера подняли соседство, а значит базовые настройки выполнены верно и роутеры готовы обмениваться маршрутной информацией.

Проверим маршруты OSPF на каждом из роутеров:

````bash

router1# sh ip route ospf

O   10.0.10.0/30 [110/10] is directly connected, ens5, weight 1, 00:42:20
O>* 10.0.11.0/30 [110/20] via 10.0.10.2, ens5, weight 1, 00:04:27
  *                       via 10.0.12.2, ens4, weight 1, 00:04:27
O   10.0.12.0/30 [110/10] is directly connected, ens4, weight 1, 00:04:52
O   172.10.10.0/24 [110/10] is directly connected, ens6, weight 1, 00:41:47
O>* 172.10.20.0/24 [110/20] via 10.0.10.2, ens5, weight 1, 00:33:59
O>* 172.10.30.0/24 [110/20] via 10.0.12.2, ens4, weight 1, 00:04:27


router2#  sh ip route ospf

O   10.0.10.0/30 [110/10] is directly connected, ens5, weight 1, 00:34:04
O   10.0.11.0/30 [110/10] is directly connected, ens4, weight 1, 00:34:13
O>* 10.0.12.0/30 [110/20] via 10.0.10.1, ens5, weight 1, 00:03:52
  *                       via 10.0.11.1, ens4, weight 1, 00:03:52
O>* 172.10.10.0/24 [110/20] via 10.0.10.1, ens5, weight 1, 00:33:19
O   172.10.20.0/24 [110/10] is directly connected, ens6, weight 1, 00:33:55
O>* 172.10.30.0/24 [110/20] via 10.0.11.1, ens4, weight 1, 00:03:52

router3# sh ip route ospf

O>* 10.0.10.0/30 [110/20] via 10.0.11.2, ens5, weight 1, 00:01:52
  *                       via 10.0.12.1, ens4, weight 1, 00:01:52
O   10.0.11.0/30 [110/10] is directly connected, ens5, weight 1, 00:01:58
O   10.0.12.0/30 [110/10] is directly connected, ens4, weight 1, 00:01:58
O>* 172.10.10.0/24 [110/20] via 10.0.12.1, ens4, weight 1, 00:01:52
O>* 172.10.20.0/24 [110/20] via 10.0.11.2, ens5, weight 1, 00:01:52
O   172.10.30.0/24 [110/10] is directly connected, ens6, weight 1, 00:01:58

````
Как видно, роутеры успешно передали друг другу маршруты и все сети доступны друг другу через соответствующие интерфейсы.

Далее, проверим из сети Net10 доступность хостов в сетях Net20 и Net30:

````bash

VPCS> ping 172.10.20.1
84 bytes from 172.10.20.1 icmp_seq=1 ttl=62 time=1.988 ms
84 bytes from 172.10.20.1 icmp_seq=2 ttl=62 time=1.143 ms

VPCS> ping 172.10.30.1
84 bytes from 172.10.30.1 icmp_seq=1 ttl=62 time=2.828 ms
84 bytes from 172.10.30.1 icmp_seq=2 ttl=62 time=1.401 ms
````
Видим, что сетевая связность обеспечена.

Также можно вывести трейс и проверить пути:

````bash
VPCS> trace 172.10.20.1
trace to 172.10.20.1, 8 hops max, press Ctrl+C to stop
 1   172.10.10.2   0.361 ms  0.193 ms  0.215 ms
 2   10.0.10.2   0.951 ms  0.523 ms  0.510 ms
 3   *172.10.20.1   2.315 ms (ICMP type:3, code:3, Destination port unreachable)

VPCS> trace 172.10.30.1
trace to 172.10.30.1, 8 hops max, press Ctrl+C to stop
 1   172.10.10.2   0.521 ms  0.300 ms  0.172 ms
 2   10.0.12.2   0.998 ms  0.524 ms  0.452 ms
 3   *172.10.30.1   0.810 ms (ICMP type:3, code:3, Destination port unreachable)
````

Видно, что путь Net10-Net20 лежит через router1(172.10.10.2) и router2(10.0.10.2), а путь Net10-Net30 лежит через router1(172.10.10.2) и router3(10.0.12.2). Как и ожидалось.



#### 2.1 Настройка OSPF с использованием Ansible

Для настройки OSPF необходимо подготовить и скоприровать на хост два файла:
* deamons
* frr.conf

Первый имеет фиксированные данные и подготовлен статически, а frr.conf должен формироваться динамически, т.к. содержит данные, специфичные для каждого из роутера.

Для динамического формирования frr.conf будет использовать шаблонизатором jinj2.

Создаем файл frr.conf.j2 на базе frr.conf, в котором вводим переменные для инстанцирования:

````bash
# default to using syslog. /etc/rsyslog.d/45-frr.conf places the log in
# /var/log/frr/frr.log
#
# Note:
# FRR's configuration shell, vtysh, dynamically edits the live, in-memory
# configuration while FRR is running. When instructed, vtysh will persist the
# live configuration to this file, overwriting its contents. If you want to
# avoid this, you can edit this file manually before starting FRR, or instruct
# vtysh to write configuration to a different file.
log syslog informational

hostname {{ ansible_hostname }}
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
!
!
router ospf
router-id 1.1.1.{{ ansible_hostname | regex_search('\d+') | first }}
!
{% set router_id = 'router' + ansible_hostname | regex_search('\d+') | first %}
{% set router_nets = router_networks[router_id] %}
{% for network_ in router_nets %}
network {{ network_ }} area 0
{% endfor %}
!
{% set router_nei = router_neighbors[router_id] %}
{% for nei in router_nei %}
neighbor {{ nei }}
{% endfor %}
````

Суть подохода заключается в том, что Ansible получает имя хоста ansible_hostname в видe router1, router2... и используя индекс роутера (1,2,3) заполняет id роутера для OSPF и сети, которые заполнены в отдельном файле router_vars.yaml:

````
router_networks:       #Networks to be announced over OSPF
  router1:
    - '10.0.12.1/30'
    - '10.0.10.1/30'
    - '172.10.10.2/24'  

  router2:
    - '10.0.11.2/30'
    - '10.0.10.2/30'
    - '172.10.20.2/24' 

  router3:
    - '10.0.12.2/30'
    - '10.0.11.1/30'
    - '172.10.30.2/24' 


router_neighbors:      #OSPF neighbors
  router1:
    - '10.0.12.2'
    - '10.0.10.2'                        

  router2:
    - '10.0.11.1'
    - '10.0.10.1'                       

  router3:
    - '10.0.12.1'
    - '10.0.11.2'    
````

Сам playbook находится в папке ansible/playbooks/ospf.yaml.

Прогоняем playbook:

```bash
ansible@ansible:~/PROJECTS/OSPF$ ansible-playbook  playbooks/ospf.yaml

PLAY [Install and setup OSPF using FRR router] ********************************************************************************************************

TASK [Gathering Facts] ********************************************************************************************************************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [disable ufw service] ****************************************************************************************************************************
ok: [router1]
ok: [router3]
ok: [router2]

TASK [add gpg frrouting.org] **************************************************************************************************************************
ok: [router1]
ok: [router3]
ok: [router2]

TASK [add frr repo] ***********************************************************************************************************************************
ok: [router3]
ok: [router1]
ok: [router2]

TASK [install FRR packages] ***************************************************************************************************************************
ok: [router2]
ok: [router3]
ok: [router1]

TASK [set up forward packages across routers] *********************************************************************************************************
changed: [router1]
changed: [router2]
changed: [router3]

TASK [base set up OSPF] *******************************************************************************************************************************
changed: [router1]
changed: [router3]
changed: [router2]

TASK [set up OSPF] ************************************************************************************************************************************
changed: [router2]
changed: [router3]
ok: [router1]

TASK [restart FRR] ************************************************************************************************************************************
changed: [router2]
changed: [router3]
changed: [router1]

PLAY RECAP ********************************************************************************************************************************************
router1                    : ok=9    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
router2                    : ok=9    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
router3                    : ok=9    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

```

После работы Ansible проверим файл конфигурации на router1 еtc/frr/frr.conf:

````bash

# default to using syslog. /etc/rsyslog.d/45-frr.conf places the log in
# /var/log/frr/frr.log
#
# Note:
# FRR's configuration shell, vtysh, dynamically edits the live, in-memory
# configuration while FRR is running. When instructed, vtysh will persist the
# live configuration to this file, overwriting its contents. If you want to
# avoid this, you can edit this file manually before starting FRR, or instruct
# vtysh to write configuration to a different file.
log syslog informational

hostname router1
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
!
!
router ospf
router-id 1.1.1.1
!
network 10.0.12.1/30 area 0
network 10.0.10.1/30 area 0
network 172.10.10.2/24 area 0
!
neighbor 10.0.12.2
neighbor 10.0.10.2
````

Файл сформировался и содержит всю необходимую информацию для работы OSPF.

Проверям также, что конфигруация загружена в актуальную:

````bash
router1# sh run
Building configuration...

Current configuration:
!
frr version 10.4.1
frr defaults traditional
hostname router1
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
router ospf
 ospf router-id 1.1.1.1
 network 10.0.10.0/30 area 0
 network 10.0.12.0/30 area 0
 network 172.10.10.0/24 area 0
 neighbor 10.0.10.2
 neighbor 10.0.12.2
exit
!
````
Проверяем маршруты и видим, что маршруты передались, что говорит о том, что OSPF работает.

````bash
router1# sh ip route ospf

IPv4 unicast VRF default:
O   10.0.10.0/30 [110/10] is directly connected, ens5, weight 1, 00:01:00
O>* 10.0.11.0/30 [110/20] via 10.0.10.2, ens5, weight 1, 00:00:06
  *                       via 10.0.12.2, ens4, weight 1, 00:00:06
O   10.0.12.0/30 [110/10] is directly connected, ens4, weight 1, 00:00:11
O   172.10.10.0/24 [110/10] is directly connected, ens6, weight 1, 00:01:00
O>* 172.10.20.0/24 [110/20] via 10.0.10.2, ens5, weight 1, 00:00:11
O>* 172.10.30.0/24 [110/20] via 10.0.12.2, ens4, weight 1, 00:00:06
````

Смотрим сетевую связность между сетями NET

![](/Lab22_OSPF/pics/OSPF_ping_Net1_2_3.jpg)

Видим, что пинги с NET10 доходят до NET20/30.

Таким образом, автоматическая настройка проведена успешно.

#### 3. Ассиметричный роутинг 

Проверим текущую таблицу маршрутизации на router1. Видим, что сейчас пути до сетей 172.10.20.0/24 и 172.10.30.0/24 идут через router2 и router3 соответственно, т.е. по коротким оптимальным путям.

router1# sh ip route ospf

O   172.10.10.0/24 [110/10] is directly connected, ens6, weight 1, 00:28:29
O>* 172.10.20.0/24 [110/20] via 10.0.10.2, ens5, weight 1, 00:27:40            # Router 2
O>* 172.10.30.0/24 [110/20] via 10.0.12.2, ens4, weight 1, 00:27:35            # Router 3
  
Попробуем реализовать ассиметричный роутинг, используя изменение "стоимости" интерфейса.

Также отключим reverse path filtering:

````bash
root@router1:~# sysctl net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.all.rp_filter = 0

````
Увеличим стоимость интерфейса на router1, смотрящего в сторону router3:

````bash
router1# conf t
router1(config)# int ens4
router1(config-if)# ip ospf cost 1000
router1(config-if)# exi
router1(config)# exi
router1# sh ip route ospf
````

По таблице маршрутизации можно сразу увидеть, что теперь путь до сети 172.10.30.0/24 также идет через роутер2:

```bash
IPv4 unicast VRF default:
O   10.0.10.0/30 [110/10] is directly connected, ens5, weight 1, 00:34:20
O>* 10.0.11.0/30 [110/20] via 10.0.10.2, ens5, weight 1, 00:00:24
O   10.0.12.0/30 [110/30] via 10.0.10.2, ens5, weight 1, 00:00:24
O   172.10.10.0/24 [110/10] is directly connected, ens6, weight 1, 00:34:20
O>* 172.10.20.0/24 [110/20] via 10.0.10.2, ens5, weight 1, 00:33:31               # Router 2
O>* 172.10.30.0/24 [110/30] via 10.0.10.2, ens5, weight 1, 00:00:24               # Router 2
```

При этом на роутер3 путь до 172.10.10.0/24 по-прежнему идет напрямую через роутер1

````bash
router3# sh ip route ospf

IPv4 unicast VRF default:
O>* 10.0.10.0/30 [110/20] via 10.0.11.2, ens5, weight 1, 00:37:23
  *                       via 10.0.12.1, ens4, weight 1, 00:37:23
O   10.0.11.0/30 [110/10] is directly connected, ens5, weight 1, 00:38:18
O   10.0.12.0/30 [110/10] is directly connected, ens4, weight 1, 00:38:18
O>* 172.10.10.0/24 [110/20] via 10.0.12.1, ens4, weight 1, 00:37:23
O>* 172.10.20.0/24 [110/20] via 10.0.11.2, ens5, weight 1, 00:37:33
O   172.10.30.0/24 [110/10] is directly connected, ens6, weight 1, 00:38:18

````
Пробуем пинговать сеть 172.10.30.0/24 c роутер1:

```bash
router1# ping 172.10.30.1
PING 172.10.30.1 (172.10.30.1) 56(84) bytes of data.
64 bytes from 172.10.30.1: icmp_seq=1 ttl=63 time=2.43 ms
64 bytes from 172.10.30.1: icmp_seq=2 ttl=63 time=2.29 ms
64 bytes from 172.10.30.1: icmp_seq=3 ttl=63 time=2.76 ms
64 bytes from 172.10.30.1: icmp_seq=4 ttl=63 time=1.79 ms
64 bytes from 172.10.30.1: icmp_seq=5 ttl=63 time=2.67 ms
```

Включаем tcpdump на ротуер2 на интерфейсе к роутеру1 и видим только запросы:

```bash
user@router2:~$ sudo tcpdump -i ens4
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on ens4, link-type EN10MB (Ethernet), snapshot length 262144 bytes
07:30:31.974205 IP 10.0.11.1 > ospf-all.mcast.net: OSPFv2, Hello, length 48
07:30:31.974456 IP router2 > ospf-all.mcast.net: OSPFv2, Hello, length 48
07:30:32.247857 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3746, seq 1, length 64
07:30:33.249872 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3746, seq 2, length 64
07:30:34.252204 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3746, seq 3, length 64
07:30:35.254457 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3746, seq 4, length 64
07:30:36.257322 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3746, seq 5, length 64
07:30:37.284305 ARP, Request who-has 10.0.11.1 tell router2, length 28
07:30:37.286167 ARP, Reply 10.0.11.1 is-at 00:50:00:00:02:02 (oui Unknown), length 28
^C
9 packets captured
9 packets received by filter
0 packets dropped by kernel
```

А на роутер3 видим, что ответы ICMP уходят напрямую к роутер1:

```bash
root@router3:~# tcpdump -i ens4
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on ens4, link-type EN10MB (Ethernet), snapshot length 262144 bytes
07:30:21.976155 IP router3 > ospf-all.mcast.net: OSPFv2, Hello, length 48
07:30:21.977113 IP 10.0.12.1 > ospf-all.mcast.net: OSPFv2, Hello, length 48
07:30:31.978547 IP router3 > ospf-all.mcast.net: OSPFv2, Hello, length 48
07:30:31.981070 IP 10.0.12.1 > ospf-all.mcast.net: OSPFv2, Hello, length 48
07:30:32.254954 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3746, seq 1, length 64
07:30:33.255963 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3746, seq 2, length 64
07:30:34.258797 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3746, seq 3, length 64
07:30:35.260514 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3746, seq 4, length 64
07:30:36.263740 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3746, seq 5, length 64
07:30:37.562386 ARP, Request who-has 10.0.12.1 tell router3, length 28
07:30:37.564004 ARP, Reply 10.0.12.1 is-at 00:50:00:00:01:01 (oui Unknown), length 28
07:30:41.978977 IP router3 > ospf-all.mcast.net: OSPFv2, Hello, length 48
07:30:41.982012 IP 10.0.12.1 > ospf-all.mcast.net: OSPFv2, Hello, length 48
^C
13 packets captured
13 packets received by filter
0 packets dropped by kernel

```

Таким образом, сейчас имеет место быть ассиметричный роутинг, когда трафик в соединении идет различными путями

![](/Lab22_OSPF/pics/assymetrical_routing.jpg)

чтобы восстановить симметричный ротуинг увеличим стоимость интерфейса в сторону router1 на router3:

```bash
router3# conf t
router3(config)# int ens4
router3(config-if)# ip ospf cost 1000
router3(config-if)# exi
router3(config)# exi

router3# sh ip route ospf

O>* 172.10.10.0/24 [110/30] via 10.0.11.2, ens5, weight 1, 00:00:19
O>* 172.10.20.0/24 [110/20] via 10.0.11.2, ens5, weight 1, 00:59:31
O   172.10.30.0/24 [110/10] is directly connected, ens6, weight 1, 01:00:16
```

Видим, что теперь для router3 путь до сетей 172.10.10.0/24 и 172.10.20.0/24 лежит через router2.


Пингуем сеть 172.10.30.1 с роутера1

```bash
router1# ping 172.10.30.1
PING 172.10.30.1 (172.10.30.1) 56(84) bytes of data.
64 bytes from 172.10.30.1: icmp_seq=1 ttl=62 time=2.87 ms
64 bytes from 172.10.30.1: icmp_seq=2 ttl=62 time=4.35 ms
```

В трафике на router2 видим, что теперь весь трафик проходит одним путем(видны как request, так b reply.)

````bash
root@router2:~# tcpdump -i ens4
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on ens4, link-type EN10MB (Ethernet), snapshot length 262144 bytes
07:49:00.577568 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3762, seq 1, length 64
07:49:00.579720 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3762, seq 1, length 64
07:49:01.579464 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3762, seq 2, length 64
07:49:01.582143 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3762, seq 2, length 64
07:49:02.154447 IP router2 > ospf-all.mcast.net: OSPFv2, Hello, length 48
07:49:02.154849 IP 10.0.11.1 > ospf-all.mcast.net: OSPFv2, Hello, length 48
07:49:02.580920 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3762, seq 3, length 64
07:49:02.582958 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3762, seq 3, length 64
07:49:03.583215 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3762, seq 4, length 64
07:49:03.585107 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3762, seq 4, length 64
07:49:04.583738 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3762, seq 5, length 64
07:49:04.584375 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3762, seq 5, length 64
07:49:05.586408 IP 10.0.10.1 > 172-10-30-1.lightspeed.rlghnc.sbcglobal.net: ICMP echo request, id 3762, seq 6, length 64
07:49:05.588150 IP 172-10-30-1.lightspeed.rlghnc.sbcglobal.net > 10.0.10.1: ICMP echo reply, id 3762, seq 6, length 64
07:49:05.764381 ARP, Request who-has 10.0.11.1 tell router2, length 28
07:49:05.766104 ARP, Reply 10.0.11.1 is-at 00:50:00:00:02:02 (oui Unknown), length 28
07:49:06.043974 ARP, Request who-has router2 tell 10.0.11.1, length 28
07:49:06.044005 ARP, Reply router2 is-at 00:50:00:00:03:01 (oui Unknown), length 28

````