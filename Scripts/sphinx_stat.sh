#!/bin/bash
# Отправка статистики сервера Sphinx на сервер Zabbix

SphinxAPI(){
# Запрос к API Sphinx

 # Параметры mysql:
 #  --host		имя/адрес соединения;
 #  --port		порт соединения;
 #  --skip-column-names	отсутствие имен столбцов в выводе;
 #  --execute		выполнение команды и выход, выключает --force и историю
 RespStr=$(/usr/bin/mysql --host=127.0.0.1 --port=9306 --skip-column-names --execute="SHOW $1;" 2>/dev/null)
 # Статистика недоступна - возврат статуса сервиса - 'не работает'
 [ $? != 0 ] && echo 0 && exit 1
}


# Список индексов
SphinxAPI 'TABLES'
IndexStr=$((cat <<EOF
$RespStr
EOF
) | awk -F\\t '$2~/^local$/ { print $1}')

# В командной строке нет параметров - отправка данных
if [ -z $1 ]; then
 # Статистика сервера
 SphinxAPI 'STATUS'
 # Форматирование данных статистики
 OutStr=$((cat <<EOF
$RespStr
EOF
 ) | awk -F\\t '{ print "- sphinx." $1, $2 }')

 # Разделитель полей во вводимой строке - для построчной обработки
 IFS=$'\n'
 # Обработка списка индексов
 for ind in $IndexStr; do
  # Статистика индекса
  SphinxAPI "INDEX $ind STATUS"
  # Форматирование данных статистики индекса в строке вывода
  for par in $RespStr; do
    OutStr="$OutStr
- sphinx.${par%%	*}[$ind] ${par#*	}"
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

# Обнаружение индексов
elif [ "$1" = 'indexes' ]; then
 # Разделитель JSON-списка имен
 es=''
 # Обработка списка индексов
 for ind in $IndexStr; do
  # JSON-форматирование имени индекса в строке вывода
  OutStr="$OutStr$es{\"{#INDEXNAME}\":\"${ind#*	}\"}"
  es=","
 done
 # Вывод списка очередей в формате JSON
 echo -e "{\"data\":[$OutStr]}"
fi
