# Репликация PostgreSQL

## Цель

Научиться настраивать репликацию и создавать резервные копии в СУБД PostgreSQL

### Задание

1. Настроить hot_standby репликацию с использованием слотов
2. Настроить резервное копирование с использованием Barman
3. Автоматизация процессов

### Решение


#### 1. Настройка hot_standby репликации с использованием слотов

* На машинах node1 и node2 устанавливаем postgresql-server актуальной (18) на данный момент версии:


```bash
master@node1:~$ sudo apt install -y postgresql-common ca-certificates
master@node1:~$ sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
master@node1:~$ sudo apt update
master@node1:~$ sudo apt install postgresql-18 postgresql-contrib-18
master@node1:~$ sudo systemctl start postgresql
master@node1:~$ sudo systemctl enable postgresql
```

```bash
master@node1:~$ sudo systemctl status postgresql
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/usr/lib/systemd/system/postgresql.service; enabled; preset: enabled)
     Active: active (exited) since Tue 2025-10-28 16:40:43 UTC; 4min 14s ago
   Main PID: 2134 (code=exited, status=0/SUCCESS)
        CPU: 1ms

Oct 28 16:40:43 node1 systemd[1]: Starting postgresql.service - PostgreSQL RDBMS...
Oct 28 16:40:43 node1 systemd[1]: Finished postgresql.service - PostgreSQL RDBMS.
```

#### На хосте node1: 

* Создаем пользователя replicator

```bash
master@node1:~$ sudo -u postgres psql
psql (18.0 (Ubuntu 18.0-1.pgdg24.04+3))
Type "help" for help.

postgres=# CREATE USER replicator WITH REPLICATION Encrypted PASSWORD 'Otus2022!';
CREATE ROLE
```

* Правим конфигурацию в postgresql.conf:

```bash
master@node1:~$ sudo vi /etc/postgresql/18/main/postgresql.conf
```

 Основные настройки, касаемые репликации:

```bash
listen_addresses = 'localhost, 192.168.20.228'
hot_standby = on
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3
hot_standby_feedback = on
```

В файле pg_hba.conf добавляем пользователя "replicator" для IP node1,2 c ролью репликации: 

```bash
master@node1:~$ sudo vi /etc/postgresql/18/main/pg_hba.conf

host    replication     replicator     192.168.20.228/32       scram-sha-256
host    replication     replicator     192.168.20.229/32       scram-sha-256
```


#### На хосте node2:

* Останавливаем postgresql:

```bash
master@node2:~$ sudo systemctl stop postgresql
```

* Делаем физический бекап сервера(node1) на node2 с использованием pg_basebackup в папку /var/lib/postgresql/18/main:

```bash
master@node2:~$ pg_basebackup -h 192.168.20.228 -U replicator -D /var/lib/postgresql/18/main -P -R
Password:
23656/23656 kB (100%), 1/1 tablespace
```
Важно, директория /var/lib/postgresql/18/main должна быть пустой перед выполнением процедуры. Также важно следить за правами пользователя/группы для данных директорий/файлов.

* Запускаем postgresql

```bash
master@node2:~$ systemctl start postgresql
```

* На мастере (node1) смотрим ссотяние репликации с использованием pg_stat_replication:

```bash
postgres=# select * from pg_stat_replication;
 pid  | usesysid |  usename   | application_name |  client_addr   | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | write_lag | flush_lag | replay_lag | sync_priority | sync_state |          reply_time         
------+----------+------------+------------------+----------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------+-----------+------------+---------------+------------+-------------------------------
 2470 |    16388 | replicator | 18/main          | 192.168.20.229 |                 |       37108 | 2025-10-29 07:06:35.034883-03 |              | streaming | 0/7000168 | 0/7000168 | 0/7000168 | 0/7000168  |           |           |            |             0 | async      | 2025-10-29 07:07:45.094904-03
(1 row)
```

Видим, что репликация активна, в строке client_addr видим IP node2.

На стороне клиента(node2) также проверяем состояние репликации с использованием pg_stat_wal_receiver:

```bash
postgres=# select * from pg_stat_wal_receiver;
 pid  |  status   | receive_start_lsn | receive_start_tli | written_lsn | flushed_lsn | received_tli |      last_msg_send_time       |     last_msg_receipt_time     | latest_end_lsn |        latest_end_time        | slot_name |  sender_host   | sender_port |                                                                                                                                                                                 conninfo                                                                                                                                                                 
------+-----------+-------------------+-------------------+-------------+-------------+--------------+-------------------------------+-------------------------------+----------------+-------------------------------+-----------+----------------+-------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 2071 | streaming | 0/7000000         |                 1 | 0/7000168   | 0/7000168   |            1 | 2025-10-29 10:10:05.136156+00 | 2025-10-29 10:10:05.139478+00 | 0/7000168      | 2025-10-29 10:06:35.059465+00 |           | 192.168.20.228 |        5432 | user=replicator password=******** channel_binding=prefer dbname=replication host=192.168.20.228 port=5432 fallback_application_name=18/main sslmode=prefer sslnegotiation=postgres sslcompression=0 sslcertmode=allow sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres gssdelegation=0 target_session_attrs=any load_balance_hosts=disable
(1 row)

```

* Проверим работу репликации путем создания тестовой БД на мастере:

```bash
postgres=# CREATE DATABASE otus_test;
CREATE DATABASE
```

На слейве видим, что БД "otus_test" также появлиась:
```bash
postgres-# \l
                                                     List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+-------------+-------------+--------+-----------+-----------------------
 otus_test | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
 postgres  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
 template0 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
(4 rows)

```
что говорит о том, что репликация работает. 

#### 2. Настройка резервного копирование с использованием Barman

В данном разделе настроим бекапы с postgress-сервера с использованием Barman:

![](/Lab29_Postgres/pics/Barman_Postgres_bkp.jpg)


<mark>
1. A standard connection to PostgreSQL for management, coordination, and monitoring purposes <br>
2. An SSH connection for base backup operations to be used by rsync that allows the barman user on the Barman server to connect as postgres user on the PostgreSQL server<br>
3. An SSH connection for WAL archiving to be used by the archive_command in PostgreSQL and that allows the postgres user on the PostgreSQL server to connect as barman user on the Barman server<br>
4. Starting from PostgreSQL 9.2, you can add a streaming replication connection that is used for WAL streaming and significantly reduce RPO. This more robust implementation is depicted in figure</mark>

<br>
<br>
<br>

* На хостах node1 и node2 установливаем утилиту barman-cli:

```bash
master@node1:~$ sudo apt install barman-cli
```

* На хосте barman выполняем устанавливаем barman-cli, barman и postgresql-18:

```bash
master@barman:~$ sudo apt install barman-cli barman

master@node1:~$ sudo apt install -y postgresql-common ca-certificates
master@node1:~$ sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
master@node1:~$ sudo apt update
master@node1:~$ sudo apt install postgresql-18 postgresql-contrib-18
master@node1:~$ sudo systemctl start postgresql
master@node1:~$ sudo systemctl enable postgresql
```

* На хостах barman и node1 генерируем ssh-ключи и обмениваемся ими, чтобы обеспечить двусторонний доступ по ssh между хостами:

```bash
barman@barman:/home/barman$ ssh-keygen -t rsa -b 4096
Generating public/private rsa key pair.
Enter file in which to save the key (/var/lib/barman/.ssh/id_rsa):
/var/lib/barman/.ssh/id_rsa already exists.
Overwrite (y/n)? y
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /var/lib/barman/.ssh/id_rsa
Your public key has been saved in /var/lib/barman/.ssh/id_rsa.pub
```

```bash
postgres@node1:/home/master$ ssh-keygen -t rsa -b 4096
Generating public/private rsa key pair.
Enter file in which to save the key (/var/lib/postgresql/.ssh/id_rsa):
Created directory '/var/lib/postgresql/.ssh'.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /var/lib/postgresql/.ssh/id_rsa
Your public key has been saved in /var/lib/postgresql/.ssh/id_rsa.pub
```

* Проверяем доступ по ssh с обоих хостов:

```bash
postgres@node1:~/.ssh$ ssh barman@192.168.20.230
barman@barman:~$

barman@barman:/home/barman$ ssh postgres@192.168.20.228
postgres@node1:~$ exit
```

* На node1 создаём пользователя barman c правами суперпользователя:

```bash
master@node1:/$ sudo -u postgres psql

postgres=# CREATE USER barman WITH PASSWORD 'Otus2022!' SUPERUSER REPLICATION;
CREATE ROLE
```

* На node1 в файле pg_hba.conf добавляем разрешения для пользователя barman:

```bash
master@node1:/$ sudo cat /etc/postgresql/18/main/pg_hba.conf

host    all             barman         192.168.20.230/32        scram-sha-256
host    replication     barman         192.168.20.230/32        scram-sha-256

master@node1:/$ systemctl restart postgresql
```

* Создаем тестовую БД otus и в ней таблицу test:

```bash
master@node1:/$ sudo -u postgres psql

postgres=# CREATE DATABASE otus;
CREATE DATABASE
postgres=# CREATE TABLE test (id int, name varchar(30));
CREATE TABLE                                  ^
postgres=# INSERT INTO test VALUES (1,' alex');
INSERT 0 1
```

* На ноде barman создаем файл .pgpass с параметрами доступа к postgress-серверу. Также настраиваем режим доступа к файлу (600)
 
```bash
barman@barman:~$ touch ~/.pgpass

192.168.20.228:5432:*:barman:Otus2022!

barman@barman:~$ chmod 600 ~/.pgpass
```

* После настройки пробуем подключиться к postgress-серверу:
```bash
barman@barman:~$ psql -h 192.168.20.228 -U barman -d postgres
psql (16.10 (Ubuntu 16.10-0ubuntu0.24.04.1), server 18.0 (Ubuntu 18.0-1.pgdg24.04+3))
WARNING: psql major version 16, server major version 18.
         Some psql features might not work.
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)
Type "help" for help.
postgres=>
```

видим, что подключение прошло успешно.

* Проверяем репликацию: 

```bash
barman@barman:~$ psql -h 192.168.20.228 -U barman -c "IDENTIFY_SYSTEM" replication=1
      systemid       | timeline |  xlogpos  | dbname
---------------------+----------+-----------+--------
 7566314089526366895 |        1 | 0/789C1B0 |
(1 row)

```

* Редактируем файл /etc/barman.conf с базовыми настройками:

```bash
last_backup_maximum_age = 4 DAYS
minimum_redundancy = 1
retention_policy = REDUNDANCY 3
backup_method = rsync
```

* Создаем  конфигурационный файл /etc/barman.d/node1.conf c параметрами для node1:

```bash
[node1]
description = "backup node1"

ssh_command = ssh postgres@192.168.20.228
conninfo = host=192.168.20.228 user=barman port=5432 dbname=postgres

retention_policy_mode = auto
retention_policy = RECOVERY WINDOW OF 7 days
wal_retention_policy = main
streaming_archiver=on

path_prefix = /usr/lib/postgresql/18/bin
create_slot = auto
slot_name = node1

#Setup for WAL streaming
streaming_conninfo = host=192.168.20.228 user=barman
backup_method = postgres
archiver = off
```


* Создаем слот для node1

```bash
barman@barman:/home/master$ barman receive-wal --create-slot node1
Creating physical replication slot 'node1' on server 'node1'
Replication slot 'node1' created

```

* Проверим работу barman:

```bash
barman@barman:/home/master$ barman switch-wal node1
The WAL file 000000010000000000000008 has been closed on server 'node1'
barman@barman:/home/master$ barman cron
Starting WAL archiving for server node1
barman@barman:/home/master$ barman check node1
Server node1:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
        backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
        backup minimum size: OK (0 B)
        wal maximum age: OK (no last_wal_maximum_age provided)
        wal size: OK (0 B)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
        minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK (no system Id stored on disk)
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK

```

Видим, что по всем пунктам за исключением backup maximum age и minimum redundancy requirements OK, значит система бекапов работает корректно.

* Сделаем бекап node1:

```bash
barman@barman:/home/master$ barman backup node1
Starting backup using postgres method for server node1 in /var/lib/barman/node1/base/20251103T102811
Backup start at LSN: 0/9000168 (000000010000000000000009, 00000168)
Starting backup copy via pg_basebackup for 20251103T102811
WARNING: pg_basebackup does not copy the PostgreSQL configuration files that reside outside PGDATA. Please manually backup the following files:
        /etc/postgresql/18/main/postgresql.conf
        /etc/postgresql/18/main/pg_hba.conf
        /etc/postgresql/18/main/pg_ident.conf

Copy done (time: 3 seconds)
Finalising the backup.
This is the first backup for server node1
WAL segments preceding the current backup have been found:
        000000010000000000000008 from server node1 has been removed
Backup size: 37.7 MiB
Backup end at LSN: 0/B000000 (00000001000000000000000B, 00000000)
Backup completed (start time: 2025-11-03 10:28:11.649988, elapsed time: 3 seconds)
Processing xlog segments from streaming for node1
        000000010000000000000009
WARNING: IMPORTANT: this backup is classified as WAITING_FOR_WALS, meaning that Barman has not received yet all the required WAL files for the backup consistency.
This is a common behaviour in concurrent backup scenarios, and Barman automatically set the backup as DONE once all the required WAL files have been archived.
Hint: execute the backup command with '--wait'
```

* Выведем список бекапов:
```bash
barman@barman:/home/master$ barman list-backup node1
node1 20251103T102811 - Mon Nov  3 07:28:15 2025 - Size: 37.7 MiB - WAL Size: 0 B - WAITING_FOR_WALS
```

Видим, что бекап успешно выполнился.


* Для теста дропнем базы otus и выполним восстановление:

```bash
postgres=# \d
        List of relations
 Schema | Name | Type  |  Owner
--------+------+-------+----------
 public | test | table | postgres
(1 row)

postgres=# \l
                                                     List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+-------------+-------------+--------+-----------+-----------------------
 otus      | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
 otus_test | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
 postgres  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =Tc/postgres         +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template0 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
(5 rows)

postgres=# DROP DATABASE otus;
DROP DATABASE
postgres=# DROP DATABASE otus_test;
DROP DATABASE
postgres=# \l
                                                     List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+-------------+-------------+--------+-----------+-----------------------
 postgres  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =Tc/postgres         +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template0 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
(3 rows)
```


* Запускаем восстановление из бекапа:

```bash
barman@barman:/home/master$ barman recover node1 20251103T102811 /var/lib/postgresql/18/main/ --remote-ssh-comman "ssh postgres@192.168.20.228"
Starting remote restore for server node1 using backup 20251103T102811
Destination directory: /var/lib/postgresql/18/main/
Remote command: ssh postgres@192.168.20.228
WARNING
The following configuration files have not been saved during backup, hence they have not been restored.
You need to manually restore them in order to start the recovered PostgreSQL instance:

    postgresql.conf
    pg_hba.conf
    pg_ident.conf

Recovery completed (start time: 2025-11-03 10:37:26.015062+00:00, elapsed time: 5 seconds)
Your PostgreSQL server has been successfully prepared for recovery!

```
* Далее перезагружаем Postgres и проверяем наличие удаленных баз данных:

```bash
master@node1:/$ systemctl restart postgresql

```

```bash
postgres=# \l
                                                     List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+-------------+-------------+--------+-----------+-----------------------
 otus      | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
 otus_test | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
 postgres  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =Tc/postgres         +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template0 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
```

#### 3. Автоматизация процессов

Выполним автоматизацию настроенных процессов выше с использованием ansible. Настройку выполним на трех отдельных "свежих" остах.

Для настройки реплиакции создадим две роли ansible:  install_postgress и postgres_replication 

<details>
  <summary><b>install_postgress main.yaml</summary>

```bash
  #SPDX-License-Identifier: MIT-0
---
# tasks file for install_postgres

#Install PostgreSQL 18
 
- name: Update apt cache
  ansible.builtin.apt:
      update_cache: yes
      cache_valid_time: 3600

- name: Install required packages for apt repository management
  ansible.builtin.apt:
      name:
        - apt-transport-https
        - ca-certificates
        - curl
        - gnupg
      state: present

- name: Add PostgreSQL GPG key
  ansible.builtin.apt_key:
      url: https://www.postgresql.org/media/keys/ACCC4CF8.asc
      state: present

- name: Add PostgreSQL 18 repository
  ansible.builtin.apt_repository:
      repo: deb http://apt.postgresql.org/pub/repos/apt/ {{ ansible_distribution_release }}-pgdg main
      state: present
      filename: pgdg

- name: Install PostgreSQL 18 server and client
  ansible.builtin.apt:
      name:
        - postgresql-18
        - postgresql-client-18
        - postgresql-contrib-18
      state: present

- name: Ensure PostgreSQL service is running and enabled
  ansible.builtin.service:
      name: postgresql
      state: started
      enabled: yes

```
</details>

<details>
  <summary><b>postgres_replication main.yaml</summary>

```bash
#SPDX-License-Identifier: MIT-0
---
# tasks file for postgres_replication
- name: install Python tools 
  apt: 
    name: 
     - python3-pip
     - python3-dev
     - libpq-dev  
    state: present 
    update_cache: true
  
# Setup of node1

- name: Copy postgresql.conf to node1
  template: 
    src: postgresql.conf.j2 
    dest: /etc/postgresql/18/main/postgresql.conf 
    owner: postgres
    group: postgres 
    mode: '0600' 
  when: (ansible_hostname == "node1")

- name: copy pg_hba.conf to node1 
  template: 
    src: pg_hba.conf.j2 
    dest: /etc/postgresql/18/main/pg_hba.conf 
    owner: postgres 
    group: postgres 
    mode: '0600' 
  when: (ansible_hostname == "node1")

- name: Restart postgresql-server on node1 
  service: 
    name: postgresql 
    state: restarted 
  when: (ansible_hostname == "node1")   

- name: Create PostgreSQL user replicator on node1 (master) # setfacl must be present on the remote host!
  become: true
  become_user: postgres
  postgresql_user: 
    name: replicator 
    password: '{{ replicator_password }}' 
    role_attr_flags: REPLICATION 
  when: (ansible_hostname == "node1")

# --- End of node 1 setup           ----

# --- Setup of node2                ----

- name: Stop postgresql-server on node2 
  service: 
     name: postgresql 
     state: stopped 
  when: (ansible_hostname == "node2")

- name: Remove files from data catalog 
  file: 
    path: /var/lib/postgresql/18/main/ 
    state: absent 
  when: (ansible_hostname == "node2")

- name: Copy files from master to slave 
  expect: 
    command: 'pg_basebackup -h {{ master_ip }} -U replicator -p 5432 -D /var/lib/postgresql/18/main/ -R -P' 
    responses: 
      Password: "{{ replicator_password }}" 
  when: (ansible_hostname == "node2")

- name: Recursively set ownership of /var/lib/postgresql/18/main/
  ansible.builtin.file:
        path: /var/lib/postgresql/18/main/
        state: directory
        recurse: yes
        owner: postgres
        group: postgres  
  when: (ansible_hostname == "node2")      

- name: Copy postgresql.conf to node2
  template: 
    src: postgresql.conf.j2 
    dest: /etc/postgresql/18/main/postgresql.conf 
    owner: postgres
    group: postgres 
    mode: '0600' 
  when: (ansible_hostname == "node2")

- name: copy pg_hba.conf to node2 
  template: 
    src: pg_hba.conf.j2 
    dest: /etc/postgresql/18/main/pg_hba.conf 
    owner: postgres 
    group: postgres 
    mode: '0600' 
  when: (ansible_hostname == "node2")

- name: Start postgresql-server on node2 
  service: 
    name: postgresql 
    state: started 
  when: (ansible_hostname == "node2")  

# --- end of node 2 setup           ----
```
</details>

Для настройки Barman создадим роль install barman:

<details>
  <summary><b>install barman main.yaml</summary>

```bash
#SPDX-License-Identifier: MIT-0
---
# tasks file for install_barman

- name: Install barman-cli packages on node1
  apt: 
    name: 
      - barman-cli 
    state: present 
    update_cache: true 
  when: (ansible_hostname != "barman")

- name: Install barman and barman-cli packages on barman
  apt: 
    name: 
      - barman 
      - barman-cli 
    state: present 
    update_cache: true 
  when: (ansible_hostname == "barman")


# --- Setup SSH infrustruture   ------

- name: Generate SSH key for postgres 
  user: 
    name: postgres 
    generate_ssh_key: yes 
    ssh_key_type: rsa 
    ssh_key_bits: 4096 
    force: no 
  when: (ansible_hostname == "node1")

- name: Generate SSH key for barman 
  user: 
    name: barman 
    uid: 994 
    shell: /bin/bash 
    generate_ssh_key: yes 
    ssh_key_type: rsa 
    ssh_key_bits: 4096 
    force: no 
  when: (ansible_hostname == "barman")

   # --- node1 -> barman   ----

- name: Get public key from node1 
  shell: cat /var/lib/postgresql/.ssh/id_rsa.pub 
  register: ssh_keys
  when: (ansible_hostname == "node1")

- name: Transfer public key to barman 
  delegate_to: barman 
  authorized_key: 
    key: "{{ ssh_keys.stdout }}"
    comment: "{{ansible_hostname}}" 
    user: barman 
  when: (ansible_hostname == "node1")   

   # ---   end   ----
  
   # --- barman -> node1   ----

- name: Fetch all public ssh keys from barman 
  shell: cat /var/lib/barman/.ssh/id_rsa.pub 
  register: ssh_keys 
  when: (ansible_hostname == "barman")

- name: Transfer public key to barman 
  delegate_to: node1
  authorized_key:
     key: "{{ ssh_keys.stdout }}" 
     comment: "{{ansible_hostname}}" 
     user: postgres 
  when: (ansible_hostname == "barman")

   # ---   end   ----

# ----     END SSH              ------  

- name: Create barman user on node 1
  become: true
  become_user: postgres 
  postgresql_user: 
    name: barman 
    password: '{{ barman_user_password }}' 
    role_attr_flags: SUPERUSER 
  when: (ansible_hostname == "node1")

- name: Add permission for barman in pg_hba.conf 
  lineinfile: 
    path: /etc/postgresql/18/main/pg_hba.conf 
    line: 'host all {{ barman_user }} {{ barman_ip }}/32 scram-sha-256'
  when: (ansible_hostname == "node1")

- name: Add permission for barman in pg_hba.conf 
  lineinfile: 
     path: /etc/postgresql/18/main/pg_hba.conf 
     line: 'host replication {{ barman_user }} {{ barman_ip }}/32 scram-sha-256'
  when: (ansible_hostname == "node1")

- name: Restart postgresql-server on node1 
  service: 
    name: postgresql 
    state: restarted 
  when: (ansible_hostname == "node1")  

- name: Copy .pgpass to barman 
  template: 
    src: .pgpass.j2 
    dest: /var/lib/barman/.pgpass 
    owner: barman 
    group: barman 
    mode: '0600' 
  when: (ansible_hostname == "barman")

- name: Copy barman.conf to barman
  template: 
    src: barman.conf.j2 
    dest: /etc/barman.conf 
    owner: barman 
    group: barman 
    mode: '0755' 
  when: (ansible_hostname == "barman") 

- name: Copy node1.conf to barman
  template: 
     src: node1.conf.j2 
     dest: /etc/barman.d/node1.conf 
     owner: barman 
     group: barman 
     mode: '0755' 
  when: (ansible_hostname == "barman") 

- name: Barman switch-wal node1 
  become_user: barman 
  shell: barman switch-wal node1 
  when: (ansible_hostname == "barman")  

- name: Barman cron 
  become_user: barman 
  shell: barman cron 
  when: (ansible_hostname == "barman")    
```
</details>


Основной playbook:

<details>
  <summary><b>provision.yaml </summary>
 
 ```bash
- name: PostgreSQL infrastructure setup
  hosts: all 
  become: yes 
  tasks:

- name: Install postgres 18 and setup replication on node1,2
  hosts: node1,node2 
  become: yes 
  roles: 
    - install_postgres 
    - postgres_replication

- name: Install postgres 18 on barman host
  hosts: barman 
  become: yes 
  roles: 
    - install_postgres    

- name: Setup backup using Barman 
  hosts: node1,barman 
  become: yes 
  roles:
    - install_barman 
 ```
</details>


Все сопутствующие файлы (конфиги, темплейты) представлены в соответствующих директориях основной директории "ansible".

После прогона плейбука проверяем работу репликации:

```bash
postgres=# select * from pg_stat_replication;
ate   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | write_lag | flush_lag | replay_lag | sync_priority | sync_state |          reply_time         
-------+----------+------------+------------------+----------------+-----------------+-------------+------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------+-----------+------------+---------------+------------+-------------------------------
 23210 |    16388 | replicator | 18/main          | 192.168.20.232 |                 |       58616 | 2025-11-03 13:12:57.45641-03 |              | streaming | 0/3000060 | 0/3000060 | 0/3000060 | 0/3000060  |           |           |            |             0 | async      | 2025-11-03 13:15:26.139762-03
(1 row)
```

```bash
postgres=# select * from pg_stat_wal_receiver;
ceipt_time     | latest_end_lsn |       latest_end_time       | slot_name |  sender_host   | sender_port |                                                                                                                                                                                 conninfo                                                                                                                                                                  
-------+-----------+-------------------+-------------------+-------------+-------------+--------------+-------------------------------+-------------------------------+----------------+-----------------------------+-----------+----------------+-------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 22152 | streaming | 0/3000000         |                 1 | 0/3000060   | 0/3000060   |            1 | 2025-11-03 13:16:36.164545-03 | 2025-11-03 13:16:36.157219-03 | 0/3000060      | 2025-11-03 13:13:06.0785-03 |           | 192.168.20.231 |        5432 | user=replicator password=******** channel_binding=prefer dbname=replication host=192.168.20.231 port=5432 fallback_application_name=18/main sslmode=prefer sslnegotiation=postgres sslcompression=0 sslcertmode=allow sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres gssdelegation=0 target_session_attrs=any load_balance_hosts=disable
(1 row)
```

Видим, что репликация запустилась успешно. 


Далее проверяем работу бекапов с использованием Barman:

```bash
barman@barman:/home/master$ barman check node
Server node1:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
2025-11-04 08:13:09,090 [13709] barman.server ERROR: Check 'backup maximum age' failed for server 'node1'
        backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
        backup minimum size: OK (0 B)
        wal maximum age: OK (no last_wal_maximum_age provided)
        wal size: OK (0 B)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
2025-11-04 08:13:09,090 [13709] barman.server ERROR: Check 'minimum redundancy requirements' failed for server 'node1'
        minimum redundancy requirements: FAILED (have 0 non-incremental backups, expected at least 1)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK (no system Id stored on disk)
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK
```

Также видим, что бекап-хост Barman успешно подключился к ноде1.
