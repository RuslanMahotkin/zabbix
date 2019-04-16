# zabbix
Набор сценариев и шаблонов для мониторинга различных сервисов.

Основные принципы написания сценариев:
- простота: небольшой объем кода;
- единообразие: одинаковые подходы к получению. обработке и отправке на сервер статистики;
- штатные средства: использование идущих в дистрибутиве и устанавливаемых по умолчанию утилит(в основном);
- данные типа траппер;
- данные получаются одним запросом к сервису;
- данные отправляются на сервер одним пакетом;
- сбор/отправка всех данных и обнаружение в одном сценарии.

Сценарии собирают не все доступные данные - фильтрация  осуществляется или в
самом сценарии, или из-за отсутствия их описания в шаблоне сервером Zabbix.

Версии сервисов:
- Apache 2.2.15;
- Asterisk 16.1;
- Elasticsearch 1.7.1;
- Mongodb 4.0.6;
- MySQL 8.0.13;
- Nginx 1.14.2;
- Oracle 10g;
- PHP-FPM 7.3.1;
- RabbitMQ 3.6.6(erlang 19.2);
- Redis 5.0.3;
- Sphinx 2.2.11.

Общее описание работы сценария:

1. Сценарий вызывается Zabbix-сервером для получения значения описанной в шаблоне переменной типа zabbix-агент Status.
2. Сценарий получает, фильтрует, обрабатывает и отправляет на сервер zabbix_sender-ом все данные за один раз.


# Linux (CentOS 6.X)

Сценарии:
- написаны на bash;
- получают данные curl-ом или штатным клиентом сервиса;
- фильтруют/обрабатывают данные с помощью awk;
- отправляют данные zabbix_sender-ом;
- размещаются в каталоге /etc/zabbix.

Порядок установки:

- Установка пакетов агента и утилиты отправки данных: zabbix, zabbix-agent,
 zabbix-sender.

- Запуск агента при старте системы и права на каталог/файл конфигурации:
```
 chmod 700 /etc/rc.d/init.d/zabbix-agent; chkconfig zabbix-agent on
 chmod 2750 /etc/zabbix; chgrp -R zabbix /etc/zabbix
 chmod 640 /etc/zabbix/zabbix_agentd.conf
```

- Разрешение портов в файерволе:
```
 # IP адрес сервера Zabbix
 $ZabbServIP='X.X.X.X'
 # Агент
 /sbin/iptables -A INPUT  -p tcp --dport 10050 -s $ZabbServIP -j ACCEPT
 /sbin/iptables -A OUTPUT -p tcp --sport 10050 -d $ZabbServIP -j ACCEPT
 # Сервер
 /sbin/iptables -A OUTPUT -p tcp --dport 10051 -d $ZabbServIP -j ACCEPT
 /sbin/iptables -A INPUT  -p tcp --sport 10051 -s $ZabbServIP -j ACCEPT
```

- Настройка агента в файле /etc/zabbix/zabbix_agentd.conf:
```
 SourceIP		= IP.адрес.zabbix.агента
 Server			= IP.адрес.zabbix.сервера
 ListenIP		= IP.адрес.zabbix.агента
 ServerActive		= IP.адрес.zabbix.сервера
 Timeout		= >5
```

- Установка требуемых сценариев.


Для обработки JSON данных в мониторинге Elasticsearch, MongoDB и RabbitMQ
используется исправленный JSON.sh (http://github.com/dominictarr/JSON.sh).


## Apache, шаблон mytemplate-apache-trap.xml

Предполагается, что Apache работает за nginx-ом.

Сценарий отправки статистики сервера Apache на сервер Zabbix
```
chmod 750 /etc/zabbix/apache_stat.sh
chgrp zabbix /etc/zabbix/apache_stat.sh
```

/etc/nginx/nginx.conf - добавить в сервер мониторинга (описан в разделе nginx)
```
  # Статистика apache
  location = /as {
   # Адрес проксируемоего сервера
   proxy_pass		http://127.0.0.1;
  }
```

В httpd.conf установить параметры:
- `ServerName` - возвращаемое hostname имя хоста;
- `Allow from` - IP адрес сервера.


/etc/https/conf/httpd.conf - создание сервера мониторинга
```
# Модуль статуса
LoadModule		status_module modules/mod_status.so
...
# Сохранение расширенной информации о каждом запросе
ExtendedStatus		On
...
# Мониторинг ----------------------------------------------
<VirtualHost 127.0.0.1:80>
 # Имя сервера
 ServerName		DNS.имя.сервера.
 # Отключение журнализации
 CustomLog		/dev/null combined

 <Location /as>
  SetHandler		server-status
  Order			allow,deny
  Allow			from	IP.адрес.сер.вера
 </Location>
</VirtualHost>
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= apache_status,/etc/zabbix/apache_stat.sh
```

Перезапуск сервисов
```
service nginx reload; service httpd restart; service zabbix-agent restart
```

## Asterisk, шаблон mytemplate-asterisk-trap.xml

Установить утилиту Netcat - пакет nc(в CentOS 7 - nmap-ncat).

В файле настройки модуля AMI и сценарии в подстроке
```
... Username: Пользователь_мониторинга\r\nSecret: Пароль_мониторинга\r\n ...
```
установить свои значения 'Пользователь_мониторинга' и 'Пароль_мониторинга'.


/etc/asterisk/manager.conf - настроить модуль AMI и задать пользователя
```
[general]
enabled = yes
bindaddr = 127.0.0.1
allowmultiplelogin = no
displayconnects = no
authtimeout = 5
authlimit = 3

[Пользователь_мониторинга]
secret = Пароль_мониторинга
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.255
write = command,reporting
```

Перезапустить модуль AMI
```
asterisk -r
 manager reload
```

Сценарий отправки статистики сервера Asterisk на сервер Zabbix
```
chmod 750 /etc/zabbix/asterisk_stat.sh
chgrp zabbix /etc/zabbix/asterisk_stat.sh
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= asterisk_status,/etc/zabbix/asterisk_stat.sh
```

Перезапуск агента
```
service zabbix-agent restart
```


## Elasticsearch, шаблон mytemplate-elasticsearch-trap.xml

Сценарий отправки статистики сервера Elasticsearch на сервер Zabbix
```
chmod 750 /etc/zabbix/{elasticsearch_stat.sh,JSON.sh}
chgrp zabbix /etc/zabbix/{elasticsearch_stat.sh,JSON.sh}
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= elasticsearch_status,/etc/zabbix/elasticsearch_stat.sh
```

Перезапуск агента
```
service zabbix-agent restart
```

## IO - дисковый ввод/вывод, шаблон mytemplate-io-trap.xml

Так как сценарий выполняет вызов `iostat` с 5 секундным замером, то параметр
`Timeout` в `zabbix_agentd.conf` должен быть больше 5.

Установить пакет `sysstat` (версии не ниже 9.0.4-27). Удалить сбор статистики по `cron`
```
rm -f /etc/cron.d/sysstat
```

Сценарий отправки статистики дискового ввода-вывода на сервер Zabbix
```
chmod 750 /etc/zabbix/io_stat.sh
chgrp zabbix /etc/zabbix/io_stat.sh
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= iostat_status,/etc/zabbix/io_stat.sh
UserParameter		= iostat.discovery_disks,/etc/zabbix/io_stat.sh disks
```

Перезапуск агента
```
service zabbix-agent restart
```

## MongoDB, шаблон mytemplate-mongodb-trap.xml

Сценарий отправки статистики сервера MongoDB на сервер Zabbix
```
chmod 750 /etc/zabbix/{JSON.sh,mongodb_stat.sh}
chgrp zabbix /etc/zabbix/{JSON.sh,mongodb_stat.sh}
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= mongodb_status,/etc/zabbix/mongodb_stat.sh
UserParameter		= mongodb.discovery_db,/etc/zabbix/mongodb_stat.sh db
```

Перезапуск агента
```
service zabbix-agent restart
```

## MySQL, шаблон mytemplate-mysql-trap.xml

В сценарии в подстроке
```
... --user=Пользователь_мониторинга --password=Пароль_мониторинга ...
```
установить свои значения 'Пользователь_мониторинга' и 'Пароль_мониторинга'.


Сценарий отправки статистики сервера MySQL на сервер Zabbix
```
chmod 750 /etc/zabbix/mysql_stat.sh
chgrp zabbix /etc/zabbix/mysql_stat.sh
```

Mysql-пользователь мониторинга
```
mysql -p
mysql> GRANT USAGE ON *.* TO 'Пользователь_мониторинга'@'localhost' IDENTIFIED BY 'Пароль_мониторинга';
mysql> FLUSH PRIVILEGES;
mysql> \q
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= mysql_status,/etc/zabbix/mysql_stat.sh
```

Перезапуск агента
```
service zabbix-agent restart
```

## MySQL репликация, шаблон mytemplate-mysql-slave-trap.xml

Сценарий отправки статистики репликации сервера MySQL на сервер Zabbix
```
chmod 750 /etc/zabbix/mysql_slave_stat.sh
chgrp zabbix /etc/zabbix/mysql_slave_stat.sh
```

Привилегия клиента репликации Mysql-пользователю мониторинга
```
mysql -p
mysql> GRANT REPLICATION CLIENT ON *.* TO 'Пользователь_мониторинга'@'localhost';
mysql> FLUSH PRIVILEGES;
mysql> \q
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= mysql_slave_status,/etc/zabbix/mysql_slave_stat.sh
```

Перезапуск агента
```
service zabbix-agent restart
```

## Nginx, шаблон mytemplate-nginx-trap.xml

Сценарий отправки статистики сервера Nginx на сервер Zabbix
```
chmod 750 /etc/zabbix/nginx_stat.sh
chgrp zabbix /etc/zabbix/nginx_stat.sh
```

В `httpd.conf` установить параметры:
- `server_name` - возвращаемое hostname имя хоста;
- `listen` и `allow` - IP адрес сервера.


/etc/nginx/nginx.conf - создание сервера мониторинга
```
 # Сервер мониторинга -------------------------------------
 server {
  # Прослушиваемые адрес:порт(*:80|*:8000)
  listen		ip.адрес.сер.вера:80;
  # Имя и псевдонимы виртуального сервера(_)
  server_name		DNS.имя.сервера;

  # Отключение журнализации
  access_log		off;
  # Таймаут закрытия keep-alive соединения со стороны сервера в секундах(75)
  keepalive_timeout	0;

  ### Доступ к серверу
  # Локальный
  allow			ip.адрес.сер.вера;
  # Запрет доступа остальным
  deny			all;

  # Статистика nginx
  location = /ns {
   # Включение обработчика статуса
   stub_status		on;
  }
 }
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= nginx_status,/etc/zabbix/nginx_stat.sh
```

Перезапуск сервисов
```
service nginx reload; service zabbix-agent restart
```

## Oracle, шаблон mytemplate-oracle-trap.xml

Сценарий отправки статистики сервера Oracle на сервер Zabbix
```
chmod 750 /etc/zabbix/{oracle_stat.sh,oraenv}
chgrp zabbix /etc/zabbix/{oracle_stat.sh,oraenv}
```

Добавление пользователя, под которым запущен агент zabbix, в группу для доступа к SQL Plus
```
usermod --append --groups oinstall zabbix
```

/etc/zabbix/oraenv - задать переменные окружения Oracle
```
export ORACLE_HOME=
export PATH=$PATH:$ORACLE_HOME/bin
export NLS_LANG=
export TZ=
```

В сценарии в строке
```
conn Пользователь_мониторинга/Пароль_мониторинга
```
установить свои значения 'Пользователь_мониторинга' и 'Пароль_мониторинга'.


Создание Oracle-пользователя и присвоение ему прав для всех БД.
БД задается установкой переменной ORACLE_SID в ее SID перед запуском sqlplus
```
su - oracle
 export ORACLE_SID=
 sqlplus /nolog
  CONNECT / AS sysdba
  CREATE USER Пользователь_мониторинга IDENTIFIED BY Пароль_мониторинга;
  GRANT CONNECT                   TO Пользователь_мониторинга;
  GRANT SELECT ON v_$instance     TO Пользователь_мониторинга;
  GRANT SELECT ON v_$sysstat      TO Пользователь_мониторинга;
  GRANT SELECT ON v_$session      TO Пользователь_мониторинга;
  GRANT SELECT ON dba_free_space  TO Пользователь_мониторинга;
  GRANT SELECT ON dba_data_files  TO Пользователь_мониторинга;
  GRANT SELECT ON dba_tablespaces TO Пользователь_мониторинга;
  GRANT SELECT ON dba_temp_files  TO Пользователь_мониторинга;
  GRANT SELECT ON v_$log          TO Пользователь_мониторинга;
  GRANT SELECT ON v_$archived_log TO Пользователь_мониторинга;
  GRANT SELECT ON v_$loghist      TO Пользователь_мониторинга;
  GRANT SELECT ON v_$system_event TO Пользователь_мониторинга;
  GRANT SELECT ON v_$event_name   TO Пользователь_мониторинга;
  GRANT SELECT ON v_$sort_segment TO Пользователь_мониторинга;
  GRANT SELECT ON v_$resource_limit TO Пользователь_мониторинга;
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= oracle_status[*],/etc/zabbix/oracle_stat.sh $1
UserParameter		= oracle.discovery_databases,/etc/zabbix/oracle_stat.sh
UserParameter		= oracle.discovery_tablespaces,/etc/zabbix/oracle_stat.sh tablespaces
```

Перезапуск агента
```
service zabbix-agent restart
```

## Php-fpm, шаблон mytemplate-php-fpm-trap.xml

Сценарий отправки статистики сервера Php-fpm на сервер Zabbix
```
chmod 750 /etc/zabbix/php-fpm_stat.sh
chgrp zabbix /etc/zabbix/php-fpm_stat.sh
```

/etc/nginx/nginx.conf - добавить в сервер мониторинга (описан в разделе nginx)
```
  # Статистика php-fpm
  location = /ps {
   # Адрес:порт или файл UNIX-сокета FastCGI-сервера
   fastcgi_pass		unix:/var/run/www-fpm.sock;
   # Включение файла общих параметров FastCGI
   include		fastcgi_params;
   # Передаваемые FastCGI-серверу параметры
   fastcgi_param	SCRIPT_FILENAME ps;
  }
```

/etc/php-fpm.d/www.conf - в конфигурации пула
```
;### Ссылка на страницу состояния FPM; не установлено - страница статуса не
; отображается()
pm.status_path			= /ps
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= php-fpm_status,/etc/zabbix/php-fpm_stat.sh
```

Перезапуск сервисов
```
service nginx reload; service php-fpm reload; service zabbix-agent restart
```

## Postfix, шаблон mytemplate-postfix-trap.xml

Установить пакет `postfix-perl-scripts`.
Используется сокращенный `logtail.pl` из пакета `logcheck`.

Сценарий отправки статистики сервера Postfix на сервер Zabbix
```
chmod 750 /etc/zabbix/{logtail.pl,postfix_stat.sh}
chgrp zabbix /etc/zabbix/{logtail.pl,postfix_stat.sh}
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= postfix_status,/etc/zabbix/postfix_stat.sh
```

/etc/sudoers - запуск logtail под root пользователю zabbix
```
### Агент Zabbix
Defaults:zabbix	!requiretty
zabbix		ALL=(ALL)	NOPASSWD: /etc/zabbix/logtail.pl -l /var/log/maillog -o /tmp/postfix_stat.dat
```

Перезапуск агента
```
service zabbix-agent restart
```

## RabbitMQ, шаблон mytemplate-rabbitmq-trap.xml

Сценарий отправки статистики сервера RabbitMQ на сервер Zabbix
```
chmod 750 /etc/zabbix/{JSON.sh,rabbitmq_stat.sh}
chgrp zabbix /etc/zabbix/{JSON.sh,rabbitmq_stat.sh}
```

В сценарии в подстроке
```
... --user Пользователь_мониторинга:Пароль_мониторинга ...
```
установить свои значения 'Пользователь_мониторинга' и 'Пароль_мониторинга'.

Примечание: в сценарии доступ к статистике по протоколу https, который настроен
в /etc/rabbitmq/rabbitmq.config в разделе rabbit
```
  %% Настройки SSL
  {ssl_options, [
   %% Полное имя файла сертификата центра сертификации в формате PEM
   {cacertfile,			"/etc/pki/tls/certs/Файл_сертификата_CA.pem"},
   %% Полное имя файла сертификата в формате PEM
   {certfile,			"/etc/pki/tls/certs/Файл_сертификата.pem"},
   %% Полное имя файла закрытого ключа в формате PEM
   {keyfile,			"/etc/pki/tls/private/Файл_ключа.pem"},
   %% Используемые версии SSL
   {versions,			['tlsv1.2']},
   %% Используемые наборы шифров
   {ciphers,			[{ecdhe_rsa,aes_128_gcm,null,sha256}]},
   %% Проверка сертификата клиента
   {verify,			verify_peer},
   %% Запрет клиента без сертификата
   {fail_if_no_peer_cert,	false}
  ]},
```
Для  http-доступа к статистике исправить протокол и убрать параметры
'ciphers', 'insecure' и 'tlsv1.2' в строке
```
 RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent --ciphers ecdhe_rsa_aes_128_gcm_sha_256 --insecure --tlsv1.2 --user Пользователь_мониторинга:Пароль_мониторинга "https://127.0.0.1:15672/api/$1" | /etc/zabbix/JSON.sh -l 2>/dev/null)
```

/etc/rabbitmq/enabled_plugins - добавить плагин управления rabbitmq_management
```
[...,rabbitmq_management].
```

RabbitMQ-пользователь мониторинга
```
rabbitmqctl add_user Пользователь_мониторинга Пароль_мониторинга
rabbitmqctl set_user_tags Пользователь_мониторинга monitoring
rabbitmqctl set_permissions Пользователь_мониторинга '' '' ''
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= rabbitmq_status,/etc/zabbix/rabbitmq_stat.sh
UserParameter		= rabbitmq.discovery_queues,/etc/zabbix/rabbitmq_stat.sh queues
```

Перезапуск агента
```
service zabbix-agent restart
```

## Redis, шаблон mytemplate-redis-trap.xml

Сценарий отправки статистики сервера Redis на сервер Zabbix
```
chmod 750 /etc/zabbix/redis_stat.sh
chgrp zabbix /etc/zabbix/redis_stat.sh
```

В сценарии в подстроке
```
... -s /полное/имя/файла/сокета ...
```
установить '/полное/имя/файла/сокета'.

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= redis_status,/etc/zabbix/redis_stat.sh
UserParameter		= redis.discovery_db,/etc/zabbix/redis_stat.sh db
```

Перезапуск агента
```
service zabbix-agent restart
```

## Sphinx, шаблон mytemplate-sphinx-trap.xml

/etc/sphinx/sphinx.conf - локальное MySQL-соединение в разделе searchd
```
 listen			= 127.0.0.1:9306:mysql41
```

Сценарий отправки статистики сервера Sphinx на сервер Zabbix
```
chmod 750 /etc/zabbix/sphinx_stat.sh
chgrp zabbix /etc/zabbix/sphinx_stat.sh
```

/etc/zabbix/zabbix_agentd.conf - подключение сценария к zabbix-агенту
```
UserParameter		= sphinx_status,/etc/zabbix/sphinx_stat.sh
UserParameter		= sphinx.discovery_indexes,/etc/zabbix/sphinx_stat.sh indexes
```

Перезапуск сервисов
```
service searchd restart; service zabbix-agent restart
```

# Linux (CentOS 7.X)

Сценарии и их установка аналогична CentOS 6.X с небольшими изменениями:

- Включение, перезапуск и перегрузка сервисов выполняется посредством systemd.
Например, перезапуск агента
```
systemctl restart zabbix-agent.service

```

- Отличается сценарий "дисковый ввод/вывод" - io_stat.sh - расположен в
 подкаталоге Scripts/CentOS7

# Windows (Server 2012R2)

Сценарии:
- написаны на Powershell;
- получают данные методами PowerShell или штатным клиентом сервиса;
- фильтруют/обрабатывают данные методами PowerShell;
- отправляют данные zabbix_sender-ом;
- размещаются в каталоге c:\Scripts.


Установка:

- Скопировать zabbix_agentd.exe, zabbix_sender.exe, zabbix_agentd_win.conf в
   C:\Scripts;

- Настройка агента в файле C:\Scripts\zabbix_agentd_win.conf:
```
 SourceIP		= IP.адрес.zabbix.агента
 Server			= IP.адрес.zabbix.сервера
 ListenIP		= IP.адрес.zabbix.агента
 ServerActive		= IP.адрес.zabbix.сервера
 Hostname		= DNS.имя.сервера
 Timeout		= 10
```

- Разрешение портов в Брандмауэре Windows:
```
 Правила для входящих подключений - Создать правило...
  Тип правила					Для порта
  Протокол и порты
   Протокол TCP
   Определенные локальные порты			10050
  Действие
   Разрешить подключение
  Профиль
   Доменный
   Частный
  Имя:
   Имя						Zabbix агент
 Zabbix агент - Свойства - Область - Удаленный IP-адрес
  Указанные IP-адреса - IP.адрес.zabbix.сервера
```

- Установка сервиса. Командная строка - Запустить от имени администратора:
```
  C:\Scripts\zabbix_agentd.exe --config C:\Scripts\zabbix_agentd_win.conf --install
```

- Разрешение выполнения неподписанных сценариев.
 Запустить powershell.exe от имени администратора:
```
 PS > Set-ExecutionPolicy remotesigned
```

- Установка требуемых сценариев.


## PostgreSQL, шаблон mytemplate-windows-postgresql-trap.xml

PostgreSQL (от 1С) установлен в каталог `E:\PostgreSQL\9.4.2-1.1C`.

Пользователь мониторинга
```
E:\PostgreSQL\9.4.2-1.1C\bin\psql --username=postgres template1
template1=# CREATE USER zabbix;
template1=# \q
```

Доступ без пароля пользователю мониторинга первая строка в
E:\PostgreSQL\9.4.2-1.1C\data\pg_hba.conf
```
host	template1	zabbix		127.0.0.1/32		trust
```

Перезапуск PostgreSQL
`Службы - PostgreSQL Database Server - Перезапуск службы`


В сценарии мониторинга C:\Scripts\postgresql_stat.ps1:
- сохранить полное имя исполняемого файла клиента PostgreSQL в переменной `$PsqlExec`;
- в строке запуска `zabbix_sender` параметр `host` установить в DNS-имя сервера.


C:\Scripts\zabbix_agentd_win.conf - подключение сценария к zabbix-агенту
```
UserParameter=postgresql_status,powershell -File "c:\Scripts\postgresql_stat.ps1"
UserParameter=postgresql.discovery_databases,powershell -File "c:\Scripts\postgresql_stat.ps1" db
```

Перезапуск агента
`Службы - Zabbix Agent - Перезапуск службы`


## RabbitMQ, шаблон mytemplate-rabbitmq-trap.xml

Предполагается Erlang otp_win64_19.0.exe.

В файле enabled_plugins - добавить плагин управления rabbitmq_management
```
[...,rabbitmq_management].
```

Пользователь мониторинга
```
SET ERLANG_HOME=C:\Program Files\erl8.0
cd "C:\Program Files\RabbitMQ Server\rabbitmq_server-3.6.5\sbin"
rabbitmqctl add_user Пользователь_мониторинга Пароль_мониторинга
rabbitmqctl set_user_tags Пользователь_мониторинга monitoring
rabbitmqctl set_permissions Пользователь_мониторинга '' '' ''
```

Перезапуск RabbitMQ
`Службы - RabbitMQ - Перезапуск службы`


В сценарии мониторинга RabbitMQ c:\Scripts\rabbitmq_stat.ps1:
- в строке
```
   $wc.Credentials = New-Object System.Net.NetworkCredential('Пользователь_мониторинга', 'Пароль_мониторинга')
```
  установить свои значения 'Пользователь_мониторинга' и 'Пароль_мониторинга'.
- в строке запуска `zabbix_sender` параметр `host` установить в DNS-имя сервера.


Примечание: в сценарии доступ к статистике по протоколу https, который настроен
в rabbitmq.config в разделе rabbit
```
  %% Настройки SSL
  {ssl_options, [
   %% Полное имя файла сертификата центра сертификации в формате PEM
   {cacertfile,			"Файл_сертификата_CA.pem"},
   %% Полное имя файла сертификата в формате PEM
   {certfile,			"Файл_сертификата.pem"},
   %% Полное имя файла закрытого ключа в формате PEM
   {keyfile,			"Файл_ключа.pem"},
   %% Используемые версии SSL
   {versions,			['tlsv1.1']},
   %% Проверка сертификата клиента
   {verify,			verify_peer},
   %% Запрет клиента без сертификата
   {fail_if_no_peer_cert,	false}

  ]},
```
Для  http-доступа к статистике исправить протокол в строке
```
 $uri = New-Object System.Uri("https://127.0.0.1:15672/api/$Query");
```
и удалить строки
```
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11

```

C:\Scripts\zabbix_agentd_win.conf - подключение сценария к zabbix-агенту
```
UserParameter=rabbitmq_status,powershell -File "c:\Scripts\rabbitmq_stat.ps1"
UserParameter=rabbitmq.discovery_queues,powershell -File "c:\Scripts\rabbitmq_stat.ps1" queues
```

Перезапуск агента
`Службы - Zabbix Agent - Перезапуск службы`
