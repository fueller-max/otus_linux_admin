# Репликация PostgreSQL

## Цель

Научиться настраивать репликацию и создавать резервные копии в СУБД PostgreSQL

### Задание

1. Настроить hot_standby репликацию с использованием слотов
2. Настроить правильное резервное копирование

### Решение


1. Настройка hot_standby репликации с использованием слотов

На машинах node1 и node2 устанавливаем postgresql-server актуальной на данный момент версии:


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

* Правим конфигурацию

```bash
master@node1:~$ sudo vi /etc/postgresql/18/main/postgresql.conf
```

```bash
master@node1:~$ sudo vi /etc/postgresql/18/main/pg_hba.conf
```


#### На хосте node2:

```bash
master@node2:~$ sudo systemctl stop postgresql
```
* Делаем физический бекап сервера(node1):

```bash
master@node2:~$ pg_basebackup -h 192.168.20.228 -U replicator -D /var/lib/postgresql/18/main -P -R
Password:
23656/23656 kB (100%), 1/1 tablespace
```

```bash
master@node2:~$ systemctl start postgresql
```

```bash
postgres=# select * from pg_stat_replication;
 pid  | usesysid |  usename   | application_name |  client_addr   | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn | write_lag | flush_lag | replay_lag | sync_priority | sync_state |          reply_time         
------+----------+------------+------------------+----------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------+-----------+------------+---------------+------------+-------------------------------
 2470 |    16388 | replicator | 18/main          | 192.168.20.229 |                 |       37108 | 2025-10-29 07:06:35.034883-03 |              | streaming | 0/7000168 | 0/7000168 | 0/7000168 | 0/7000168  |           |           |            |             0 | async      | 2025-10-29 07:07:45.094904-03
(1 row)


```

```bash
postgres=# select * from pg_stat_wal_receiver;
 pid  |  status   | receive_start_lsn | receive_start_tli | written_lsn | flushed_lsn | received_tli |      last_msg_send_time       |     last_msg_receipt_time     | latest_end_lsn |        latest_end_time        | slot_name |  sender_host   | sender_port |                                                                                                                                                                                 conninfo                                                                                                                                                                 
------+-----------+-------------------+-------------------+-------------+-------------+--------------+-------------------------------+-------------------------------+----------------+-------------------------------+-----------+----------------+-------------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 2071 | streaming | 0/7000000         |                 1 | 0/7000168   | 0/7000168   |            1 | 2025-10-29 10:10:05.136156+00 | 2025-10-29 10:10:05.139478+00 | 0/7000168      | 2025-10-29 10:06:35.059465+00 |           | 192.168.20.228 |        5432 | user=replicator password=******** channel_binding=prefer dbname=replication host=192.168.20.228 port=5432 fallback_application_name=18/main sslmode=prefer sslnegotiation=postgres sslcompression=0 sslcertmode=allow sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres gssdelegation=0 target_session_attrs=any load_balance_hosts=disable
(1 row)

```


```bash
postgres=# CREATE DATABASE otus_test;
CREATE DATABASE
```

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

