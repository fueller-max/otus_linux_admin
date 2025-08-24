# Резервное копирование

## Цель

Научиться настраивать резервное копирование с помощью утилиты Borg

### Задание

1. Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client.
2. Настроить удаленный бэкап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:
* директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB; 
* репозиторий для резервных копий должен быть зашифрован ключом или паролем - на усмотрение студента;
* имя бэкапа должно содержать информацию о времени снятия бекапа;
* глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех. Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов;
* резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации;
* написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на усмотрение студента;
* настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов.


### Решение

#### 1. Настройка стенда Vagrant с двумя виртуальными машинами: backup_server и client.

Тестовый стенд:
 - backup 192.168.11.160 Ubuntu 22.04 
 - client 192.168.11.150 Ubuntu 22.04


````bash
ansible@ansible:~/BACKUPS$ vagrant ssh-config
Host backup
  HostName 127.0.0.1
  User vagrant
  Port 2222
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /home/ansible/BACKUPS/.vagrant/machines/backup/virtualbox/private_key
  IdentitiesOnly yes
  LogLevel FATAL
  PubkeyAcceptedKeyTypes +ssh-rsa
  HostKeyAlgorithms +ssh-rsa

Host client
  HostName 127.0.0.1
  User vagrant
  Port 2200
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /home/ansible/BACKUPS/.vagrant/machines/client/virtualbox/private_key
  IdentitiesOnly yes
  LogLevel FATAL
  PubkeyAcceptedKeyTypes +ssh-rsa
  HostKeyAlgorithms +ssh-rsa

````


````bash
ansible@ansible:~/BACKUPS/ansible$ ssh -i /home/ansible/BACKUPS/.vagrant/machines/client/virtualbox/private_key -p 2200 vagrant@127.0.0.1
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-144-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Aug 23 06:43:06 PM UTC 2025

  System load:  0.0                Processes:             132
  Usage of /:   15.9% of 30.34GB   Users logged in:       0
  Memory usage: 22%                IPv4 address for eth0: 10.0.2.15
  Swap usage:   0%


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Sat Aug 23 18:38:52 2025 from 10.0.2.2
````


````bash
ansible@ansible:~/BACKUPS/ansible$ ansible backup -m ping
backup | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "ping": "pong"
}

````

````bash

ansible@ansible:~/BACKUPS/ansible$ ansible client -m ping
client | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "ping": "pong"
}
````



````bash
sudo chown -R vagrant:vagrant /home/vagrant/.ssh
````

````bash
````

````bash
````

````bash
````

