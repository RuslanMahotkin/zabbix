#!/bin/bash
# Отправка статистики сервера Apache на сервер Zabbix

# Получение строки статистики. Параметры curl:
#  --max-time		максимальное время операции в секундах;
#  --no-keepalive	отключение keepalive-сообщений в TCP-соединении;
#  --silent		отключение индикаторов загрузки и сообщений об ошибках;
RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent "http://`/bin/hostname`//as?auto")
# Статистика недоступна - возврат статуса сервиса - 'не работает'
[ $? != 0 ] && echo 0 && exit 1

# Фильтрация, форматирование и отправка данных статистики серверу Zabbix
(cat <<EOF
$RespStr
EOF
) | awk -F: '!/^Scoreboard/ {
  gsub(" ", "", $1)
  print "- apache." $1 $2
  } /^Scoreboard/ {
   par["WaitingForConnection"] = "_"
   par["StartingUp"] = "S"
   par["ReadingRequest"] = "R"
   par["SendingReply"] = "W"
   par["KeepAlive"] = "K"
   par["DNSLookup"] = "D"
   par["ClosingConnection"] = "C"
   par["Logging"] = "L"
   par["GracefullyFinishing"] = "G"
   par["IdleCleanupOfWorker"] = "I"
   par["OpenSlotWithNoCurrentProcess"] = "\\."
   for(p in par) print "- apache." p, gsub(par[p], "", $2)
}' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Возврат статуса сервиса - 'работает'
echo 1
exit 0
