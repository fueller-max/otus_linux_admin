# Настраиваем центральный сервер для сбора логов

## Цель

Научится проектировать централизованный сбор логов;
рассмотреть особенности разных платформ для сбора логов.

### Задание

1. В Vagrant развернуть 2 виртуальные машины web и log
2. На web настроить nginx
3. На log настраить центральный лог сервер на любой системе на выбор:
   * journald;
   * rsyslog;
   * elk.
4. Настраиваем аудит, следящий за изменением конфигов nginx 

Все критичные логи с web должны собираться и локально и удаленно.
Все логи с nginx должны уходить на удаленный сервер (локально только критичные).
Логи аудита должны также уходить на удаленную систему.

### Решение


1. Разворачивание 2 виртуальные машины: web и log в Vagrant

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

````bash
ansible@ansible:~/LOGGER$ vagrant status
Current machine states:

web                       running (virtualbox)
log                       running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
````

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

````bash
vagrant@log:~$ apt list rsyslog
Listing... Done
rsyslog/jammy-updates,jammy-security,now 8.2112.0-2ubuntu2.2 amd64 [installed,automatic]
N: There is 1 additional version. Please use the '-a' switch to see it
````


````bash
# provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# provides TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")


# Add remote logs
$template RemoteLogs,"/var/log/rsyslog/%HOSTNAME%/%PROGRAMME%.log"
*.* ?RemoteLogs
& ~
````


````bash
vagrant@log:~$ systemctl restart rsyslog
````

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
```


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

````bash
vagrant@log:/var/log/rsyslog/web$ cat nginx_access.log
Aug 21 21:18:12 web nginx_access: 192.168.56.1 - - [21/Aug/2025:21:18:12 +0300] "GET / HTTP/1.1" 200 612 "-" "curl/8.5.0"

````




