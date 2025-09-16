# PXE

## Цель

Отработать навыки установки и настройки DHCP, TFTP, PXE загрузчика и автоматической загрузки

### Задание

1. Настроить загрузку по сети дистрибутива Ubuntu 24
2. Настроить Apache для загрузки из HTTP-репозитория.
3. Настроить автоматическую установку c помощью файла user-data

### Решение

#### 1. Настройка загрузки по сети дистрибутива Ubuntu 24

* Разворачиванием VM в VMware, которую будем использовать в качестве PXE сервера.

Выполняем первичную настройку хоста с использованием provision.yaml плейбука:

````bash
---
- name: Setup PXE Server
  hosts: pxeserver
  become: yes

  tasks:
  - name: Stop ufw service
    systemd:
      name: ufw
      state: stopped

  - name: Disable ufw service
    systemd:
      name: ufw
      enabled: no

  - name: Update package list
    apt:
       update_cache: yes

  - name: Install dnsmasq
    apt:
     name: dnsmasq
     state: present

  - name: copy config file
    template:
        src: pxe.conf
        dest: /etc/dnsmasq.d/pxe.conf
        mode: 0640

  - name: Create directory /srv/tftp
    file:
        path: /srv/tftp
        state: directory
        mode: 0755

  - name: Download the Ubuntu 24.04 netboot image
    get_url:
        url: https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-netboot-amd64.tar.gz
        dest: /tmp/noble-netboot-amd64.tar.gz

  - name: Extract the tar file to /srv/tftp
    shell: tar -xzvf /tmp/noble-netboot-amd64.tar.gz -C /srv/tftp
    args:
        creates: /srv/tftp/amd64

  - name: Restart dnsmasq service
    systemd:
        name: dnsmasq
        state: restarted
````

Результатом работы должен быть установленный и запущенный dnsmasq сервис (DHCP и TFTP), а также скачанный netboot image для Ubuntu 24.04.

````bash
pxe@pxe:~$ systemctl status dnsmasq
● dnsmasq.service - dnsmasq - A lightweight DHCP and caching DNS server
     Loaded: loaded (/lib/systemd/system/dnsmasq.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2025-09-16 17:01:35 UTC; 32s ago
    Process: 871 ExecStartPre=/usr/sbin/dnsmasq --test (code=exited, status=0/SUCCESS)
    Process: 908 ExecStart=/etc/init.d/dnsmasq systemd-exec (code=exited, status=0/SUCCESS)
    Process: 953 ExecStartPost=/etc/init.d/dnsmasq systemd-start-resolvconf (code=exited, status=0/SUCCESS)
   Main PID: 944 (dnsmasq)
      Tasks: 1 (limit: 4550)
     Memory: 2.8M
     CGroup: /system.slice/dnsmasq.service
             └─944 /usr/sbin/dnsmasq -x /run/dnsmasq/dnsmasq.pid -u dnsmasq -7 /etc/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new --local-ser>

Sep 16 17:01:33 pxe dnsmasq[871]: dnsmasq: syntax check OK.
Sep 16 17:01:34 pxe dnsmasq[944]: started, version 2.90 cachesize 150
Sep 16 17:01:35 pxe systemd[1]: Started dnsmasq - A lightweight DHCP and caching DNS server.
Sep 16 17:01:34 pxe dnsmasq[944]: compile time options: IPv6 GNU-getopt DBus no-UBus i18n IDN DHCP DHCPv6 no-Lua TFTP conntrack ipset no>
Sep 16 17:01:34 pxe dnsmasq-dhcp[944]: DHCP, IP range 10.0.0.100 -- 10.0.0.120, lease time 1h
Sep 16 17:01:34 pxe dnsmasq-dhcp[944]: DHCP, sockets bound exclusively to interface ens37
Sep 16 17:01:34 pxe dnsmasq-tftp[944]: TFTP root is /srv/tftp/amd64
Sep 16 17:01:34 pxe dnsmasq[944]: reading /etc/resolv.conf
Sep 16 17:01:34 pxe dnsmasq[944]: using nameserver 127.0.0.53#53
Sep 16 17:01:34 pxe dnsmasq[944]: read /etc/hosts - 8 names
````

````bash
pxe@pxe:~$ ll /srv/tftp/amd64
total 92792
drwxr-xr-x 4 root root     4096 Sep 14 08:30 ./
drwxr-xr-x 3 root root     4096 Sep 14 08:30 ../
-rw-r--r-- 1 root root   966664 Apr  4  2024 bootx64.efi
drwxr-xr-x 2 root root     4096 Sep 14 08:30 grub/
-rw-r--r-- 1 root root  2344840 Mar 28 10:14 grubx64.efi
-rw-r--r-- 1 root root 75970454 Sep 14 08:30 initrd
-rw-r--r-- 1 root root   118676 Apr  8  2024 ldlinux.c32
-rw-r--r-- 1 root root 15546760 Sep 14 08:30 linux
-rw-r--r-- 1 root root    42392 Apr  8  2024 pxelinux.0
drwxr-xr-x 2 root root     4096 Sep 16 13:28 pxelinux.cfg/
````


#### 2. Настроить Apache для загрузки из HTTP-репозитория.

Для того, чтобы отдавать файлы по HTTP настроим HTTP сервер на базе Apache, используя playbook werbserver.yaml:

````bash
---
- name: Setup WEB Server
  hosts: pxeserver
  become: yes

  tasks:
  - name: Install Apache2
    apt: 
     name: apache2
     state: present

  - name: Create directory /srv/images
    file:
        path: /srv/images
        state: directory
        mode: 0755

  - name: Download the Ubuntu 24.04 iso-image
    get_url:
        url: https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-live-server-amd64.iso
        dest: /srv/images

  - name: copy config file for virtual host
    template:
        src: ks-server.conf
        dest:  /etc/apache2/sites-available/ks-server.conf
        mode: 0640

  - name: Enable ks-server.conf site
    command: a2ensite ks-server.conf
    register: enable_site_result

  - name: copy config file /srv/tftp/amd64/pxelinux.cfg/default
    template:
        src: default
        dest:  /srv/tftp/amd64/pxelinux.cfg/default
        mode: 0644

  - name: Reload Apache to apply changes
    command: systemctl reload apache2
````

Результатом должен быть настроенный сервер Apache, у которого настроена директория /srv/images для отдачи образа операционной системы.

````bash
pxe@pxe:~$ systemctl status apache2
● apache2.service - The Apache HTTP Server
     Loaded: loaded (/lib/systemd/system/apache2.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2025-09-16 17:01:37 UTC; 2min 14s ago
       Docs: https://httpd.apache.org/docs/2.4/
    Process: 961 ExecStart=/usr/sbin/apachectl start (code=exited, status=0/SUCCESS)
   Main PID: 1042 (apache2)
      Tasks: 55 (limit: 4550)
     Memory: 8.4M
     CGroup: /system.slice/apache2.service
             ├─1042 /usr/sbin/apache2 -k start
             ├─1043 /usr/sbin/apache2 -k start
             └─1044 /usr/sbin/apache2 -k start

Sep 16 17:01:35 pxe systemd[1]: Starting The Apache HTTP Server...
Sep 16 17:01:37 pxe apachectl[994]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 127.0>
Sep 16 17:01:37 pxe systemd[1]: Started The Apache HTTP Server.
````


На данном этапе, мы имеем систему PXE сервера, к которой могут подключаться клиенты и выполнить установку системы в ручном режиме.

Создаем VM в Vmware c загрузкой по сети и проверяем возможность установки ОС:

![](/Lab20_PXE/pics/pxe_1.jpg)
![](/Lab20_PXE/pics/pxe_2.jpg)
![](/Lab20_PXE/pics/pxe_3.jpg)

#### 3. Настройка автоматической установки c помощью файла user-data

Для того, чтобы полностью сделать установку полностью автоматической (чтобы не требовалось использовать мастер установки) настроим пакет cloud-init для автоматической настройки ОС.

* Создаем файл user-data с требуемой конфигруацией:

````bash
#cloud-config
autoinstall:
  version: 1
  apt:
    disable_components: []
    geoip: true
    preserve_sources_list: false
    primary:
     - arches: [amd64,i386]
       uri: http://us.archive.ubuntu.com/ubuntu
  drivers:
   install: false
  identity:
    hostname: linux
    password: $6$sJgo6Hg5zXBwkkI8$btrEoWAb5FxKhajagWR49XM4EAOfO/Dr5bMrLOkGe3KkMYdsh7T3MU5mYwY2TIMJpVKckAwnZFs2ltUJ1abOZ.
    realname: otus
    username: otus
  kernel:
   package: linux-generic
  keyboard:
   layout: us
  network:
    ethernets:
     ens33:
      dhcp4: true
     ens37:
      dhcp4: true
    version: 2
  ssh:
   allow-pw: true
   authorized-keys: []
   install-server: true
   updates: security
````

* В файле /srv/tftp/amd64/pxelinux.cfg/default добавлем параметры для автоматической установки с использованием cloud-config:

````bash
DEFAULT install
LABEL install
  KERNEL linux
  INITRD initrd
  APPEND root=/dev/ram0 ramdisk_size=4000000 ip=dhcp cloud-config-url=http://10.0.0.20/ iso-url=http://10.0.0.20/srv/images/noble-live-server-amd64.iso autoinstall ds=nocloud-net;s=http://10.0.0.20/srv/ks/
````

Используем плейбук auto_install.yaml для обновления конфигурации и перезапуска сервисов:

````bash
---
- name: Configure PXE for Ubuntu autoinstall
  hosts: pxeserver
  become: yes

  tasks:
  - name: Create directory /srv/ks
    file:
        path: /srv/ks
        state: directory
        mode: 0755
  
  - name: copy cloud-config  file
    template:
        src: autoinstall/user-data
        dest: /srv/ks
        mode: 0644

  - name: Create file with meta data
    file:
        path: /srv/ks/meta-data
        state: touch
        mode: 0644
  
  - name: copy config file /srv/tftp/amd64/pxelinux.cfg/default
    template:
        src: autoinstall/default_auto_install
        dest:  /srv/tftp/amd64/pxelinux.cfg/default
        mode: 0644      
  
  - name: copy config file for virtual host
    template:
        src: autoinstall/ks-server_auto_install.conf
        dest:  /etc/apache2/sites-available/ks-server.conf
        mode: 0644 
  
  - name: Restart dnsmasq service
    systemd:
        name: dnsmasq
        state: restarted    

  - name: Reload Apache to apply changes
    command: systemctl reload apache2 

  - name: Restart Apache
    systemd:
        name: apache2
        state: restarted   
````


* Проверка работы. После всех перечисленных действий возможна полностью автоматческая установка ОС на хост.

Система установилась полностью автоматически с логином/паролем otus/123 как указано в user-data файле.
![](/Lab20_PXE/pics/ubuntu_auto_install.jpg)
