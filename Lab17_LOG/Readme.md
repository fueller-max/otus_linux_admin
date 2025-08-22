# Настраиваем центральный сервер для сбора логов

## Цель

Научится проектировать централизованный сбор логов;
рассмотреть особенности разных платформ для сбора логов.

### Задание

1. В Vagrant развернуть 2 виртуальные машины web и log
2. На web настроить nginx
3. На log настроить центральный лог сервер на любой системе на выбор:
   * journald;
   * rsyslog;
   * elk.
4. Настроить аудит, следящий за изменением конфигов nginx 

Все критичные логи с web должны собираться и локально и удаленно.
Все логи с nginx должны уходить на удаленный сервер (локально только критичные).
Логи аудита должны также уходить на удаленную систему.

### Решение


#### 1. Разворачиваем 2 виртуальных машин: web и log в Vagrant

* Vagrant файл для развертывания двух машин:

````bash
Vagrant.configure("2") do |config|
# Base VM OS config
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.provider :virtualbox do |v|
    v.memory = 1024
    v.cpus = 1
  end

  #Define 2 VMs with static private IP addresses
  boxes = [
    { :name => "web",
      :ip => "192.168.56.10",
    },
    { :name => "log",
      :ip => "192.168.56.15",
    }
  ]
  # Provision each of the VMs
  boxes.each do |opts|
    config.vm.define opts[:name] do |config|
      config.vm.hostname = opts[:name]
      config.vm.network "private_network", ip: opts[:ip]
    end
  end
end
````

* Машины установились и запустились:

````bash
ansible@ansible:~/LOGGER$ vagrant status
Current machine states:

web                       running (virtualbox)
log                       running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
````

* Устанавливаем TimeZone, проверяем корректность установки времени на обеих машинах:

````bash
root@web:~# sudo timedatectl set-timezone Europe/Moscow
root@web:~# date
Thu Aug 21 08:42:38 PM MSK 2025
````

````bash
vagrant@log:~$ sudo timedatectl set-timezone Europe/Moscow
vagrant@log:~$ date
Thu Aug 21 08:43:45 PM MSK 2025
````
#### 2.  Настройка nginx на web 

* Устанавливаем Nginx и убеждаемся, что сервис работает:

````bash
root@web:~# systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2025-08-21 20:48:18 MSK; 29s ago
       Docs: man:nginx(8)
    Process: 3331 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 3332 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 3434 (nginx)
      Tasks: 2 (limit: 1011)
     Memory: 3.8M
        CPU: 51ms
     CGroup: /system.slice/nginx.service
             ├─3434 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             └─3435 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""

Aug 21 20:48:18 web systemd[1]: Starting A high performance web server and a reverse proxy server...
Aug 21 20:48:18 web systemd[1]: Started A high performance web server and a reverse proxy server.
````

````bash
root@web:~# ss -tln | grep 80
LISTEN 0      511          0.0.0.0:80        0.0.0.0:*
LISTEN 0      511             [::]:80           [::]:*
````
#### 3.Настройка центрального log-сервера - rsyslog 

* Проверяем, что rsyslog установлен в системе

````bash
vagrant@log:~$ apt list rsyslog
Listing... Done
rsyslog/jammy-updates,jammy-security,now 8.2112.0-2ubuntu2.2 amd64 [installed,automatic]
N: There is 1 additional version. Please use the '-a' switch to see it
````

* В файле конфига rsyslog (/etc/rsyslog.conf ) настраиваем получение логов по TCP/UDP на 514 порту:

````bash
# provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# provides TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")
````
* Добавляем правила приёма сообщений от внешних хостов:

````bash
# Add remote logs
$template RemoteLogs,"/var/log/rsyslog/%HOSTNAME%/%PROGRAMME%.log"
*.* ?RemoteLogs
& ~
````
* Перезапускаем rsyslog после внесенных изменений конфига:

````bash
vagrant@log:~$ systemctl restart rsyslog
````
* Проверяем, что порт 514 (TCP/UDP) открыт:
````bash
vagrant@log:~$ ss -tuln
Netid         State           Recv-Q          Send-Q                    Local Address:Port                   Peer Address:Port         Process
udp           UNCONN          0               0                         127.0.0.53%lo:53                          0.0.0.0:*
udp           UNCONN          0               0                        10.0.2.15%eth0:68                          0.0.0.0:*
udp           UNCONN          0               0                               0.0.0.0:514                         0.0.0.0:*
udp           UNCONN          0               0                                  [::]:514                            [::]:*
tcp           LISTEN          0               128                             0.0.0.0:22                          0.0.0.0:*
tcp           LISTEN          0               25                              0.0.0.0:514                         0.0.0.0:*
tcp           LISTEN          0               4096                      127.0.0.53%lo:53                          0.0.0.0:*
tcp           LISTEN          0               128                                [::]:22                             [::]:*
tcp           LISTEN          0               25                                 [::]:514                            [::]:*

````

* Заходим на web и делаем настройку конфига nginx для передачи логов на внешний сервис

````bash
root@web:~# nginx -v
nginx version: nginx/1.18.0 (Ubuntu)
````


````bash
root@web:~# nano /etc/nginx/nginx.conf

##
        # Logging Settings
        ##

        error_log  /var/log/nginx/error.log;
        error_log  syslog:server=192.168.56.15:514,tag=nginx_error;
        access_log syslog:server=192.168.56.15:514,tag=nginx_access,severity=info combined;
````
Исходя из приведенных настроек, error_log будет вестись локально и также отправлятся на внешний сервер(192.168.56.15:514). access_log же будет отправляться только на внешний сервер.


* Проверим, что логирование работает. Зайдем на web из хостовой ОС:

````bash
ansible@ansible:~$ curl 192.168.56.10
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
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

* В машине log видим, что появилась запись о входе

````bash
vagrant@log:/var/log/rsyslog/web$ cat nginx_access.log
Aug 21 21:18:12 web nginx_access: 192.168.56.1 - - [21/Aug/2025:21:18:12 +0300] "GET / HTTP/1.1" 200 612 "-" "curl/8.5.0"

````

Т.е. передача логов работает корректно.

#### 4. Настройка аудита, следящего за изменением конфигов nginx 

* Устанавливаем auditd на web:

````bash
root@web:~# apt-get install auditd
````

* Добавлем правило для мониторинга изменений конфига nginx(директория/etc/nginx/)

````bash
root@web:~# sudo nano /etc/audit/rules.d/nginx.rules
-w /etc/nginx/ -p wa -k nginx-config
````
* Перезапускаем правила auditd

````bash
root@web:~# sudo auditctl -R /etc/audit/rules.d/nginx.rules
````


* Настраиваем rsyslog на перенаправление сообщений от audit на сервер:

````bash
#################
#### MODULES ####
#################
$ModLoad imfile

#Log msg from audit log send to external log server over TCP
$InputFileName /var/log/audit/audit.log
$InputFileTag tag\_audit\_log:
$InputFileStateFile audit_log
$InputFileSeverity info
$InputFileFacility local6
$InputRunFileMonitor

local6.* @@192.168.56.15:514
````

* На log-сервере добавляем template для записи сообщений от audit:

````bash
$template HostAudit, "/var/log/rsyslog/%HOSTNAME%/audit_log"
local6.* ?HostAudit
````

* Проверяем работу системы. Вносим изменение в /etc/nginx/nginx.conf, меняе мorker_connections с 768 на 767. 


````bash
events {
        worker_connections 767;
        # multi_accept on;
}
````

* Используя утилиту ausearch убеждаемся, что audit определил факт изменения файла конфига.

````bash
root@web:/var/log/audit# sudo ausearch -k nginx-config

----
time->Fri Aug 22 19:09:18 2025
type=PROCTITLE msg=audit(1755878958.684:335): proctitle=6E616E6F002F6574632F6E67696E782F6E67696E782E636F6E66
type=PATH msg=audit(1755878958.684:335): item=0 name="/etc/nginx/" inode=1050361 dev=fd:00 mode=040755 ouid=0 ogid=0 rdev=00:00 nametype=PARENT cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0
type=CWD msg=audit(1755878958.684:335): cwd="/var/log/audit"
type=SYSCALL msg=audit(1755878958.684:335): arch=c000003e syscall=87 success=no exit=-2 a0=557b28daedc0 a1=1f a2=626577 a3=7f6dfc72fac0 items=1 ppid=1424 pid=1926 auid=1000 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=pts1 ses=3 comm="nano" exe="/usr/bin/nano" subj=unconfined key="nginx-config"
----
time->Fri Aug 22 19:09:18 2025
type=PROCTITLE msg=audit(1755878958.684:336): proctitle=6E616E6F002F6574632F6E67696E782F6E67696E782E636F6E66
type=PATH msg=audit(1755878958.684:336): item=1 name="/etc/nginx/.nginx.conf.swp" inode=1050159 dev=fd:00 mode=0100644 ouid=0 ogid=0 rdev=00:00 nametype=CREATE cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0
type=PATH msg=audit(1755878958.684:336): item=0 name="/etc/nginx/" inode=1050361 dev=fd:00 mode=040755 ouid=0 ogid=0 rdev=00:00 nametype=PARENT cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0
type=CWD msg=audit(1755878958.684:336): cwd="/var/log/audit"
type=SYSCALL msg=audit(1755878958.684:336): arch=c000003e syscall=257 success=yes exit=3 a0=ffffff9c a1=557b28daedc0 a2=c1 a3=1b6 items=2 ppid=1424 pid=1926 auid=1000 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=pts1 ses=3 comm="nano" exe="/usr/bin/nano" subj=unconfined key="nginx-config"
----
time->Fri Aug 22 19:09:21 2025
type=PROCTITLE msg=audit(1755878961.368:337): proctitle=6E616E6F002F6574632F6E67696E782F6E67696E782E636F6E66
type=PATH msg=audit(1755878961.368:337): item=1 name="/etc/nginx/.nginx.conf.swp" inode=1050159 dev=fd:00 mode=0100644 ouid=0 ogid=0 rdev=00:00 nametype=DELETE cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0
type=PATH msg=audit(1755878961.368:337): item=0 name="/etc/nginx/" inode=1050361 dev=fd:00 mode=040755 ouid=0 ogid=0 rdev=00:00 nametype=PARENT cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0
type=CWD msg=audit(1755878961.368:337): cwd="/var/log/audit"
type=SYSCALL msg=audit(1755878961.368:337): arch=c000003e syscall=87 success=yes exit=0 a0=557b28daedc0 a1=557b1ed7f7b0 a2=557b28dcd270 a3=7ffcb0673bb0 items=2 ppid=1424 pid=1926 auid=1000 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=pts1 ses=3 comm="nano" exe="/usr/bin/nano" subj=unconfined key="nginx-config"

````

* Смотрим сообщения в log сервере.

Видим, что появился файл audit_log, в котором находятся сообщения от audit.

````bash 
root@log:/var/log/rsyslog/web# ll
total 44
drwxr-xr-x 2 syslog syslog  4096 Aug 22 19:04 ./
drwxr-xr-x 4 syslog syslog  4096 Aug 21 21:18 ../
-rw-r----- 1 syslog adm    26066 Aug 22 19:09 audit_log
-rw-r----- 1 syslog adm      244 Aug 22 16:03 nginx_access.log
-rw-r----- 1 syslog adm      377 Aug 22 18:44 sudo.log
````


Видим, что время и содержание соответствует тому, что было на web сервере, что говорит о том, что данные аудита корректно передаются на центральный log сервер.


````bash 

Aug 22 19:09:22 web tag\_audit\_log: type=CWD msg=audit(1755878961.368:337): cwd="/var/log/audit"
Aug 22 19:09:22 web tag\_audit\_log: type=PATH msg=audit(1755878961.368:337): item=0 name="/etc/nginx/" inode=1050361 dev=fd:00 mode=040755 ouid=0 ogi>
Aug 22 19:09:22 web tag\_audit\_log: type=PATH msg=audit(1755878961.368:337): item=1 name="/etc/nginx/.nginx.conf.swp" inode=1050159 dev=fd:00 mode=01>
Aug 22 19:09:22 web tag\_audit\_log: type=PROCTITLE msg=audit(1755878961.368:337): proctitle=6E616E6F002F6574632F6E67696E782F6E67696E782E636F6E66
Aug 22 19:09:32 web tag\_audit\_log: type=USER_ACCT msg=audit(1755878963.388:338): pid=1927 uid=0 auid=1000 ses=3 subj=unconfined msg='op=PAM:accounti>
Aug 22 19:09:32 web tag\_audit\_log: type=USER_CMD msg=audit(1755878963.388:339): pid=1927 uid=0 auid=1000 ses=3 subj=unconfined msg='cwd="/var/log/au>
Aug 22 19:09:32 web tag\_audit\_log: type=CRED_REFR msg=audit(1755878963.388:340): pid=1927 uid=0 auid=1000 ses=3 subj=unconfined msg='op=PAM:setcred >
Aug 22 19:09:32 web tag\_audit\_log: type=USER_START msg=audit(1755878963.388:341): pid=1927 uid=0 auid=1000 ses=3 subj=unconfined msg='op=PAM:session>
Aug 22 19:09:32 web tag\_audit\_log: type=USER_END msg=audit(1755878963.496:342): pid=1927 uid=0 auid=1000 ses=3 subj=unconfined msg='op=PAM:session_c>
Aug 22 19:09:32 web tag\_audit\_log: type=CRED_DISP msg=audit(1755878963.496:343): pid=1927 uid=0 auid=1000 ses=3 subj=unconfined msg='op=PAM:setcred >

````







