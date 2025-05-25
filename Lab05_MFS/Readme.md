### Работа с NFS

### Цель:
Научиться самостоятельно разворачивать сервис NFS и подключать к нему клиентов

###  Задание:

1. Создать две виртуальные машины с сетевой связностью
2. Настроить сервер NFS на первой машине
3. Настроить клиент NFS на второй машине
4. Проверка работоспобности


### Решение:

#### 1. Создание 2-ух виртуальных машины с сетевой связностью


1-ая виртуальная машина(сервер MFS):

````
otus@otusadmin:~$ ip address

2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:44:c3:e7 brd ff:ff:ff:ff:ff:ff
    altname enp2s1
    inet 192.168.153.138/24 metric 100 brd 192.168.153.255 scope global dynamic ens33
       valid_lft 1087sec preferred_lft 1087sec
    inet6 fe80::20c:29ff:fe44:c3e7/64 scope link
       valid_lft forever preferred_lft forever

````

2-ая виртуальная машина(клиент MFS):

````
otus@otus2:~$ ip address

2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 00:0c:29:ad:a4:60 brd ff:ff:ff:ff:ff:ff
    inet 192.168.153.142/24 brd 192.168.153.255 scope global dynamic ens33
       valid_lft 1152sec preferred_lft 1152sec
    inet6 fe80::20c:29ff:fead:a460/64 scope link
       valid_lft forever preferred_lft forever

````

Проверка сетевой связности:

````
otus@otus2:~$ ping 192.168.153.138
PING 192.168.153.138 (192.168.153.138) 56(84) bytes of data.
64 bytes from 192.168.153.138: icmp_seq=1 ttl=64 time=0.221 ms
###
--- 192.168.153.138 ping statistics ---
6 packets transmitted, 6 received, 0% packet loss, time 5039ms
rtt min/avg/max/mdev = 0.221/0.599/0.812/0.252 ms
````

Две виртуальные машины созданы, сетевая связность между ними обеспечена.

#### 2. Настройка сервера NFS на первой машине

````
root@otusadmin:~# apt install nfs-kernel-server
````
````
root@otusadmin:~# dpkg -l | grep -i nfs
ii  libnfsidmap1:amd64                         1:2.6.4-3ubuntu5.1                      amd64        NFS idmapping library
ii  nfs-common                                 1:2.6.4-3ubuntu5.1                      amd64        NFS support files common to client and server
ii  nfs-kernel-server                          1:2.6.4-3ubuntu5.1                      amd64        support for NFS kernel server

````


````
root@otusadmin:~# cat /etc/nfs.conf
#
# This is a general configuration for the
# NFS daemons and tools
###
[nfsd]
# debug=0
# threads=8
# host=
# port=0
# grace-time=90
# lease-time=90
# udp=n
# tcp=y
# vers3=y
# vers4=y
# vers4.0=y
# vers4.1=y
# vers4.2=y
# rdma=n
# rdma-port=20049

````

TCP всех версий, UDP неактивен по соображениям стабильности работы по протколу UDP в новых версиях сборки Ubuntu(хотя он работает быстрее и меньше нагружает ядро системы).


Выводим список используемых портов RPC(Remote procedure call):
````
root@otusadmin:~# rpcinfo -p
   program vers proto   port  service
    100000    4   tcp    111  portmapper
    100000    3   tcp    111  portmapper
    100000    2   tcp    111  portmapper
    100000    4   udp    111  portmapper
    100000    3   udp    111  portmapper
    100000    2   udp    111  portmapper
    100024    1   udp  51270  status
    100024    1   tcp  53983  status
    100005    1   udp  46624  mountd
    100005    1   tcp  45591  mountd
    100005    2   udp  34543  mountd
    100005    2   tcp  46755  mountd
    100005    3   udp  33775  mountd
    100005    3   tcp  51393  mountd
    100003    3   tcp   2049  nfs
    100003    4   tcp   2049  nfs
    100227    3   tcp   2049  nfs_acl
    100021    1   udp  33279  nlockmgr
    100021    3   udp  33279  nlockmgr
    100021    4   udp  33279  nlockmgr
    100021    1   tcp  45037  nlockmgr
    100021    3   tcp  45037  nlockmgr
    100021    4   tcp  45037  nlockmgr

````

Видим, что используется порт 2049 непосредственно NFS, а также 111 для portmapper.

Проверяем, что порты слушаются. Файрвол пока не не настроен - подразумеваем, что все порты будут доступны.

````
root@otusadmin:~# ss -tnplu
Netid   State    Recv-Q   Send-Q             Local Address:Port      Peer Address:Port   Process
#####
udp     UNCONN   0        0                        0.0.0.0:111            0.0.0.0:*       users:(("rpcbind",pid=2316,fd=5),("systemd",pid=1,fd=201))
udp     UNCONN   0        0                           [::]:111               [::]:*       users:(("rpcbind",pid=2316,fd=7),("systemd",pid=1,fd=203))
tcp     LISTEN   0        4096                     0.0.0.0:111            0.0.0.0:*       users:(("rpcbind",pid=2316,fd=4),("systemd",pid=1,fd=199))
tcp     LISTEN   0        64                          [::]:2049              [::]:*
####
````


Далее создадим директорию с соответствующими настройкам для использования ее как share папки:

````
root@otusadmin:~# mkdir -p /srv/share/upload
````

````
root@otusadmin:~# chown -R nobody:nogroup /srv/share
`````

````
root@otusadmin:~# chmod 0777 /srv/share/upload

````


Cоздаём в файле /etc/exports структуру, которая позволит экспортировать ранее созданную директорию:


````
root@otusadmin:~# cat << EOF > /etc/exports
> /srv/share 192.168.153.138/32(rw,sync,root_squash)
> EOF
````

````
root@otusadmin:~# cat /etc/exports
/srv/share 192.168.153.138/32(rw,sync,root_squash)
````

```
root@otusadmin:~# exportfs -r
exportfs: /etc/exports [1]: Neither 'subtree_check' or 'no_subtree_check' specified for export "192.168.153.138/32:/srv/share".
  Assuming default behaviour ('no_subtree_check').
  NOTE: this default has changed since nfs-utils version 1.0.x

root@otusadmin:~# exportfs -s
/srv/share  192.168.153.138/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

````

#### 3. Настройка клиента NFS на второй машине


````
root@otus2:~# apt install nfs-common

````

````
root@otus2:~# dpkg -l | grep -i nfs
ii  libnfsidmap2:amd64                    0.25-5.1ubuntu1                   amd64        NFS idmapping library
ii  nfs-common                            1:1.3.4-2.5ubuntu3.7              amd64        NFS support files common to client and server

````



````
root@otus2:~# mount 192.168.153.138:/srv/share/ /mnt/
mount.nfs: access denied by server while mounting 192.168.153.138:/srv/share/

````


````
root@otusadmin:~# journalctl -u nfs-mountd
May 25 16:58:11 otusadmin systemd[1]: Starting nfs-mountd.service - NFS Mount Daemon...
May 25 16:58:11 otusadmin rpc.mountd[3835]: Version 2.6.4 starting
May 25 16:58:11 otusadmin systemd[1]: Started nfs-mountd.service - NFS Mount Daemon.
May 25 18:02:52 otusadmin rpc.mountd[3835]: refused mount request from 192.168.153.142 for /srv/share (/srv/share): unmatched host
May 25 18:03:03 otusadmin rpc.mountd[3835]: refused mount request from 192.168.153.142 for /srv/share (/srv/share): unmatched host
May 25 18:03:38 otusadmin rpc.mountd[3835]: refused mount request from 192.168.153.142 for /srv/share (/srv/share): unmatched host
May 25 18:03:59 otusadmin rpc.mountd[3835]: refused mount request from 192.168.153.142 for /srv/share (/srv/share): unmatched host
May 25 18:03:59 otusadmin rpc.mountd[3835]: refused mount request from 192.168.153.142 for /srv/share (/srv/share): unmatched host

````

````
root@otus2:~# mount | grep mnt
nsfs on /run/snapd/ns/lxd.mnt type nsfs (rw)
systemd-1 on /mnt type autofs (rw,relatime,fd=51,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=52769)
192.168.153.138:/srv/share on /mnt type nfs4 (rw,relatime,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.153.142,local_lock=none,addr=192.168.153.138)
````


````
root@otus2:~# echo "192.168.153.138:/srv/share /mnt nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
root@otus2:~# systemctl daemon-reload
root@otus2:~# systemctl restart remote-fs.target
````


#### 4. Проверка работоспобности


Сервер:

````
root@otusadmin:~# cd /srv/share/upload
root@otusadmin:/srv/share/upload# touch test_file
````

Клиент:
````
root@otus2:~# cd /mnt/upload
root@otus2:/mnt/upload# ls -l
total 0
-rw-r--r-- 1 root root 0 May 25 18:29 test_file
````


Клиент:

````
root@otus2:/mnt/upload# touch client_test
````

Сервер:

````
root@otusadmin:/srv/share/upload# ls -l
total 0
-rw-r--r-- 1 nobody nogroup 0 May 25 18:32 client_test
-rw-r--r-- 1 root   root    0 May 25 18:29 test_file

```


Перезапускаем клиент и проверяем, что доступ к директории NFS есть и ранее созданные файлы на месте:

````
otus@otus2:~$ reboot

The system will reboot now!

````

````
otus@otus2:~$ ls -l /mnt/upload
total 0
-rw-r--r-- 1 nobody nogroup 0 May 25 18:32 client_test
-rw-r--r-- 1 root   root    0 May 25 18:29 test_file
````


Перезапускаем сервер:
````
otus@otusadmin:~$ reboot

The system will reboot now!
````
````
otus@otusadmin:~$ ls -l /srv/share/upload
total 0
-rw-r--r-- 1 nobody nogroup 0 May 25 18:32 client_test
-rw-r--r-- 1 root   root    0 May 25 18:29 test_file
```

````
root@otusadmin:~# exportfs -s
/srv/share  192.168.153.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

````

````
root@otusadmin:~# showmount -a 192.168.153.138
All mount points on 192.168.153.138:
192.168.153.142:/srv/share

````



Клиент:

`````
otus@otus2:~$ showmount -a 192.168.153.138
All mount points on 192.168.153.138:
192.168.153.142:/srv/share
`````

````
otus@otus2:~$ cd /mnt/upload
otus@otus2:/mnt/upload$ ls -l
total 0
-rw-r--r-- 1 nobody nogroup 0 May 25 18:32 client_test
-rw-r--r-- 1 root   root    0 May 25 18:29 test_file

````


````
otus@otus2:/mnt/upload$ touch client_final_check
````

````
root@otusadmin:~# ls -l /srv/share/upload/
total 0
-rw-rw-r-- 1 otus   otus    0 May 25 18:54 client_final_check
-rw-r--r-- 1 nobody nogroup 0 May 25 18:32 client_test
-rw-r--r-- 1 root   root    0 May 25 18:29 test_file
````




