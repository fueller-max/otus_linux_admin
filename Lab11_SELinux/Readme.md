# Практика с SELinux

## Цель

Работать с SELinux: диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется

### Задание

0. Установать Nginx на rpm based Linux машину

1. Запустить nginx на нестандартном порту 3-мя разными способами:

* переключатели setsebool;
* добавление нестандартного порта в имеющийся тип;
* формирование и установка модуля SELinux.

2. Обеспечить работоспособность приложения при включенном selinux.

* развернуть приложенный стенд <https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems>;
* выяснить причину неработоспособности механизма обновления зоны (см. README);
* предложить решение (или решения) для данной проблемы;
* выбрать одно из решений для реализации, предварительно обосновав выбор;
* реализовать выбранное решение и продемонстрировать его работоспособность.

### Решение

0. Установка Nginx на rpm based Linux машину

Установим Nginx на дистрибутив Alma Linux 9. В конфигруации сразу указываем необходимые нам порты, на которых будет находится Nginx - 4881. Сразу запускаем Nginx.

````bash
yum install -y epel-release
      yum install -y nginx
      yum install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
      sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
      sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
      systemctl start nginx
````

1. Проверка статуса и запуск Nginx различными способами.

* Проверям статус Nginx после запуска в предыдущем пункте:

````bash
[root@localhost otus]# systemctl status nginx.service
× nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Sat 2025-06-28 13:50:13 MSK; 1min 17s ago
    Process: 80267 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80268 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
        CPU: 126ms

Jun 28 13:50:12 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 13:50:13 localhost.localdomain nginx[80268]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 13:50:13 localhost.localdomain nginx[80268]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
Jun 28 13:50:13 localhost.localdomain nginx[80268]: nginx: configuration file /etc/nginx/nginx.conf test failed
Jun 28 13:50:13 localhost.localdomain systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
Jun 28 13:50:13 localhost.localdomain systemd[1]: nginx.service: Failed with result 'exit-code'.
Jun 28 13:50:13 localhost.localdomain systemd[1]: Failed to start The nginx HTTP and reverse proxy server.

````

Видим, что Nginx не смог запуститься(статус failed). Из логов также видно, что причина есть осутствие необходимых прав доступа к нестандартному для web сервиса порту - 4881.

Отключаем firewall:

````bash
[root@localhost otus]# systemctl status firewalld
○ firewalld.service - firewalld - dynamic firewall daemon
     Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; preset: enabled)
     Active: inactive (dead) since Sat 2025-06-28 14:01:59 MSK; 2s ago
   Duration: 3w 4d 19h 49min 5.758s
       Docs: man:firewalld(1)
    Process: 847 ExecStart=/usr/sbin/firewalld --nofork --nopid $FIREWALLD_ARGS (code=exited, status=0/SUCCESS)
   Main PID: 847 (code=exited, status=0/SUCCESS)
        CPU: 2.409s

Jun 02 18:12:49 localhost systemd[1]: Starting firewalld - dynamic firewall daemon...
Jun 02 18:12:51 localhost systemd[1]: Started firewalld - dynamic firewall daemon.
Jun 28 14:01:56 localhost.localdomain systemd[1]: Stopping firewalld - dynamic firewall daemon...
Jun 28 14:01:59 localhost.localdomain systemd[1]: firewalld.service: Deactivated successfully.
Jun 28 14:01:59 localhost.localdomain systemd[1]: Stopped firewalld - dynamic firewall daemon.
Jun 28 14:01:59 localhost.localdomain systemd[1]: firewalld.service: Consumed 2.409s CPU time.

````

Проверяем режим работы SELinux:

````bash
[root@localhost otus]# getenforce
Enforcing

````bash
SELinux находится в состоянии Enforcing (принудительный) и обеспечивает защиту системы.

Проверим лог SELinux c поиском по порту 4881. Находим необходимые записи, проверям, что они относятся к Nginx и отмечаем время их возникновения.

````bash
[root@localhost otus]# cat  /var/log/audit/audit.log | grep 4881
type=AVC msg=audit(1751107356.146:694): avc:  denied  { name_bind } for  pid=76123 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=AVC msg=audit(1751107580.250:702): avc:  denied  { name_bind } for  pid=76240 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=AVC msg=audit(1751107813.126:771): avc:  denied  { name_bind } for  pid=80268 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

````

Используем утилиту audit2why, которая анализирует лог-записи и выдает причину возникновения блокировки. 

````bash
[root@localhost otus]# grep 1751107580.250:702 /var/log/audit/audit.log | audit2why
tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

        Was caused by:
        The boolean nis_enabled was set incorrectly.
        Description:
        Allow nis to enabled

        Allow access by executing:
        # setsebool -P nis_enabled 1

````

Утилита подсказывает, что причиной является блокировка NIS (который по дефолту выключен). Вариант решения - разблокировка NIS с помощью соответствующей команды. Возможно не лучший варинат решения, т.к. данный способ может потенциально нести проблемы с ослаблением безопасности в целом.

Проверим работу данной опции:

````bash
[root@localhost otus]# setsebool -P nis_enabled on
[root@localhost otus]# systemctl restart nginx
[root@localhost otus]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2025-06-28 14:10:20 MSK; 17s ago
    Process: 80497 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80498 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 80499 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 80500 (nginx)
      Tasks: 3 (limit: 10711)
     Memory: 4.1M
        CPU: 200ms
     CGroup: /system.slice/nginx.service
             ├─80500 "nginx: master process /usr/sbin/nginx"
             ├─80501 "nginx: worker process"
             └─80502 "nginx: worker process"

Jun 28 14:10:20 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 14:10:20 localhost.localdomain nginx[80498]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 14:10:20 localhost.localdomain nginx[80498]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jun 28 14:10:20 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.

````

Видим, что послу активации NIS, Nginx смог запуститья в нормальнои режиме.

![Nginx start page](/Lab11_SELinux/pics/var1_Niginx_OK.PNG)

````bash
[root@localhost otus]# getsebool -a | grep nis_enabled
nis_enabled --> on

````

Отключаем NIS, перезапускаем Ngnix и видим, что он снова не запускается:

````bash
[root@localhost otus]# setsebool -P nis_enabled off

````

````bash
[root@localhost otus]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.

````

2. Следующий поход основан на добавлении нового порта в контестный тип http_port_t, чтобы разрешить приложению прослушивать на нем.

Видим, что стандартные web порты относятся к типу http_port_t:

````bash
[root@localhost otus]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989

````

Добавим наш порт 4881 в конекстный тип http_port_t:

````bash
[root@localhost otus]# semanage port -a -t http_port_t -p tcp 4881

````

Проверим, что порт добавлен в тип:

````bash
[root@localhost otus]# semanage port -l | grep  http_port_t
http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988

````

После этого перезапускаем Nginx и видим, что он запустился без сбоев:

````bash
[root@localhost otus]# systemctl restart nginx
[root@localhost otus]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2025-06-28 14:27:24 MSK; 5s ago
    Process: 80565 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80566 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 80567 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 80568 (nginx)
      Tasks: 3 (limit: 10711)
     Memory: 2.8M
        CPU: 196ms
     CGroup: /system.slice/nginx.service
             ├─80568 "nginx: master process /usr/sbin/nginx"
             ├─80569 "nginx: worker process"
             └─80570 "nginx: worker process"

Jun 28 14:27:24 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 14:27:24 localhost.localdomain nginx[80566]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 14:27:24 localhost.localdomain nginx[80566]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jun 28 14:27:24 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.

````

Удаляем порт из контекстного типа, после чего Nginx снова не запускается:

````bash
[root@localhost otus]# semanage port -d -t http_port_t -p tcp 4881
[root@localhost otus]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
[root@localhost otus]# systemctl status nginx
× nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Sat 2025-06-28 14:28:33 MSK; 7s ago
   Duration: 1min 3.314s
    Process: 80583 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80584 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
        CPU: 104ms

Jun 28 14:28:32 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 14:28:33 localhost.localdomain nginx[80584]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 14:28:33 localhost.localdomain nginx[80584]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
Jun 28 14:28:33 localhost.localdomain nginx[80584]: nginx: configuration file /etc/nginx/nginx.conf test failed
Jun 28 14:28:33 localhost.localdomain systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
Jun 28 14:28:33 localhost.localdomain systemd[1]: nginx.service: Failed with result 'exit-code'.
Jun 28 14:28:33 localhost.localdomain systemd[1]: Failed to start The nginx HTTP and reverse proxy server.

````

3. Запуск Nginx с помощью устанвоки модуля.

Проверяем, что Nginx не запускается на данный момент:

````bash
[root@localhost otus]# systemctl start nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
[root@localhost otus]# grep nginx /var/log/audit/audit.log

````

Используя логи + утилиту audit2allow, которая формирует policy-пакет для nginx: 

````bash
[root@localhost otus]# grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp

````

Выполняем и команду и видим, что далее Ngnix запускается в нормальном режиме:

````bash
[root@localhost otus]# semodule -i nginx.pp
[root@localhost otus]# systemctl start nginx
[root@localhost otus]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2025-06-28 14:32:27 MSK; 5s ago
    Process: 80637 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 80638 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 80639 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 80640 (nginx)
      Tasks: 3 (limit: 10711)
     Memory: 2.8M
        CPU: 195ms
     CGroup: /system.slice/nginx.service
             ├─80640 "nginx: master process /usr/sbin/nginx"
             ├─80641 "nginx: worker process"
             └─80642 "nginx: worker process"

Jun 28 14:32:27 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
Jun 28 14:32:27 localhost.localdomain nginx[80638]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Jun 28 14:32:27 localhost.localdomain nginx[80638]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Jun 28 14:32:27 localhost.localdomain systemd[1]: Started The nginx HTTP and reverse proxy server.

````

Достоинством метода явялется то, что политка остается постоянной (сохраняется после перезагрузки). 

Удаляем установленнй пакет безопасности для Nginx:

````bash
[root@localhost otus]# semodule -r nginx
libsemanage.semanage_direct_remove_key: Removing last nginx module (no other nginx module exists at another priority).
````

После чего запуск Nginx снова стал невозможен:

````bash
[root@localhost otus]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.

````
2.	Обеспечение работоспособности приложения при включенном SELinux

* Скачиваем репозиторий с Vagrant файлом и Ansible playbook`ом:

````bash
root@otus:/home/otus# git clone https://github.com/Nickmob/vagrant_selinux_dns_problems.git
Cloning into 'vagrant_selinux_dns_problems'...
remote: Enumerating objects: 32, done.
remote: Counting objects: 100% (32/32), done.
remote: Compressing objects: 100% (21/21), done.
remote: Total 32 (delta 9), reused 29 (delta 9), pack-reused 0 (from 0)
Receiving objects: 100% (32/32), 7.23 KiB | 2.41 MiB/s, done.
Resolving deltas: 100% (9/9), done.
```

* На машине установлен Vagrant и Ansible, запускаем процесс развертывания машин:

````bash
ansible@ansible:~/vagrant_selinux_dns_problems$ vagrant up
==> vagrant: A new version of Vagrant is available: 2.4.7 (installed version: 2.4.1)!
==> vagrant: To upgrade visit: https://www.vagrantup.com/downloads.html

Bringing machine 'ns01' up with 'virtualbox' provider...
Bringing machine 'client' up with 'virtualbox' provider...
==> ns01: Importing base box 'almalinux/9'...
==> ns01: Matching MAC address for NAT networking...
==> ns01: Checking if box 'almalinux/9' version '9.4.20240805' is up to date...
==> ns01: Setting the name of the VM: vagrant_selinux_dns_problems_ns01_1752344002704_15603
==> ns01: Clearing any previously set network interfaces...
==> ns01: Preparing network interfaces based on configuration...
    ns01: Adapter 1: nat
    ns01: Adapter 2: intnet
==> ns01: Forwarding ports...
    ns01: 22 (guest) => 2222 (host) (adapter 1)
==> ns01: Running 'pre-boot' VM customizations...
==> ns01: Booting VM...
==> ns01: Waiting for machine to boot. This may take a few minutes...
    ns01: SSH address: 127.0.0.1:2222
    ns01: SSH username: vagrant
    ns01: SSH auth method: private key
    ns01:
    ns01: Vagrant insecure key detected. Vagrant will automatically replace
    ns01: this with a newly generated keypair for better security.
    ns01:
    ns01: Inserting generated public key within guest...
    ns01: Removing insecure key from the guest if it's present...
    ns01: Key inserted! Disconnecting and reconnecting using new SSH key...
==> ns01: Machine booted and ready!
==> ns01: Checking for guest additions in VM...
==> ns01: Setting hostname...
==> ns01: Configuring and enabling network interfaces...
==> ns01: Running provisioner: ansible...
Vagrant gathered an unknown Ansible version:


and falls back on the compatibility mode '1.8'.

Alternatively, the compatibility mode can be specified in your Vagrantfile:
https://www.vagrantup.com/docs/provisioning/ansible_common.html#compatibility_mode

    ns01: Running ansible-playbook...

PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
ok: [ns01]

TASK [install packages] ********************************************************
changed: [ns01]

PLAY [ns01] ********************************************************************

TASK [Gathering Facts] *********************************************************
ok: [ns01]

TASK [copy named.conf] *********************************************************
changed: [ns01]

TASK [copy master zone dns.lab] ************************************************
changed: [ns01] => (item=/home/ansible/vagrant_selinux_dns_problems/provisioning/files/ns01/named.dns.lab)
changed: [ns01] => (item=/home/ansible/vagrant_selinux_dns_problems/provisioning/files/ns01/named.dns.lab.view1)

TASK [copy dynamic zone ddns.lab] **********************************************
changed: [ns01]

TASK [copy dynamic zone ddns.lab.view1] ****************************************
changed: [ns01]

TASK [copy master zone newdns.lab] *********************************************
changed: [ns01]

TASK [copy rev zones] **********************************************************
changed: [ns01]

TASK [copy resolv.conf to server] **********************************************
changed: [ns01]

TASK [copy transferkey to server] **********************************************
changed: [ns01]

TASK [set /etc/named permissions] **********************************************
changed: [ns01]

TASK [set /etc/named/dynamic permissions] **************************************
changed: [ns01]

TASK [ensure named is running and enabled] *************************************
changed: [ns01]
[WARNING]: Could not match supplied host pattern, ignoring: client

PLAY [client] ******************************************************************
skipping: no hosts matched

PLAY RECAP *********************************************************************
ns01                       : ok=14   changed=12   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

==> client: Importing base box 'almalinux/9'...
==> client: Matching MAC address for NAT networking...
==> client: Checking if box 'almalinux/9' version '9.4.20240805' is up to date...
==> client: Setting the name of the VM: vagrant_selinux_dns_problems_client_1752344153646_49802
==> client: Fixed port collision for 22 => 2222. Now on port 2200.
==> client: Clearing any previously set network interfaces...
==> client: Preparing network interfaces based on configuration...
    client: Adapter 1: nat
    client: Adapter 2: intnet
==> client: Forwarding ports...
    client: 22 (guest) => 2200 (host) (adapter 1)
==> client: Running 'pre-boot' VM customizations...
==> client: Booting VM...
==> client: Waiting for machine to boot. This may take a few minutes...
    client: SSH address: 127.0.0.1:2200
    client: SSH username: vagrant
    client: SSH auth method: private key
    client:
    client: Vagrant insecure key detected. Vagrant will automatically replace
    client: this with a newly generated keypair for better security.
    client:
    client: Inserting generated public key within guest...
    client: Removing insecure key from the guest if it's present...
    client: Key inserted! Disconnecting and reconnecting using new SSH key...
==> client: Machine booted and ready!
==> client: Checking for guest additions in VM...
==> client: Setting hostname...
==> client: Configuring and enabling network interfaces...
==> client: Running provisioner: ansible...
Vagrant gathered an unknown Ansible version:


and falls back on the compatibility mode '1.8'.

Alternatively, the compatibility mode can be specified in your Vagrantfile:
https://www.vagrantup.com/docs/provisioning/ansible_common.html#compatibility_mode

    client: Running ansible-playbook...

PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
ok: [client]

TASK [install packages] ********************************************************
changed: [client]

PLAY [ns01] ********************************************************************
skipping: no hosts matched

PLAY [client] ******************************************************************

TASK [Gathering Facts] *********************************************************
ok: [client]

TASK [copy resolv.conf to the client] ******************************************
changed: [client]

TASK [copy rndc conf file] *****************************************************
changed: [client]

TASK [copy motd to the client] *************************************************
changed: [client]

TASK [copy transferkey to client] **********************************************
changed: [client]

PLAY RECAP *********************************************************************
client                     : ok=7    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

````

* После отработки Vagrant и плэйбуков имеем две запущенные виртуальные машины:


````bash
ansible@ansible:~/vagrant_selinux_dns_problems$ vagrant status
Current machine states:

ns01                      running (virtualbox)
client                    running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
````

* Заходим по SHH на виртуальную машину Client:

````bash
ansible@ansible:~/vagrant_selinux_dns_problems$ vagrant ssh client
###############################
### Welcome to the DNS lab! ###
###############################

- Use this client to test the enviroment
- with dig or nslookup. Ex:
    dig @192.168.50.10 ns01.dns.lab

- nsupdate is available in the ddns.lab zone. Ex:
    nsupdate -k /etc/named.zonetransfer.key
    server 192.168.50.10
    zone ddns.lab
    update add www.ddns.lab. 60 A 192.168.50.15
    send

- rndc is also available to manage the servers
    rndc -c ~/rndc.conf reload

###############################
### Enjoy! ####################
###############################
Last login: Sat Jul 12 18:17:34 2025 from 10.0.2.2
````

В данном машине пробуем изменить настройки в зону:

```` bash
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
> quit
[vagrant@client ~]$

````
Видим, что настройки не удалось применить. 

Анализиуря логи сервера и с примением утилиты  audit2why можно получить информацию о причине проблемы:

````bash
ansible@ansible:~/vagrant_selinux_dns_problems$ vagrant ssh ns01
Last login: Sat Jul 12 18:14:54 2025 from 10.0.2.2
[vagrant@ns01 ~]$
[vagrant@ns01 ~]$
[vagrant@ns01 ~]$ cat /var/log/audit/audit.log | audit2why
cat: /var/log/audit/audit.log: Permission denied
Nothing to do
[vagrant@ns01 ~]$ sudo -i
[root@ns01 ~]# cat /var/log/audit/audit.log | audit2why

type=AVC msg=audit(1752344549.813:1767): avc:  denied  { write } for  pid=9633 comm="isc-net-0000" name="dynamic" dev="sda4" ino=34030135 scontext=system_u:system_r:named_t:s0 tcontext=unconfined_u:object_r:named_conf_t:s0 tclass=dir permissive=0

        Was caused by:
                Missing type enforcement (TE) allow rule.

                You can use audit2allow to generate a loadable module to allow this access.

[root@ns01 ~]#

````
Видно, что целевой контект безопасности тут "named_conf_t" 

Однако, на сервере используется контекст "named_zone_t":

````bash
[root@ns01 ~]# ls -alZ /var/named/named.localhost
-rw-r-----. 1 root named system_u:object_r:named_zone_t:s0 152 Jun 24 13:47 /var/named/named.localhost
````

Собственно, несовпадение данных контекстов приводит к проблеме невозможности настройки зоны.

В коинфигах etc/named везде используется контект "named_conf_t":

````bash
[root@ns01 ~]# ls -laZ /etc/named
total 28
drw-rwx---.  3 root named system_u:object_r:named_conf_t:s0      121 Jul 12 18:14 .
drwxr-xr-x. 85 root root  system_u:object_r:etc_t:s0            8192 Jul 12 18:14 ..
drw-rwx---.  2 root named unconfined_u:object_r:named_conf_t:s0   56 Jul 12 18:14 dynamic
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      784 Jul 12 18:14 named.50.168.192.rev
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      610 Jul 12 18:14 named.dns.lab
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      609 Jul 12 18:14 named.dns.lab.view1
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      657 Jul 12 18:14 named.newdns.lab
````


Меняем тип контекста безопасности для каталога /etc/named на "named_zone_t" :

````bash
[root@ns01 ~]# sudo chcon -R -t named_zone_t /etc/named
[root@ns01 ~]# ls -laZ /etc/named
total 28
drw-rwx---.  3 root named system_u:object_r:named_zone_t:s0      121 Jul 12 18:14 .
drwxr-xr-x. 85 root root  system_u:object_r:etc_t:s0            8192 Jul 12 18:14 ..
drw-rwx---.  2 root named unconfined_u:object_r:named_zone_t:s0   56 Jul 12 18:14 dynamic
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      784 Jul 12 18:14 named.50.168.192.rev
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      610 Jul 12 18:14 named.dns.lab
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      609 Jul 12 18:14 named.dns.lab.view1
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      657 Jul 12 18:14 named.newdns.lab
[root@ns01 ~]#

````

Заново пробуем настроить зону на клиенте и видим, что теперь все проходит успешно:

````bash
[root@client ~]# nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit
[root@client ~]# dig www.ddns.lab

; <<>> DiG 9.16.23-RH <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 65026
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: c8c92e3a572a32eb010000006872ac41c58d2de04a2c51e5 (good)
;; QUESTION SECTION:
;www.ddns.lab.                  IN      A

;; ANSWER SECTION:
www.ddns.lab.           60      IN      A       192.168.50.15

;; Query time: 0 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sat Jul 12 18:41:05 UTC 2025
;; MSG SIZE  rcvd: 85

[root@client ~]#

````

После рестарта системы также все работает:

````bash
Last login: Sat Jul 12 18:19:39 2025 from 10.0.2.2
[vagrant@client ~]$ dig @192.168.50.10 www.ddns.lab

; <<>> DiG 9.16.23-RH <<>> @192.168.50.10 www.ddns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 17603
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: de2d759946215d26010000006872ae9a9766d5e2431d46ef (good)
;; QUESTION SECTION:
;www.ddns.lab.                  IN      A

;; ANSWER SECTION:
www.ddns.lab.           60      IN      A       192.168.50.15

;; Query time: 3 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sat Jul 12 18:51:06 UTC 2025
;; MSG SIZE  rcvd: 85

````
В случае необходимости есть возмжность вернуть правила обратно:

````bash
[vagrant@ns01 ~]$ sudo -i
[root@ns01 ~]# restorecon -v -R /etc/named
Relabeled /etc/named from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/named.dns.lab from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/named.dns.lab.view1 from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/dynamic from unconfined_u:object_r:named_zone_t:s0 to unconfined_u:object_r:named_conf_t:s0
Relabeled /etc/named/dynamic/named.ddns.lab from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/dynamic/named.ddns.lab.view1 from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/dynamic/named.ddns.lab.view1.jnl from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/named.newdns.lab from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/named.50.168.192.rev from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0

````

