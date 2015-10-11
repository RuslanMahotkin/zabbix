#!/bin/bash
# Отправка статистики сервера Nginx на сервер Zabbix

# Получение строки статистики. Параметры curl:
#  --max-time		максимальное время операции в секундах;
#  --no-keepalive	отключение keepalive-сообщений в TCP-соединении;
#  --silent		отключение индикаторов загрузки и сообщений об ошибках;
RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent "http://`/bin/hostname`/ns")
# Статистика недоступна - возврат статуса сервиса - 'не работает'
[ $? != 0 ] && echo 0 && exit 1

# Фильтрация, форматирование и отправка данных статистики серверу Zabbix
(cat <<EOF
$RespStr
EOF
) | awk '/^Active connections/ {active = int($NF)}
 /^ *[0-9]+ *[0-9]+ *[0-9]+/ {accepts = int($1); handled = int($2); requests = int($3)}
 /^Reading:/ {reading = int($2); writing = int($4); waiting = int($NF)}
 END {
  print "- nginx.active", active;
  print "- nginx.accepts", accepts;
  print "- nginx.handled", handled;
  print "- nginx.requests", requests;
  print "- nginx.reading", reading;
  print "- nginx.writing", writing;
  print "- nginx.waiting", waiting;
}' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Возврат статуса сервиса - 'работает'
echo 1
exit 0
