# DNS

## Цель

Изучить основы DNS, научиться работать с технологией Split-DNS в Linux-based системах

### Задание

1. Запустить стенд с двумя серверами(ns01,ns02) DNS в режиме master/slave c двумя клиентам(client1, client2)
 * развернуть стенд с 4- мя ВМ.
 * завести в зоне dns.lab имена:
 * web1 - смотрит на client1
 * web2 смотрит на client2
 * завести еще одну зону dnsnew.lab
 * завести в ней запись www
 * www - смотрит на обоих клиентов
2. Настроить split-dns
 * клиент1 - видит обе зоны, но в зоне dns.lab только web1
 * клиент2 видит только dns.lab

### Решение

#### 1. Разворачивание стендf с двумя серверами(ns01,ns02) DNS в режиме master/slave c двумя клиентам(client1, client2)

Для разворчивания стенда воспользуемся средой EVE-NG, где развернем 4-е виртуальные машины:

![](/Lab24_DNS/pics/lab_eve.jpg)

Имеются 2 виртуальные машины ns01,ns02 выполняющие функции DNS серверов, а также два клиента client1 и client2.

Сеть DNS_Net 172.16.20.0/24

Приведем конфигруацию основного DNS сервера ns01 master-named.conf :

````bash
options {

    directory 	"/var/cache/bind";        // Store  zone cache file

	listen-on port 53 { 172.16.20.10; };  // isten on a specific IP 

	recursion yes;                        // Enable recursive queries for local clients
	allow-query     { any; };             // Allow queries from any client
    allow-transfer { any; };              // Allow transfer to a slave DNS

     forwarders {
        1.1.1.1;                           // Example: Cloudflare
        8.8.8.8;                           // Example: Google
    };
 
	dnssec-validation auto;
};

logging {
  
   channel query_syslog {                 // Define a channel for query logs to syslog
        syslog local4;
        severity debug;
        print-time yes;
        print-severity yes;
    };
   
    category queries { query_syslog; };
};


                                           // ZONE TRANSFER WITH TSIG
include "/etc/bind/named.zonetransfer.key"; 
server 172.16.20.11 {
    keys { "zonetransfer.key"; };
};

                                           // root zone
zone "." IN {
	type hint;
	file "/etc/bind/db.0";
};

                                          // zones like localhost
include "/etc/bind/zones.rfc1918";
// root's DNSKEY
//include "/etc/named.root.key";

// lab's zone
zone "dns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    file "/etc/bind/named.dns.lab";
};

zone "dnsnew.lab" {
     type master;
     allow-transfer { key "zonetransfer.key"; };
     allow-update { key "zonetransfer.key"; };
     file "/etc/bind/named.dnsnew.lab";
};

// lab's zone reverse
zone "20.16.172.in-addr.arpa" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    file "/etc/bind/named.dns.lab.rev";
};

// lab's ddns zone
zone "ddns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    allow-update { key "zonetransfer.key"; };
    file "/etc/bind/named.ddns.lab";
};

````

В данной конфигурации определяем опции - раздел options, где определяем основные параметры - IP/порт, возможность трансфера зон, а также форвардинг к внешнему DNS серверу.

Также в файле прописаны зоны, которые DNS сервер сможет отрезолвить.

Сейчас там прописаны три зоны:

* dns.lab
* ddns.lab
* dnsnew.lab

Последняя зона добавлена дополнительно в соотвествии с заданием.

Для каждой зоны должен быть определен файл с определениями данной зоны. Для вновь созданной зоны приведем содержание данного файла named.dnsnew.lab:

````bash
$TTL 3600
$ORIGIN dnsnew.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       172.16.20.10
ns02            IN      A       172.16.20.11

; WWW 
www            IN      A       172.16.20.15 
www            IN      A       172.16.20.16 
````

В данном файле прописываются параметры для DNS записей (время жизни, попытки и пр..), а также имена для резолвинга.
В данном случае резолвится должны доменные имена:

* ns01.dnsnew.lab
* ns02.dnsnew.lab
* www.dnsnew.lab


Также формируется файл для secondary DNS сервера - slave-named.conf - по схожей схеме, но с учетом того, что он secondary и должен быть slave`ом по отношению к основному серверу. Его содержимое не будем приводить, файл находится в общей папке ansible/files.

После подготовки всех файлов, запускаем плейбуки для настройки серверов и клиентов.

Сначала запускаем provision.yaml для установки пакета bind9 (для Debian based систем), а также сразу копируем ключ named.zonetransfer.key для передачи зон.

```bash
- name: Basic setup of DNS system 
  hosts: servers
  become: yes
  tasks:
  - name: Install bind, bind-uitls
    apt:
        name:
          - bind9
          - bind9-utils
        state: present
        update_cache: yes

  - name: Copy named.zonetransfer.key 
    copy:
      src: named.zonetransfer.key
      dest: /etc/bind/named.zonetransfer.key
      owner: bind
      group: bind
      mode: 0644
```

После этого запускаем плейбук server.yaml - основной плейбук для настройки серверов.

Здесь приведем только часть для ns01 (для ns02 действия аналогичные). Задача плейбука:

* скопировать основной файл с настройками сервера named.conf
* скопировать файлы с описанием каждой из зон: named.dns.lab, named.ddns.lab и т.д.
* перезапустить bind9 (named)

```bash
---
- name: Setup of ns01 (name server 1)
  hosts: ns01
  become: yes
  tasks:
  - name: Copy named.conf 
    copy:
      src: master-named.conf
      dest: /etc/bind/named.conf
      owner: user
      group: bind
      mode: 0644
      
  - name: Copy zones 
    copy:
      src: "{{ item }}"
      dest: /etc/bind/
      owner: user
      group: bind
      mode: 0644
    loop: "{{ query('ansible.builtin.fileglob', 'named.d*') }}"

  - name: Copy resolv.conf 
    template:
      src: servers-resolv.conf.j2
      dest: /etc/resolv.conf
      owner: user
      group: bind
      mode: 0644 

  - name: set /etc/bind permissions
    file: 
     path: /etc/bind
     state: directory
     owner: user
     group: bind 
     mode: 0755 
     recurse: yes 

  - name: ensure named is running and enabled
    service:
     name: bind9 
     state: restarted 
     enabled: yes   
```

Настройка клиентов очень проста и в основе сводится к копированию  файла resolv.conf с указанием адресов DNS серверов, к которым клиенты будут обращаться:

```bash
domain dns.lab
search dns.lab
nameserver 172.16.20.10
nameserver 172.16.20.11
```

После отработки всех плейбуков проверям работоспосбность системы DNS.

Для проверки используем утилиту dig и сделаем запросы к обоим DNS серверу:
 
* ns01.dns.lab, сервер ns01:

````bash

user@client1:~$ dig @172.16.20.10 ns01.dns.lab

; <<>> DiG 9.18.39-0ubuntu0.24.04.1-Ubuntu <<>> @172.16.20.10 ns01.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 4793
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 54a080ddbecf5f1a0100000068d8f0f9bab5ed16f5c9892d (good)
;; QUESTION SECTION:
;ns01.dns.lab.                  IN      A

;; ANSWER SECTION:
ns01.dns.lab.           3600    IN      A       172.16.20.10

;; Query time: 0 msec
;; SERVER: 172.16.20.10#53(172.16.20.10) (UDP)
;; WHEN: Sun Sep 28 08:25:29 UTC 2025
;; MSG SIZE  rcvd: 85
````

* web2.dns.lab, сервер ns02:

```bash
user@client1:~$ dig @172.16.20.11 web2.dns.lab

; <<>> DiG 9.18.39-0ubuntu0.24.04.1-Ubuntu <<>> @172.16.20.11 web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 61074
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 03e0fd1b491edbdc0100000068d8f1e985ee4142797a8681 (good)
;; QUESTION SECTION:
;web2.dns.lab.                  IN      A

;; ANSWER SECTION:
web2.dns.lab.           3600    IN      A       172.16.20.16

;; Query time: 1 msec
;; SERVER: 172.16.20.11#53(172.16.20.11) (UDP)
;; WHEN: Sun Sep 28 08:29:29 UTC 2025
;; MSG SIZE  rcvd: 85
```


* www.dnsnew.lab, сервер ns02:

````bash
user@client1:~$ dig @172.16.20.11 www.dnsnew.lab

; <<>> DiG 9.18.39-0ubuntu0.24.04.1-Ubuntu <<>> @172.16.20.11 www.dnsnew.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 57463
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 9d7c4e947c07957a0100000068d93b1096a361f6957962d1 (good)
;; QUESTION SECTION:
;www.dnsnew.lab.                        IN      A

;; ANSWER SECTION:
www.dnsnew.lab.         3600    IN      A       172.16.20.16
www.dnsnew.lab.         3600    IN      A       172.16.20.15

;; Query time: 1 msec
;; SERVER: 172.16.20.11#53(172.16.20.11) (UDP)
;; WHEN: Sun Sep 28 13:41:36 UTC 2025
;; MSG SIZE  rcvd: 103

````

Видим, что система отрабатывает корректно, отдавая IP по доменным именам. Причем в последнем случае для www.dnsnew.lab было возвращено два IP - в полном соотвествии с настройками зоны, где мы указали два IP. Данный подход может использоваться для балансировки нагрузки.



#### 2. Настройка Split-DNS

В соотвествии с заданием в уже имеющихся зонах необходимо релизовать следующее: 

client1 должен:

 * видеть запись web1.dns.lab 
 * не видеть запись web2.dns.lab. 

 client2:
 * может видеть обе записи из домена dns.lab
 * не должен видеть записи домена dnsnew.lab 
 
 Осуществить данные настройки нам поможет технология Split-DNS. Технология Split-DNS реализуется с помощью описания представлений (view), для каждого отдельного acl. В каждое представление (view) добавляются только те зоны, которые разрешено видеть хостам, адреса которых указаны в access листе.

 В соотвествии с требованиями реализуем настройки.

 В named.conf (master-named_acl.conf) вводим ACL (access lists) для каждого из клиентов и для каждого из клиентов организуем отдельный view, где настроим нужные нам зоны для каждого из клиентов. Также введем зону default для всех оставшихся клиентов.

 Дополнительно тут реализована система ключей для повышения уровня security передачи зон.
  

 ````bash
 #Key for host "client1"
key "client1-key" {
    algorithm hmac-sha256;
    secret "gigWHnZjSv7AddjBfYG6v9WnoJfpDhgUHCaAo9i6ATI=";
};

#Key for host "client1"
key "client2-key" {
    algorithm hmac-sha256;
    secret "EcEshhwXsnBQS/dRK0b0tVh9+9n1nIPB5MCKKEH2NmY=";
};

#Access lists
acl client1 { !key client2-key; key client1-key; 172.16.20.15; };
acl client2 { !key client1-key; key client2-key; 172.16.20.16; };

#View for the first client1
view client1 {

    match-clients { client1; };

    zone "dns.lab" {
      type master;
      file "/etc/bind/named.dns.lab.client";
      also-notify { 172.16.20.11 key client1-key; };
   }; 

    zone "dnsnew.lab" {
      type master;
      also-notify { 172.16.20.11 key client1-key; };
      file "/etc/bind/named.dnsnew.lab";
   };

};

#View for the first client2
view client2 {

    match-clients { client2; };

    zone "dns.lab" {
      type master;
      file "/etc/bind/named.dns.lab";
      also-notify { 172.16.20.11 key client2-key; };
   }; 

   
    zone "20.16.172.in-addr.arpa" {
      type master;
      file "/etc/bind/named.dns.lab.rev";
      also-notify { 172.16.20.11 key client2-key; };
   };

};

#default view
view "default" {
    match-clients { any; };

    zone "." IN {
	type hint;
	file "/etc/bind/db.0";
   };

    include "/etc/bind/zones.rfc1918";

   
    zone "dns.lab" {
      type master;
      allow-transfer { key "zonetransfer.key"; };
      file "/etc/bind/named.dns.lab";
    };

    zone "20.16.172.in-addr.arpa" {
      type master;
      allow-transfer { key "zonetransfer.key"; };
      file "/etc/bind/named.dns.lab.rev";
    };
    
    zone "dnsnew.lab" {
      type master;
      also-notify { 172.16.20.11 key client1-key; };
      file "/etc/bind/named.dnsnew.lab";
     };

    zone "ddns.lab" {
       type master;
       allow-transfer { key "zonetransfer.key"; };
       allow-update { key "zonetransfer.key"; };
       file "/etc/bind/named.ddns.lab";
    };
};

 ````
Для view client1 для зоны dns.lab заводим отдельный файл named.dns.lab.client, где уберем запись web2, оставив только web1.

````bash
; DNS Servers
ns01            IN      A       172.16.20.10
ns02            IN      A       172.16.20.11

; Web 
web1            IN      A       172.16.20.15 
````

Для view client2 оставляем только зону "dns.lab", а зону "dnsnew.lab" убираем. 

После запуска плейбуков, которые прогрузят измененные файлы и перезапустят службу DNS проверяем работу системы:

 Для client1:

  * www.dnsnew.lab

 ````bash
 user@client1:~$ dig @172.16.20.10 www.dnsnew.lab

; <<>> DiG 9.18.39-0ubuntu0.24.04.1-Ubuntu <<>> @172.16.20.10 www.dnsnew.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 60647
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: ee7c9c2dfcf69c130100000068d940b2910985edc8d8711f (good)
;; QUESTION SECTION:
;www.dnsnew.lab.                        IN      A

;; ANSWER SECTION:
www.dnsnew.lab.         3600    IN      A       172.16.20.15
www.dnsnew.lab.         3600    IN      A       172.16.20.16

;; Query time: 0 msec
;; SERVER: 172.16.20.10#53(172.16.20.10) (UDP)
;; WHEN: Sun Sep 28 14:05:38 UTC 2025
;; MSG SIZE  rcvd: 103
````
* web1.dns.lab

```bash
user@client1:~$ dig @172.16.20.10 web1.dns.lab

; <<>> DiG 9.18.39-0ubuntu0.24.04.1-Ubuntu <<>> @172.16.20.10 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 10945
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 43101e5e5b26e1e50100000068d940baeb5e5ca1c00b9170 (good)
;; QUESTION SECTION:
;web1.dns.lab.                  IN      A

;; ANSWER SECTION:
web1.dns.lab.           3600    IN      A       172.16.20.15

;; Query time: 0 msec
;; SERVER: 172.16.20.10#53(172.16.20.10) (UDP)
;; WHEN: Sun Sep 28 14:05:46 UTC 2025
;; MSG SIZE  rcvd: 85
```

* web2.dns.lab

```bash
user@client1:~$ dig @172.16.20.10 web2.dns.lab

; <<>> DiG 9.18.39-0ubuntu0.24.04.1-Ubuntu <<>> @172.16.20.10 web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 27287
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 45c464e6058a0be50100000068d940c0b0644c12a63a66e2 (good)
;; QUESTION SECTION:
;web2.dns.lab.                  IN      A

;; AUTHORITY SECTION:
dns.lab.                600     IN      SOA     ns01.dns.lab. root.dns.lab. 2711201407 3600 600 86400 600

;; Query time: 1 msec
;; SERVER: 172.16.20.10#53(172.16.20.10) (UDP)
;; WHEN: Sun Sep 28 14:05:52 UTC 2025
;; MSG SIZE  rcvd: 115

```

Видим, что для www.dnsnew.lab и web1.dns.lab ответ успешный, а для web2.dns.lab резолва не произошло.

Для  client2:

* web1.dns.lab

 ```bash
 user@client2:~$ dig @172.16.20.11 web1.dns.lab

; <<>> DiG 9.18.39-0ubuntu0.24.04.1-Ubuntu <<>> @172.16.20.11 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 51449
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: f3d7063287253a500100000068d941063aa81982faa50779 (good)
;; QUESTION SECTION:
;web1.dns.lab.                  IN      A

;; ANSWER SECTION:
web1.dns.lab.           3600    IN      A       172.16.20.15

;; Query time: 4 msec
;; SERVER: 172.16.20.11#53(172.16.20.11) (UDP)
;; WHEN: Sun Sep 28 14:07:02 UTC 2025
;; MSG SIZE  rcvd: 85
```
* web2.dns.lab

```bash
user@client2:~$ dig @172.16.20.11 web2.dns.lab

; <<>> DiG 9.18.39-0ubuntu0.24.04.1-Ubuntu <<>> @172.16.20.11 web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 13547
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 90e309eaf8f6b5180100000068d9410935d030936e399abb (good)
;; QUESTION SECTION:
;web2.dns.lab.                  IN      A

;; ANSWER SECTION:
web2.dns.lab.           3600    IN      A       172.16.20.16

;; Query time: 1 msec
;; SERVER: 172.16.20.11#53(172.16.20.11) (UDP)
;; WHEN: Sun Sep 28 14:07:05 UTC 2025
;; MSG SIZE  rcvd: 85
```
* www.dnsnew.lab

```bash
user@client2:~$ dig @172.16.20.11 www.dnsnew.lab

; <<>> DiG 9.18.39-0ubuntu0.24.04.1-Ubuntu <<>> @172.16.20.11 www.dnsnew.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 10251
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 7ec5afaab319f8060100000068d94112490f183549e8ec20 (good)
;; QUESTION SECTION:
;www.dnsnew.lab.                        IN      A

;; AUTHORITY SECTION:
.                       10800   IN      SOA     a.root-servers.net. nstld.verisign-grs.com. 2025092800 1800 900 604800 86400

;; Query time: 33 msec
;; SERVER: 172.16.20.11#53(172.16.20.11) (UDP)
;; WHEN: Sun Sep 28 14:07:14 UTC 2025
;; MSG SIZE  rcvd: 146
```

Видим, что для web1.dns.lab и web2.dns.lab ответы успешны, для www.dnsnew.lab резолва не произошло.

Таким образом, используя split DNS был реализован выборочный резолвинг DNS для отдельных хостов.

