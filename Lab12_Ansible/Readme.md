# Первые шаги с Ansible

## Первые шаги с Ansible

Работать с SELinux: диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется

### Задание

На сервере используя Ansible необходимо развернуть nginx со следующими условиями:

* необходимо использовать модуль yum/apt;
* конфигурационные файлы должны быть взяты из шаблона jinja2 с перемененными;
* после установки nginx должен быть в режиме enabled в systemd;
* должен быть использован notify для старта nginx после установки;
* сайт должен слушать на нестандартном порту - 8080, для этого использовать переменные в Ansible.

Сделать все это с использованием Ansible роли.

### Решение 

* Развертывание управляемого хоста

Для управления хоста с использованием Ansible будем использовать локальный хост Linux в домашней сети(192.168.40.11).

К нему обеспечен доступ по SSH из виртуальной машины с развернутым Ansible.


Создадим inventory файл ./staging/hosts с описанием параметров хоста для управления:

````bash
[home_serv]
nginx ansible_host=192.168.40.11 ansible_port=22 ansible_user=master
ansible_private_key_file=/home/ansible/.ssh/id_rsa
````

Проверим, что Ansible имеет доступ к управляемому хосту:


```` bash
ansible@ansible:~/Ansible/anisble_project/inventory$ ansible nginx -i staging/hosts -m ping
nginx | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.12"
    },
    "changed": false,
    "ping": "pong"
}
````

Видим, что Ansible имеет доступ к хосту.

В текущем каталоге создадим файл ansible.cfg со следующим 
содержанием для того, чтобы каждый раз явно у указывать inventroy файл: 


````bash
[defaults]
inventory = inventory/staging/hosts
remote_user = master
host_key_checking = False
retry_files_enabled = False
````
 
Пробуем проверить доступ к хосту используя только его имя:

````bash
ansible@ansible:~/Ansible/anisble_project$ ansible nginx -m ping
nginx | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.12"
    },
    "changed": false,
    "ping": "pong"
}
````

Видим, что все работает без указания инвентаря.

Попробуем выполнить команду на хосте, например, запросив версию ядра:

````bash
ansible@ansible:~/Ansible/anisble_project$ ansible nginx -m command -a "uname -r"
nginx | CHANGED | rc=0 >>
6.8.0-62-generic
````
Видим, что команда успешно выполнилась, вернув версию ядра на хосте.

Можкм запросить статус файрвола на хосте:

````bash
ansible@ansible:~/Ansible/anisble_project$ ansible nginx -m systemd -a name=firewalld
nginx | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.12"
    },
    "changed": false,
    "name": "firewalld",
    "status": {
        "ActiveEnterTimestampMonotonic": "0",
        "ActiveExitTimestampMonotonic": "0",
        "ActiveState": "inactive",
        "AllowIsolate": "no",
        "AssertResult": "no",
        "AssertTimestampMonotonic": "0",
        "Before": "docker.service",
        "BlockIOAccounting": "no",
        "BlockIOWeight": "[not set]",
        "CPUAccounting": "yes",
        "CPUAffinityFromNUMA": "no",
        "CPUQuotaPerSecUSec": "infinity",
        "CPUQuotaPeriodUSec": "infinity",
        "CPUSchedulingPolicy": "0",
        "CPUSchedulingPriority": "0",
        #########################################
        "WatchdogTimestampMonotonic": "0",
        "WatchdogUSec": "infinity"
    }
}
````

Далее приступим к написанию playbook для установки nginx на хосте.

Первый playbook будет состоять из двух задач (tasks)
 * обновить пакеты
 * установить NGINX с использованием apt

```bash
---
- name: NGINX | Install and configure NGINX
  hosts: nginx
  become: true
  tasks:
    - name: update
      apt:
        update_cache=yes
    - name: NGINX | Install NGINX
      apt:
        name: nginx
        state: latest
```

После написания пробуем запустить playbook:

```bash
ansible@ansible:~/Ansible/anisble_project$ ansible-playbook playbooks/nginx.yaml --ask-become-pass
BECOME password:

PLAY [NGINX | Install and configure NGINX] **********************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************
ok: [nginx]

TASK [update] ***************************************************************************************************************************
changed: [nginx]

TASK [NGINX | Install NGINX] ************************************************************************************************************
changed: [nginx]

PLAY RECAP ******************************************************************************************************************************
nginx                      : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Видим, что playbook отработал успешно, последовательно выполнив описаные таски.

Далее расширим созданный playbook, добавив туда задачу копирования конфигруации на базе шаблона j2. 
Также вводится переменная nginx_listen_port, в которой указывается требуемый порт, который будет задан в конфигурации и на котором будет работать Nginx после запуска.

Также в playbook добавлены два handler, который запускаются из тасков для перезапуска NGINX и конфигруации.

Финальный playbook выглядит следующим образом:

```bash
---
- name: NGINX | Install and configure NGINX
  hosts: nginx
  become: true
  vars:
    nginx_listen_port: 8080

  tasks:
    - name: update
      apt:
        update_cache=yes

    - name: NGINX | Install NGINX
      apt:
        name: nginx
        state: latest
      notify:
        - restart nginx
      tags:
        - nginx-package

    - name: NGINX | Create NGINX config file from template
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify:
        - reload nginx
      tags:
        - nginx-configuration

  handlers:
    - name: restart nginx
      systemd:
        name: nginx
        state: restarted
        enabled: yes

    - name: reload nginx
      systemd:
        name: nginx
        state: reloaded
```

Шаблон j2:

```bash

# {{ ansible_managed }}
events {
    worker_connections 1024;
}

http {
    server {
        listen       {{ nginx_listen_port }} default_server;
        server_name  default_server;
        root         /usr/share/nginx/html;

        location / {
        }
    }
}
```

Запускаем playbook:

```bash
ansible@ansible:~/Ansible/anisble_project$ ansible-playbook playbooks/nginx.yaml --ask-become-pass
BECOME password:

PLAY [NGINX | Install and configure NGINX] **********************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************
ok: [nginx]

TASK [update] ***************************************************************************************************************************
changed: [nginx]

TASK [NGINX | Install NGINX] ************************************************************************************************************
ok: [nginx]

TASK [NGINX | Create NGINX config file from template] ***********************************************************************************
changed: [nginx]

RUNNING HANDLER [reload nginx] **********************************************************************************************************
changed: [nginx]

PLAY RECAP ******************************************************************************************************************************
nginx                      : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

```

Видим, что playbook отработал успешно и сервис работает на порту 8080, как и требовалось:

![NGINX](/Lab12_Ansible/pics/NGINX_8080.jpg)


Структура папок проекта Ansible:

````bash
ansible@ansible:~/Ansible/anisble_project$ ll
total 24
drwxrwxr-x 5 ansible ansible 4096 Jul 29 14:03 ./
drwxrwxr-x 4 ansible ansible 4096 Jul 19 18:36 ../
-rw-rw-r-- 1 ansible ansible  126 Jul 28 16:31 ansible.cfg
drwxrwxr-x 2 ansible ansible 4096 Jul 16 17:48 hosts/
drwxrwxr-x 3 ansible ansible 4096 Jul 16 17:49 inventory/
drwxrwxr-x 3 ansible ansible 4096 Jul 29 14:35 playbooks/

ansible@ansible:~/Ansible/anisble_project/playbooks$ ll
total 16
drwxrwxr-x 3 ansible ansible 4096 Jul 29 14:35 ./
drwxrwxr-x 5 ansible ansible 4096 Jul 29 14:03 ../
-rw-rw-r-- 1 ansible ansible  774 Jul 29 14:20 nginx.yaml
drwxrwxr-x 2 ansible ansible 4096 Jul 29 14:37 templates/

ansible@ansible:~/Ansible/anisble_project/playbooks/templates$ ll
total 12
drwxrwxr-x 2 ansible ansible 4096 Jul 29 14:37 ./
drwxrwxr-x 3 ansible ansible 4096 Jul 29 14:35 ../
-rw-rw-r-- 1 ansible ansible  267 Jul 29 14:02 nginx.conf.j2

````










