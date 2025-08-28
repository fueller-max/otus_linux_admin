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

* Создаем Vagrantfile запускаем две машины.

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
    { :name => "backup",
      :ip => "192.168.56.160",
    },
    { :name => "client",
      :ip => "192.168.56.150",
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

* После развертывания проверяем, что машины доступны для Ansible

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

#### 2. Написание playbook для Ansible для установки Borg backup и инициализации репозитория

Пишем playbook для Ansible, который будет делать следующее:

  * установка borgbackup на backup машине
  * настройка пользователя на backup машине
  * создание директории для репозитория на backup машине
  * установка borgbackup на client машине
  * настрока ssh доступа от client до backup
  * инициализация репозитория на backup машине со стороны client машины

````bash
---
- name: Manage backup machine 1st step
  hosts: backup
  become: true
  tasks:
    - name: Update package list
      apt:
        update_cache: yes

    - name: Install borgbackup
      apt:
        name: borgbackup
        state: present

    - name: Ensure borg group exists
      group:
        name: borg
        state: present

    - name: Ensure borg user  exist
      user:
        name: borg
        group: borg
        createhome: no

    - name: Create /var/backup directory
      file:
        path: /var/backup
        state: directory
        owner: borg
        group: borg
        mode: '0755'
    
    - name: Create .ssh directory for borg user
      file:
        path: /home/borg/.ssh
        state: directory
        owner: borg
        group: borg
        mode: '0700'

    - name: Create .ssh/authorized_keys file for borg user
      file:
        path: /home/borg/.ssh/authorized_keys
        state: touch
        owner: borg
        group: borg
        mode: '0600'

- name: Manage client machine 1st step
  hosts: client
  become: true
  
  tasks:
      - name: Update package list
        apt:
          update_cache: yes

      - name: Install borgbackup
        apt:
          name: borgbackup
          state: present

      - name: Generate SSH key
        shell: |
         ssh-keygen -t ed25519 -f /home/vagrant/.ssh/id_ed25519 -N ''
      
      - name: Change ownership of /home/vagrant/.ssh
        file:
          path: /home/vagrant/.ssh
          owner: vagrant
          group: vagrant
          recurse: yes

- name: Copy SSH public key from client to backup
  hosts: backup
  become: true
  vars:
    borg_user: borg
    client_public_key_path: "/home/vagrant/.ssh/id_ed25519.pub"

  tasks:
    - name: Fetch the public key from the client
      fetch:
        src: "{{ client_public_key_path }}"
        dest: "/tmp/client_id_ed25519.pub"
        flat: yes
      delegate_to: client

    - name: Add SSH public key to authorized_keys on backup
      authorized_key:
        user: "{{ borg_user }}"
        key: "{{ lookup('file', '/tmp/client_id_ed25519.pub') }}"
        state: present

- name: Manage client machine
  hosts: client
  become: true
  vars:
    borg_passphrase: "Otus1234"

  tasks:
    - name: Initialize Borg repository
      shell: |
        echo "{{ borg_passphrase }}" | borg init --encryption=repokey --passphrase-fd 0 borg@192.168.56.160:/var/backup/

````

#### 3. Настройка процесса бекапа

После того, как репозиторий инициализрован, создаем скрипт, который будет выполнять процесс бекапа

````bash
#!/bin/bash

# Path to the directory you want to back up
SOURCE_DIR="/tmp/data"

# Borg repository URL
REPO_URL="borg@192.168.56.160:/var/backup/"

# Backup name using date
BACKUP_NAME="backup-$(date +"%Y-%m-%d_%H:%M:%S")"

# Passphrase
export BORG_PASSPHRASE="Otus1234"

# Perform the backup
borg create --stats  "$REPO_URL::$BACKUP_NAME" "$SOURCE_DIR"

# Check consistency of repo
borg check "$REPO_URL"

# Clean up old backups
borg prune  --list   --keep-daily 90   "$REPO_URL"

# Clean up the space
borg compact "$REPO_URL"
````

Далее создаем сервис и таймер для переродического вызова скрипта

````bash
[Unit]
Description=Borg Backup
After=network.target

[Service]
User=vagrant
Environment=HOME=/home/vagrant
ExecStart=/usr/local/bin/borg-backup.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target

````

````bash
[Unit] 
Description=Borg Backup 
 
[Timer] 
OnUnitActiveSec=5min 
 
[Install] 
WantedBy=timers.target
````


````bash
vagrant@client://usr/local/bin$ sudo nano  borg-backup.sh

````

````bash
sudo chmod +x /usr/local/bin/borg-backup.sh
````

* Cмотрим работу

````bash
vagrant@client:/$ sudo systemctl status borg-backup.service
○ borg-backup.service - Borg Backup
     Loaded: loaded (/etc/systemd/system/borg-backup.service; disabled; vendor preset: enabled)
     Active: inactive (dead) since Thu 2025-08-28 16:46:15 UTC; 43s ago
TriggeredBy: ● borg-backup.timer
    Process: 3961 ExecStart=/usr/local/bin/borg-backup.sh (code=exited, status=0/SUCCESS)
   Main PID: 3961 (code=exited, status=0/SUCCESS)
        CPU: 2.690s

Aug 28 16:46:10 client borg-backup.sh[3963]: This archive:                  568 B                544 B                544 B
Aug 28 16:46:10 client borg-backup.sh[3963]: All archives:                2.69 MB              1.04 MB              1.09 MB
Aug 28 16:46:10 client borg-backup.sh[3963]:                        Unique chunks         Total chunks
Aug 28 16:46:10 client borg-backup.sh[3963]: Chunk index:                     745                  782
Aug 28 16:46:10 client borg-backup.sh[3963]: ------------------------------------------------------------------------------
Aug 28 16:46:13 client borg-backup.sh[3967]: Keeping archive (rule: daily #1):        backup-2025-08-28_16:46:08           Thu, 2025-08-28 16:46:10 [b>
Aug 28 16:46:13 client borg-backup.sh[3967]: Pruning archive (1/1):                   backup-2025-08-28_16:25:04           Thu, 2025-08-28 16:25:06 [4>
Aug 28 16:46:13 client borg-backup.sh[3967]: Keeping archive (rule: daily[oldest] #2): backup-20250828101726                Thu, 2025-08-28 10:17:36 [>
Aug 28 16:46:15 client systemd[1]: borg-backup.service: Deactivated successfully.
Aug 28 16:46:15 client systemd[1]: borg-backup.service: Consumed 2.690s CPU time.

````

#### 4.Восстановление из бекапа


````bash

lines 1-18/18 (END)
vagrant@client:/$ borg list borg@192.168.56.160:/var/backup/
Enter passphrase for key ssh://borg@192.168.56.160/var/backup:
backup-20250828101726                Thu, 2025-08-28 10:17:36 [935e5d9e3ecc96793632ad56b4f7fcfb7f627b915e4b4bb63c09b83714e5bd32]
backup-2025-08-28_16:46:08           Thu, 2025-08-28 16:46:10 [bb71a38b68a453c2d5cda7dfd0b1aa746a6bae1b0a4db6fff6f7b77d7113fa9e]
````

````bash
vagrant@client:/$ borg list borg@192.168.56.160:/var/backup/
Enter passphrase for key ssh://borg@192.168.56.160/var/backup:
backup-20250828101726                Thu, 2025-08-28 10:17:36 [935e5d9e3ecc96793632ad56b4f7fcfb7f627b915e4b4bb63c09b83714e5bd32]
backup-2025-08-28_16:51:32           Thu, 2025-08-28 16:51:34 [726d4f16c35edc061fb31a26e4c66e4d312bc2862ebd8b97c2f13d7334ae2029]

vagrant@client:/$ borg list borg@192.168.56.160:/var/backup/::backup-2025-08-28_16:51:32 tmp/data
Enter passphrase for key ssh://borg@192.168.56.160/var/backup:
drwxrwxr-x vagrant vagrant        0 Thu, 2025-08-28 16:41:03 tmp/data
-rw-rw-r-- vagrant vagrant        0 Thu, 2025-08-28 16:40:59 tmp/data/file1
-rw-rw-r-- vagrant vagrant        0 Thu, 2025-08-28 16:41:02 tmp/data/file2
-rw-rw-r-- vagrant vagrant        0 Thu, 2025-08-28 16:41:03 tmp/data/file3
````