#!/bin/bash
# Отправка статистики сервера MongoDB на сервер Zabbix

MongoAPI(){
# Запрос к API MongoDB

 # Параметры mongo:
 #  --quiet	'тихий' вывод оболочки;
 #  --eval	вычисляемое JavaScript выражение
 RespStr=$(/usr/bin/mongo --quiet --eval "print(JSON.stringify($1))" $2 | /etc/zabbix/JSON.sh -l 2>/dev/null)
 # Статистика недоступна - возврат статуса сервиса - 'не работает'
 [ $? != 0 ] && echo 0 && exit 1
}


# Список БД
MongoAPI 'db.getMongo().getDBs()'
DBStr=$((cat <<EOF
$RespStr
EOF
) | awk -F\\t '$1~/^databases..+.name$/ && $2!~/^local$/ {
 print $2
}')


# В командной строке нет параметров - отправка данных
if [ -z $1 ]; then
 # Статистика сервера
 MongoAPI 'db.serverStatus({cursors: 0, locks:0, wiredTiger: 0})'
 # Фильтрация, форматирование данных статистики
 OutStr=$((cat <<EOF
$RespStr
EOF
) | awk -F\\t '$1~/^(metrics.(cursor.(open.total|timedOut)|document.(deleted|inserted|returned|updated))|connections.(current|available)|globalLock.(currentQueue.(readers|total|writers)|activeClients.(total|readers|writers)|totalTime)|extra_info.(heap_usage_bytes|page_faults)|mem.(resident|virtual|mapped)|uptime|network.(bytes(In|Out)|numRequests)|opcounters.(command|delete|getmore|insert|query|update))(.floatApprox|.\$numberLong)?$/ {
  sub(".floatApprox", "", $1)
  sub(".\\$numberLong", "", $1)
  print "- mongodb." $1, int($2)
 }')

 # Разделитель полей во вводимой строке - для построчной обработки
 IFS=$'\n'
 # Обработка списка БД
 for db in $DBStr; do
  # Статистика БД
  MongoAPI 'db.stats()' $db
  # Форматирование данных статистики БД в строке вывода
  for par in $RespStr; do
    OutStr="$OutStr
- mongodb.${par%%	*}[$db] ${par#*	}"
  done
 done

 # Отправка строки вывода серверу Zabbix. Параметры zabbix_sender:
 #  --config		файл конфигурации агента;
 #  --host		имя узла сети на сервере Zabbix;
 #  --input-file	файл данных('-' - стандартный ввод)
 (cat <<EOF
$OutStr
EOF
 ) | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
 # Возврат статуса сервиса - 'работает'
 echo 1
 exit 0

# Обнаружение БД
elif [ "$1" = 'db' ]; then
 # Разделитель JSON-списка имен
 es=''
 # Обработка списка БД
 for db in $DBStr; do
  # JSON-форматирование имени БД в строке вывода
  OutStr="$OutStr$es{\"{#DBNAME}\":\"${db#*	}\"}"
  es=","
 done
 # Вывод списка БД в формате JSON
 echo -e "{\"data\":[$OutStr]}"
fi
