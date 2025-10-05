# LDAP на базе FreeIPA

## Цель

Научиться настраивать LDAP-сервер и подключать к нему LDAP-клиентов

### Задание

1. Установить FreeIPA
2. Написать Ansible-playbook для конфигурации клиента

### Решение

#### 1. Установка FreeIPA

Для установки FreeIP используем гайд с freeipa.org:

<https://www.freeipa.org/page/Quick_Start_Guide>

* Устанвливаем hostname на машине сервера server.ipa.test

```bash
[master@localhost ~]$ hostnamectl set-hostname server.ipa.test
```

* Добавляем DNS записи в файл /etc/hosts
  
```bash
127.0.1.1 server.ipa.test server
192.168.153.164 server.ipa.test server
```

Шаги по настройке DNS крайне важны для корректной работы системы FreeIPA. т.к. Kerberos и SSL службы не будут работать без рабочей DNS конфигурации.

* Добавляем сервис FreeIPA в правила firewalld:
  
```bash
[master@server ~]$ firewall-cmd --add-service=freeipa-4 
[master@server ~]$ firewall-cmd --add-service=freeipa-4  --permanent
```

* Переводим SELinux в отключенное состояние(также вносим изменение в параметры ядра для постоянного отключения SELinux )
  
 ```bash
[master@server ~]$ sudo setenforce 0
 ```

* Запускаем установку FreeIPA сервера

````bash
[master@server ~]$ dnf install freeipa-server
````

* После установки запускаем скрипт конфигурирования FreeIPA сервера

````bash
[master@server ~]$ sudo ipa-server-install
````

* После установки/конфнига должно быть сообщение об успешной инсталяции Free IPA сервера
  
````bash
the ipa-server-install command was successful
````

* Делаем инициализацию пользователя admin c использованием пароля IPA admin password, заданного при конфигурировании сервера

```bash
[root@localhost master]# kinit admin
Password for admin@IPA.TEST:
```

На этом базовая установка и настройка сервера закончена и сервер доступен по доменному имени и можно авторизоваться под пользователем admin.

![basic_FreeIPA](/Lab26_LDAP/pic/ipa_1.jpg)
![login_FreeIPA](/Lab26_LDAP/pic/ipa_2.jpg)

#### 2. Конфигурация клиента

* Создадим пользователя otus-user на сервере в графическом режиме.
![NewClient_FreeIPA](/Lab26_LDAP/pic/serv_new_client.jpg)

* Для настройки клиента воспользуемся следующим ansible-плейбуком:

```bash
- name: Setup of IPA clients 
  hosts: client1.ipa.test
  become: yes 
  tasks:
  
  - name: disable firewalld 
    service: 
     name: firewalld 
     state: stopped 
     enabled: false  

  - name: disable SElinux 
    selinux: 
     state: disabled 

  - name: disable SElinux now
    shell: setenforce 0

  - name: Set up timezone 
    timezone: 
     name: "Europe/Moscow" 

  - name: enable chrony 
    service:
     name: chronyd 
     state: restarted 
     enabled: true      

  - name: change /etc/hosts 
    copy:
     src: hosts 
     dest: /etc/hosts 
     owner: root 
     group: root 
     mode: 0644

  - name: install module ipa-client 
    yum: 
     name: 
       - freeipa-client 
     state: present 
     update_cache: true

  - name: add host to ipa-server
    shell: echo -e "yes\nyes" | ipa-client-install --mkhomedir --domain=IPA.TEST --server=server.ipa.test --no-ntp -p admin -w OrmENagE   
```

Данный плейбук по последовательности действий достаточно близок к установке и настройке сервера, описанной выше.

Важной является последний таск (add host to ipa-server) -  добавление нового клиента на сервер после установки freeipa-client  на клиенте.

Здесь мы указываем доменное имя сервера, некоторые параметры.

* После настройки free ipa клиента на машине можно инциализировать ранее созданного пользователя на сервере otus-user:

````bash
[root@client1 master]# kinit otus-user
Password for otus-user@IPA.TEST: 
Password expired.  You must change it now.
Enter new password: 
Enter it again: 
[root@client1 master]# su otus-user
sh-5.1$ 
sh-5.1$ whoami
otus-user
````

Видим, что система создала в системе нового пользователя otus-user с параметрами, подтянутыми из IPA сервера. Таким образом, связка IPA сервер и IPA клиент работает корректно и позволяет выполнять централизованный менеджмент пользователей.
