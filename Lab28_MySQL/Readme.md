# Репликация MySQL

## Цель

Поработать с репликацией MySQL

### Задание

Развернуть БД на мастере и настроить так, чтобы реплицировались таблицы:

* bookmaker          
* competition        
* market             
* odds               
* outcome

Настроить GTID репликацию

### Решение


#### 1. Настройка MySQL - Master

* Сразу добавим правило в Firewalld для возможности подключения к базе данных через  стандартный для MySQL порт 3306:

```bash
[master@mysqlmaster dump]$ sudo firewall-cmd --zone=public --add-port=3306/tcp
success

[master@mysqlmaster dump]$ sudo firewall-cmd --permanent --zone=public --add-port=3306/tcpsuccess

```


* Выполним установку Percona server с соответствии с инструкциями с официального сервера:

https://docs.percona.com/percona-server/5.7/installation/yum_repo.html#installing-from-the-percona-yum-repository

```bash
yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
percona-release setup ps57
yum install Percona-Server-server-57
```

* Копируем файлы конфигурации в директорию /etc/my.cnf.d/.

```bash
[root@mysqlmaster /]# ll  /etc/my.cnf.d/
total 24
-rw-r--r--. 1 root root 207 Oct 23 14:48 01-base.cnf
-rw-r--r--. 1 root root  48 Oct 23 14:48 02-max-connections.cnf
-rw-r--r--. 1 root root 487 Oct 23 14:48 03-performance.cnf
-rw-r--r--. 1 root root  66 Oct 23 14:48 04-slow-query.cnf
-rw-r--r--. 1 root root 385 Oct 23 14:48 05-binlog.cnf
-rw-r--r--. 1 root root 168 Oct 23 14:02 charset.cnf
```

* Запускаем сервис mysql

```bash
[root@mysqlmaster master]# systemctl start mysql
[root@mysqlmaster master]# systemctl status mysql
● mysqld.service - MySQL Server
     Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; preset: disabled)
     Active: active (running) since Thu 2025-10-23 18:13:05 MSK; 6s ago
       Docs: man:mysqld(8)
             http://dev.mysql.com/doc/refman/en/using-systemd.html
```

* Узнаем временный пароль, который был сгенерирован Percona при установке
```bash
[root@mysqlmaster master]# cat /var/log/mysqld.log | grep 'root@localhost:'
2025-10-23T15:12:57.959797Z 1 [Note] A temporary password is generated for root@localhost: 3(!tobRNlYBY
```

* Устанавливаем постоянный пароль

```bash
[root@mysqlmaster master]# mysql -uroot -p'3(!tobRNlYBY'

mysql> ALTER USER USER() IDENTIFIED BY 'PerconaStrongPassword_1';
Query OK, 0 rows affected (0.00 sec)

```

* Проверяем ID сервера (важна его уникальность в рамках всей системы репликации) и то, что GUID (global transaction identifier) включен.

```bash
mysql> SELECT @@server_id;
+-------------+
| @@server_id |
+-------------+
|           1 |
+-------------+
1 row in set (0.00 sec)

mysql> SHOW VARIABLES LIKE 'gtid_mode';
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| gtid_mode     | ON    |
+---------------+-------+
1 row in set (1.69 sec)
```

* Берем предоставленный дамп (bet.dmp) и загружаем в нашу базу данных на мастере, предварительно создав ее:

```bash
[master@mysqlmaster dump]$ mysql -uroot -p'PerconaStrongPassword_1'

mysql> CREATE DATABASE bet;
mysql> USE bet;
Database changed
mysql> source /home/master/database/dump/bet.dmp
```

* Проверяем наличие таблиц в базе:

```bash
mysql> SHOW TABLES;
+------------------+
| Tables_in_bet    |
+------------------+
| bookmaker        |
| competition      |
| events_on_demand |
| market           |
| odds             |
| outcome          |
| v_same_event     |
+------------------+
7 rows in set (0.00 sec)
```

* Далее настраиваем пользователя для репликации и даем ему соответствующие права:

```bash
mysql> CREATE USER 'repl'@'%' IDENTIFIED BY '!OtusLinux2018';
Query OK, 0 rows affected (0.00 sec)

mysql> SELECT user,host FROM mysql.user where user='repl';
+------+------+
| user | host |
+------+------+
| repl | %    |
+------+------+
1 row in set (0.00 sec)

mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%' IDENTIFIED BY '!OtusLinux2018';
Query OK, 0 rows affected, 1 warning (0.00 sec)

```

* Делаем частичный(без некоторых оговоренных по заданию таблиц) dump базы данных (master.sql), который будет загружен в слейв для дальнейшей репликации. 

```bash
[master@mysqlmaster dump]$ mysqldump --all-databases --triggers --routines --master-data --ignore-table=bet.events_on_demand --ignore-table=bet.v_same_event -uroot -p > master.sql
Enter password:
Warning: A partial dump from a server that has GTIDs will by default include the GTIDs of all transactions, even those that changed suppressed parts of the database. If you don't want to restore GTIDs, pass --set-gtid-purged=OFF. To make a complete dump, pass --all-databases --triggers --routines --events.
[master@mysqlmaster dump]$ ll
total 1100
-rw-r--r--. 1 master master  117778 Oct 23 18:28 bet.dmp
-rw-r--r--. 1 master master 1006220 Oct 23 18:49 master.sql
```

На данном этапе настройка мастера завершена - cервер Percona установлен и настроен, создана база, снят с нее дамп, а также создан пользователь для репликации.


### 1. Настройка MySQL - Slave

* По аналогии устанавливаем Percona server на Slave хосте. Также настраиваем пароль. 

```bash
mysql> ALTER USER USER() IDENTIFIED BY 'PerconaStrongPassword_2'
```
* Копируем файлы конфигруации (скопируем в мастера)

```bash
[root@mysqlslave master]# scp master@192.168.20.226:/etc/my.cnf.d/* /etc/my.cnf.d/

[root@mysqlslave master]# ll /etc/my.cnf.d/
total 24
-rw-r--r--. 1 root root 207 Oct 23 19:07 01-base.cnf
-rw-r--r--. 1 root root  48 Oct 23 19:07 02-max-connections.cnf
-rw-r--r--. 1 root root 487 Oct 23 19:07 03-performance.cnf
-rw-r--r--. 1 root root  66 Oct 23 19:07 04-slow-query.cnf
-rw-r--r--. 1 root root 385 Oct 23 19:07 05-binlog.cnf
-rw-r--r--. 1 root root 168 Oct 23 19:07 charset.cnf
```

* Правим server-id для слейва

```bash
[root@mysqlslave master]# vi /etc/my.cnf.d/01-base.cnf

server-id = 2

```

* Проверяем:

```bash
[root@mysqlslave master]# mysql -uroot -p'PerconaStrongPassword_2'
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 3
Server version: 5.7.44-48-log Percona Server (GPL), Release 48, Revision 497f936a373

Copyright (c) 2009-2023 Percona LLC and/or its affiliates
Copyright (c) 2000, 2023, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> SELECT @@server_id;
+-------------+
| @@server_id |
+-------------+
|           2 |
+-------------+
1 row in set (0.00 sec)
```

* В файле 05-binlog.cnf указываем таблицы, которые будут игнорироваться при репликации:

```bash
[root@mysqlslave master]# vi /etc/my.cnf.d/05-binlog.cnf

replicate-ignore-table=bet.events_on_demand
replicate-ignore-table=bet.v_same_event
```

* Копируем себе сделанный дамп с мастера 

```bash
[root@mysqlslave dump]# scp master@192.168.20.226:/home/master/database/dump/master.sql /home/master/database/dump/

[root@mysqlslave dump]# ll
total 984
-rw-r--r--. 1 root root 1006220 Oct 23 19:21 master.sql

```

* Заливаем дамп в базу и проверяем наличие таблиц 

```bash

mysql> CREATE DATABASE bet;
Query OK, 1 row affected (0.00 sec)

mysql> USE bet;
Database changed
mysql> source /home/master/database/dump/master.sql


mysql> SHOW DATABASES LIKE 'bet';
+----------------+
| Database (bet) |
+----------------+
| bet            |
+----------------+
1 row in set (0.00 sec)

mysql> USE bet;
Database changed
mysql> SHOW TABLES;
+---------------+
| Tables_in_bet |
+---------------+
| bookmaker     |
| competition   |
| market        |
| odds          |
| outcome       |
+---------------+
5 rows in set (0.00 sec)
```

* На данном моменте все готово, чтобы запустить репликацию:

```bash
mysql> CHANGE MASTER TO MASTER_HOST = "192.168.20.226", MASTER_PORT = 3306, MASTER_USER = "repl", MASTER_PASSWORD = "!OtusLinux2018", MASTER_AUTO_POSITION = 1;
mysql> START SLAVE;
mysql> SHOW SLAVE STATUS\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.20.226
                  Master_User: repl
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000003
          Read_Master_Log_Pos: 786
               Relay_Log_File: mysqlslave-relay-bin.000020
                Relay_Log_Pos: 750
        Relay_Master_Log_File: mysql-bin.000003
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table: bet.events_on_demand,bet.v_same_event
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 0
                   Last_Error:
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 786
              Relay_Log_Space: 1262
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File:
           Master_SSL_CA_Path:
              Master_SSL_Cert:
            Master_SSL_Cipher:
               Master_SSL_Key:
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Master_Server_Id: 1
                  Master_UUID: c1ff3d48-b022-11f0-b81f-000c29230a35
             Master_Info_File: /var/lib/mysql/master.info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Master_SSL_Crl:
           Master_SSL_Crlpath:
           Retrieved_Gtid_Set: c1ff3d48-b022-11f0-b81f-000c29230a35:1-41
            Executed_Gtid_Set: 15a4dc68-b02b-11f0-abf4-000c290c959e:1-5,
c1ff3d48-b022-11f0-b81f-000c29230a35:1-41
                Auto_Position: 1
         Replicate_Rewrite_DB:
                 Channel_Name:
           Master_TLS_Version:
1 row in set (0.00 sec)
```

Видим, что репликация запустилась без ошибок и активна.

* Проверка работы репликации

Вставляем пару записей в таблицу bookmaker на мастере

```bash
mysql> INSERT INTO bookmaker (id,bookmaker_name) VALUES(1,'1xbet');
mysql> INSERT INTO bookmaker (id,bookmaker_name) VALUES(2,'2xbet');
```

Идем на слейв и проверяем, что данные также появлись в таблице.
```bash
mysql> SELECT * FROM bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  2 | 2xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
6 rows in set (0.00 sec)
```
Таким образом была настроена репликация данных с мастера на слейв. Проверена синхронизация данных.

