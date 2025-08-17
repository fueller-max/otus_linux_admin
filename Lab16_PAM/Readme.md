# PAM

## Цель

Научиться создавать пользователей и добавлять им ограничения

### Задание

Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников

### Решение

#### 1. Развертывание виртуальной машины с использованием Vagrant


* Для развертывания виртуальной машины используем предложенный Vagrantfile с небольшими изменениями:

````bash
MACHINES = {
  :"pam" => {
              :box_name => "ubuntu/jammy64",
              :cpus => 1,
              :memory => 512,
              :ip => "192.168.57.10",
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.network "private_network", ip: boxconfig[:ip]
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.box_version = boxconfig[:box_version]
      box.vm.host_name = boxname.to_s

      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
      box.vm.provision "shell", inline: <<-SHELL
          sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
          systemctl restart sshd.service
  	  SHELL
    end
  end
end

````

* Далее запускаем создание ВМ:

````bash
ansible@ansible:~/pam$ vagrant up
==> vagrant: A new version of Vagrant is available: 2.4.8 (installed version: 2.4.1)!
==> vagrant: To upgrade visit: https://www.vagrantup.com/downloads.html

Bringing machine 'pam' up with 'virtualbox' provider...
==> pam: Box 'ubuntu/jammy64' could not be found. Attempting to find and install...
    pam: Box Provider: virtualbox
    pam: Box Version: >= 0
==> pam: Loading metadata for box 'ubuntu/jammy64'
    pam: URL: https://vagrantcloud.com/api/v2/vagrant/ubuntu/jammy64
==> pam: Adding box 'ubuntu/jammy64' (v20241002.0.0) for provider: virtualbox
    pam: Downloading: https://vagrantcloud.com/ubuntu/boxes/jammy64/versions/20241002.0.0/providers/virtualbox/unknown/vagrant.box
==> pam: Successfully added box 'ubuntu/jammy64' (v20241002.0.0) for 'virtualbox'!
==> pam: Importing base box 'ubuntu/jammy64'...
==> pam: Matching MAC address for NAT networking...
==> pam: Checking if box 'ubuntu/jammy64' version '20241002.0.0' is up to date...
==> pam: Setting the name of the VM: pam_pam_1755440896848_56737
==> pam: Clearing any previously set network interfaces...
==> pam: Preparing network interfaces based on configuration...
    pam: Adapter 1: nat
    pam: Adapter 2: hostonly
==> pam: Forwarding ports...
    pam: 22 (guest) => 2222 (host) (adapter 1)
==> pam: Running 'pre-boot' VM customizations...
==> pam: Booting VM...
==> pam: Waiting for machine to boot. This may take a few minutes...
    pam: SSH address: 127.0.0.1:2222
    pam: SSH username: vagrant
    pam: SSH auth method: private key
    pam: Warning: Connection reset. Retrying...
    pam: Warning: Remote connection disconnect. Retrying...
    pam: Warning: Connection reset. Retrying...
    pam: Warning: Remote connection disconnect. Retrying...
    pam:
    pam: Vagrant insecure key detected. Vagrant will automatically replace
    pam: this with a newly generated keypair for better security.
    pam:
    pam: Inserting generated public key within guest...
    pam: Removing insecure key from the guest if it's present...
    pam: Key inserted! Disconnecting and reconnecting using new SSH key...
==> pam: Machine booted and ready!
==> pam: Checking for guest additions in VM...
    pam: The guest additions on this VM do not match the installed version of
    pam: VirtualBox! In most cases this is fine, but in rare cases it can
    pam: prevent things such as shared folders from working properly. If you see
    pam: shared folder errors, please make sure the guest additions within the
    pam: virtual machine match the version of VirtualBox you have installed on
    pam: your host and reload your VM.
    pam:
    pam: Guest Additions Version: 6.0.0 r127566
    pam: VirtualBox Version: 7.0
==> pam: Setting hostname...
==> pam: Configuring and enabling network interfaces...
==> pam: Running provisioner: shell...
    pam: Running: inline script
````

* Проверяем статус ВМ:

````bash
ansible@ansible:~/pam$ vagrant status
Current machine states:

pam                       running (virtualbox)

The VM is running. To stop this VM, you can run `vagrant halt` to
shut it down forcefully, or you can run `vagrant suspend` to simply
suspend the virtual machine. In either case, to restart it again,
simply run `vagrant up`.
````
Видим, что на данном этапе все прошло успешно -виртуальная машина создана и готова к работе.

#### 2. Создание пользователей в системе и группы пользователей

* Заходим на созданную ВМ по SSH. 
````bash
ansible@ansible:~/pam$ vagrant ssh
````

* После авторизации создаем два новых пользователя: "otus" и "otusadm".  

```bash
vagrant@pam:~$ sudo -i
root@pam:~# sudo useradd otusadm && sudo useradd otus
```
* Устанавливаем пароли для созданных пользователей. Для Ubuntu используем команду chpasswd

````bash
root@pam:~# echo "otusadm:Otus2022!" | sudo chpasswd && echo "otus:Otus2022!" | sudo chpasswd
````
* Создадим новую группу "admin".

````bash
root@pam:~# sudo groupadd -f admin
````

* Поместим в созданную группу "admin" троих пользователей: "otusadm" и уже два ранее существовавших "root" и "vagrant". Стоит отметить, что помещение пользователей в группу "admin" никак не делает их автоматически администраторам (если они не были им). 
````bash
root@pam:~# usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
````

Secondary Groups: The -aG option adds a user to one or more secondary groups.

* Проверяем, что можем войти в SSH под каждым из вновь созданных пользователей с использованием пароля:

````bash
ansible@ansible:~/pam$ ssh otus@192.168.57.10
otus@192.168.57.10's password:
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-144-generic x86_64)

$
````

````bash
ansible@ansible:~/pam$ ssh otusadm@192.168.57.10
otusadm@192.168.57.10's password:
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-144-generic x86_64)

$
````

На данном этапе созданы два новых пользователя, пользователи с администраторскими правами помещены в отдельную дополнительную группу с целью дальнейшей настройки прав доступа к систему по времени

#### 3.  Настройка запрета для всех пользователей (кроме группы admin) логина в выходные дни (праздники не учитываются)

Проверим, какие пользователи входят в созданную группу "admin"

````bash
vagrant@pam:~$ cat /etc/group | grep admin
admin:x:118:otusadm,root,vagrant
````
Видим, что в группу входит 3 пользователя: otusadm,root,vagrant

Для настройки контроля доступа по времени будем использовать PAM модуль pam_exec. Использование PAM модуля pam_time было бы логичнее да и проще, т.к. этот модуль специально "заточен" под использование для временных задач, однако не поддерживает группы пользователей, что ведет к необходимости написания строк для каждого пользователя в отдельности.

Для реализации контроля доступа используем предложенный скрипт, задача которого определить какой сейчас день недели, далее определить входит ли пользователь в группу "admin". Если входит, то скрипт завершиться нулевым кодом возврата и аутентифакция будет возможна, если нет (т.е. суббота или вскр, но пользователь не входит в группу "admin"), то скрипт вернет ненулевой код, что означает ошибку и аутентифакция будет невозможна.

````bash
#!/bin/bash
#Первое условие: если день недели суббота или воскресенье
if [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun" ]; then
 #Второе условие: входит ли пользователь в группу admin
 if getent group admin | grep -qw "$PAM_USER"; then
        #Если пользователь входит в группу admin, то он может подключиться
        exit 0
      else
        #Иначе ошибка (не сможет подключиться)
        exit 1
    fi
  #Если день не выходной, то подключиться может любой пользователь
  else
    exit 0
fi
````

Делаем скрипт исполняемым:

````bash
root@pam:~# chmod +x /usr/local/bin/login.sh
````

Далее в файле etc/pam.d/sshd (модуль PAM, ответственный за SSH) добавляем ссылку на наш скрипт:

````bash
root@pam:~# nano /etc/pam.d/sshd

# PAM configuration for the Secure Shell service

#Custom authentication

auth required pam_exec.so debug /usr/local/bin/login.sh
````

Проверяем работу. Поскольку сегодня воскресенье, то все должно работать как ожидается.

Пользователь "otus":

````bash
ansible@ansible:~$ ssh otus@192.168.57.10
otus@192.168.57.10's password:
Permission denied, please try again.
````

Видим, что аутентфикация не проходит, при этом в логах ВМ можно видеть следующие записи:

````bash
Aug 17 15:52:03 pam sshd[3238]: pam_exec(sshd:auth): /usr/local/bin/login.sh failed: exit code 1
Aug 17 15:52:05 pam sshd[3238]: Failed password for otus from 192.168.57.1 port 43450 ssh2
Aug 17 15:52:05 pam sshd[3238]: Connection closed by authenticating user otus 192.168.57.1 port 43450 [preauth]
````
указывающие, что скрипт был вызван и вернул 1 и аутентфикация не сработала.


Пользователь "otusadm":

````bash
ansible@ansible:~$ ssh otusadm@192.168.57.10
otusadm@192.168.57.10's password:
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-144-generic x86_64)
````
Аутентфикация прошла успешно, а в логах видно, что скрипт также был вызван, вернул 0.

````bash
Aug 17 15:52:39 pam sshd[3261]: pam_exec(sshd:auth): Calling /usr/local/bin/login.sh ...
Aug 17 15:52:39 pam sshd[3259]: Accepted password for otusadm from 192.168.57.1 port 39064 ssh2
Aug 17 15:52:39 pam sshd[3259]: pam_unix(sshd:session): session opened for user otusadm(uid=1002) by (uid=0)
````





