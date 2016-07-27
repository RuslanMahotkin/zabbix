#!/bin/bash
# Отправка статистики дискового ввода-вывода на сервер Zabbix


# В командной строке нет параметров - отправка данных
if [ -z $1 ]; then
 # Получение строки статистики. Параметры iostat:
 #  -d	статистика использования устройств;
 #  -k	статистика в килобайтах в секунду;
 #  -x	расширенная статистика;
 #  -y	пропуск первой статистики(с момента загрузки);
 #  5	время в секундах между отчетами;
 #  1	количество отчетов
 RespStr=$(/usr/bin/iostat -dkxy 5 1 2>/dev/null)
 # Статистика недоступна - возврат статуса сервиса - 'не работает'
 [ $? != 0 ] && echo 0 && exit 1

 # Фильтрация, форматирование и отправка данных статистики серверу Zabbix
 (cat <<EOF
$RespStr
EOF
 ) | awk 'BEGIN {split("disk rrqm_s wrqm_s r_s w_s rkB_s wkB_s avgrq-sz avgqu-sz await r_await w_await svctm util", aParNames)}
  $1 ~ /^[hsv]d[a-z]$/ {
  gsub(",", ".", $0);
  if(NF == 14)
   for(i = 2; i <= 14; i++) print "- iostat."aParNames[i]"["$1"]", $i
 }' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
 # Возврат статуса сервиса - 'работает'
 echo 1
 exit 0

# Обнаружение дисков
elif [ "$1" = 'disks' ]; then
 # Строка списка дисков
 DiskStr=`/usr/bin/iostat -d | awk '$1 ~ /^[hsv]d[a-z]$/ {print $1}'`
 # Разделитель JSON-списка имен
 es=''
 # Обработка списка дисков
 for disk in $DiskStr; do
  # JSON-форматирование имени диска в строке вывода
  OutStr="$OutStr$es{\"{#DISKNAME}\":\"$disk\"}"
  es=","
 done
 # Вывод списка дисков в формате JSON
 echo -e "{\"data\":[$OutStr]}"
fi
