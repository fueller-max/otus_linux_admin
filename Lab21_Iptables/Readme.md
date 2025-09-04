# Сценарии iptables

## Цель

Написать сценарии iptables

### Задание

1. Реализовать knocking port. CentralRouter может попасть на ssh inetRouter через knock скрипт
2. Добавить inetRouter2, который виден с хоста или форвардится порт через локалхост.
3. Запустить Nginx на centralServer.
4. Пробросить 80й порт Nginx на inetRouter2 8080.
5. Дефолт в интернет оставить через inetRouter.

### Решение

#### 1.1 Реализация knocking port

Для реализации механизма knocking port будем использовать утилиту knockd.

Установка и настройка со стороны "Server side" inet Router:

````bash
user@ubuntu:~$ sudo apt-get install knockd
````
Настройки( /etc/knockd.conf) оставляем стандартные, за исключением добавления интерфейса (ens4), на котором будем слушать. В реальном применении, естственно стоит поменять паттерны (7000, 8000 ...) на что-то кастомное. Данные по попыткам подключений knockd будет брать из syslog.

````bash
[options]
        interface = ens4
        UseSyslog

[openSSH]
        sequence    = 7000,8000,9000
        seq_timeout = 5
        command     = /sbin/iptables -A INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
        tcpflags    = syn

[closeSSH]
        sequence    = 9000,8000,7000
        seq_timeout = 5
        command     = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
        tcpflags    = syn

[openHTTPS]
        sequence    = 12345,54321,24680,13579
        seq_timeout = 5
        command     = /usr/local/sbin/knock_add -i -c INPUT -p tcp -d 443 -f %IP%
        tcpflags    = syn

````
Запускаем сервис и ставим в автозагрузку.

````bash
root@ubuntu:~# systemctl start knockd
root@ubuntu:~# systemctl enable knockd
````

````bash
root@ubuntu:~# systemctl status knockd
● knockd.service - Port-Knock Daemon
     Loaded: loaded (/usr/lib/systemd/system/knockd.service; enabled; preset: enabled)
     Active: active (running) since Thu 2025-09-04 07:54:15 UTC; 11s ago
       Docs: man:knockd(1)
   Main PID: 1574 (knockd)
      Tasks: 1 (limit: 1068)
     Memory: 688.0K (peak: 872.0K)
        CPU: 16ms
     CGroup: /system.slice/knockd.service
             └─1574 /usr/sbin/knockd

````
На клиенте также устанавливаем knockd.

После установки проверяем работу данной системы.

* Изначально разрешения на подключение к ssh нет:
![](/Lab21_Iptables/pics/knocking/inetRouter_iptablesINIT.jpg)

* Со стороны клиента выполняем "простукивание" с нужным паттерном.

![](/Lab21_Iptables/pics/knocking/knockport_openSSH.jpg)

* После простукивания видим, что появлись правило, разрешающее подключение по SSH.
![](/Lab21_Iptables/pics/knocking/inetRouter_iptablesSSH_OPEN.jpg)

* Можно подключиться по SSH 
![](/Lab21_Iptables/pics/knocking/SSH_OK.jpg)

* Далее выполняем простукивание, но уже паттерном для закрытия SSH
![](/Lab21_Iptables/pics/knocking/knockport_closeSSH.jpg)

* После этого разрешающее правило снова пропало и подключением по SSH невозможно.  
![](/Lab21_Iptables/pics/knocking/inetRouter_iptablesSSH_CLOSE.jpg)

В целом, видим, что система рабочая и существенно повышает уровень секьюрити (особенно, если не забывать закрывать:)), однако не должно быть единственным решением.


#### 1.1 Добавление inet Router2

Добавляем в наш стенд еще один роутер, который с одной стороны подключен к внешней сети, а с другой стороны к central Router. Внешний интерфейс имеет статический адрес 192.168.20.202(домашний VLAN) и доступен с хоста, а внутренний имеет адрес 192.168.255.14 (след. свободная подсеть 192.168.255.12/30)

![](/Lab21_Iptables/pics/eve/plan.jpg)

Сетевые настройки для inet Router2

````bash
network:
    ethernets:
        ens3:
            dhcp4: false
            addresses: [192.168.20.202/24] # to external network(Home VLAN 192.168.20.0/24)
            routes:
            - to: 0.0.0.0/0
              via: 192.168.20.1
            nameservers:
              addresses: [8.8.8.8]
        ens4:
            dhcp4: false
            addresses: [192.168.255.14/30]
            routes:
            - to: 192.168.0.0/16 #internal hosts
              via: 192.168.255.13
            - to: 172.12.50.0/24 #Ansible network
              via: 192.168.255.13
    version: 2
````

#### 1.3 Nginx on central Server

Установку NGINX на central Server осуществим сразу через Ansible. Опустим настройку всех сопутствующих вещей (инвентари и пр..), т.к. уже было описано ранее.

Используем данный playbook:

````bash
---
- name: Configure inet Router2
  hosts: inetRouter2
  become: yes
  tasks:
     - name: Install iptables-persistent
       apt:
         name: iptables-persistent
         state: present

     - name: Copy ipv4 rules
       ansible.builtin.template:
           src:  "{{ item.src }}"
           dest: "{{ item.dest }}"
           owner: root
           group: root
           mode: "{{ item.mode }}"
       with_items:
          - {src: "inetRouter2/rules.v4", dest: "/etc/iptables/rules.ipv4", mode: "0644"}

     - name: restore firewall rules
       shell: |
         sudo iptables-restore < /etc/iptables/rules.v4

     - name: Setup package forwarding
       sysctl:
          name: net.ipv4.ip_forward
          value: '1'
          state: present
````

Запускаем

````bash
user@ubuntu:~/netlab/ansible$ ansible-playbook  playbooks/centralServer.yml

PLAY [Install and configure NGINX on centralServer] *************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************
[WARNING]: Platform linux on host centralServer is using the discovered Python interpreter at /usr/bin/python3.12, but future
installation of another Python interpreter could change the meaning of that path. See https://docs.ansible.com/ansible-
core/2.18/reference_appendices/interpreter_discovery.html for more information.
ok: [centralServer]

TASK [Update package cache] *************************************************************************************************************
ok: [centralServer]

TASK [Install NGINX] ********************************************************************************************************************
changed: [centralServer]

TASK [Start NGINX service] **************************************************************************************************************
ok: [centralServer]

TASK [Enable NGINX to start on boot] ****************************************************************************************************
ok: [centralServer]

TASK [Ensure NGINX is listening on port 80] *********************************************************************************************
ok: [centralServer]

TASK [Display NGINX status] *************************************************************************************************************
ok: [centralServer] => {
    "msg": "NGINX is running and listening on port 80."
}

PLAY RECAP ******************************************************************************************************************************
centralServer              : ok=7    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

````

После работы playbook`а проверяем, что nginx работает на хосте central Server:

````bash
user@ubuntu:~/netlab/ansible$ curl 192.168.0.2
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
````

#### 1.4 Пробросить 80й порт Nginx на inetRouter2 8080

Для реализации проброса 80го порта Nginx на central Server на inetRouter2  порт 8080 принципиально необходимо два правила в iptables:

````bash
 sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
 sudo iptables -t nat -A POSTROUTING -j MASQUERADE
````

Первое, DNAT будет перенаправлять трафик с порта 8080 на хост 192.168.0.2:80.

Второе необходимо для обратного трафика, т.к. устройства находятся в разных подсетях.

На осоновании этого готовим файл с правилами ip tables:

````bash
# Generated by iptables-save v1.8.10 (nf_tables) on Thu Sep  4 12:59:12 2025
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [10:2406]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
-A OUTPUT -o lo -j ACCEPT
-A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
COMMIT
# Completed on Thu Sep  4 12:59:12 2025
# Generated by iptables-save v1.8.10 (nf_tables) on Thu Sep  4 12:59:12 2025
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
-A POSTROUTING -j MASQUERADE
COMMIT
# Completed on Thu Sep  4 12:59:12 2025
````

Далее, делаем playbook по аналогии с уже использованным для inet Router 

````bash
---
- name: Configure inet Router2
  hosts: inetRouter2
  become: yes
  tasks:
     - name: Install iptables-persistent
       apt:
         name: iptables-persistent
         state: present

     - name: Copy ipv4 rules
       ansible.builtin.template:
           src:  "{{ item.src }}"
           dest: "{{ item.dest }}"
           owner: root
           group: root
           mode: "{{ item.mode }}"
       with_items:
          - {src: "inetRouter2/rules.v4", dest: "/etc/iptables/rules.ipv4", mode: "0644"}

     - name: restore firewall rules
       shell: |
         sudo iptables-restore < /etc/iptables/rules.v4

     - name: Setup package forwarding
       sysctl:
          name: net.ipv4.ip_forward
          value: '1'
          state: present
````

Далее прогоняем playbook:

````
user@ubuntu:~/netlab/ansible$ ansible-playbook  playbooks/inetRouter2.yml

PLAY [Configure inet Router2] ***********************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************
[WARNING]: Platform linux on host inetRouter2 is using the discovered Python interpreter at /usr/bin/python3.12, but future installation
of another Python interpreter could change the meaning of that path. See https://docs.ansible.com/ansible-
core/2.18/reference_appendices/interpreter_discovery.html for more information.
ok: [inetRouter2]

TASK [Install iptables-persistent] ******************************************************************************************************
ok: [inetRouter2]

TASK [Copy ipv4 rules] ******************************************************************************************************************
changed: [inetRouter2] => (item={'src': 'inetRouter2/rules.v4', 'dest': '/etc/iptables/rules.ipv4', 'mode': '0644'})

TASK [restore firewall rules] ***********************************************************************************************************
changed: [inetRouter2]

TASK [Setup package forwarding] *********************************************************************************************************
ok: [inetRouter2]

PLAY RECAP ******************************************************************************************************************************
inetRouter2                : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
````

И убеждаемся, что Nginx теперь достуапен из вне (с хостовой OC) по адресу http://192.168.20.202:8080/

![](/Lab21_Iptables/pics/nginx_redirect/nginx.jpg)

