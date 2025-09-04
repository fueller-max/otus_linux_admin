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

#### 1.1 Port knocking


Server side

````bash
user@ubuntu:~$ sudo apt-get install knockd
````

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


#### 1.3 Nginx on central Server




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

#### 1.4 Redirect port

````bash
 sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
 sudo iptables -t nat -A POSTROUTING -j MASQUERADE
````


