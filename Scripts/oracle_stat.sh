#!/bin/bash
# Отправка статистики сервера Oracle на сервер Zabbix. Параметры:
#  1 - SID БД или 'tablespaces' для обнаружения табличных пространств

ExecSql(){
# Выполнение sql-запроса. Параметры: 1 - строка запроса

 ResStr=$(sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
set verify off echo off feedback off heading off pagesize 0 trimout on trimspool on termout off
conn Пользователь_мониторинга/Пароль_мониторинга
column retvalue format a15
$1
EOF
)
 # Ошибка
 [ $? != 0 ] && exit 1
}


# Настройка Oracle-окружения
. /etc/zabbix/oraenv

# В командной строке нет параметров - обнаружение БД
if [ -z $1 ]; then
 # Получение строки списка имен БД
 DBStr=$(awk -F: '$1~/^[A-Za-z]+$/ { print $1 }' /etc/oratab 2>/dev/null)
 # Ошибка
 [ $? != 0 ] && exit 1
 # Разделитель JSON-списка
 es=''
 # Обработка списка
 for db in $DBStr; do
  # JSON-форматирование имени в строке вывода
  OutStr="$OutStr$es{\"{#DBNAME}\":\"$db\"}"
  es=","
 done
 # Вывод списка в формате JSON
 echo "{\"data\":[$OutStr]}"

# Обнаружение табличных пространств
elif [ "$1" = 'tablespaces' ]; then
 # Получение строки списка имен БД
 DBStr=$(awk -F: '$1~/^[A-Za-z]+$/ { print $1 }' /etc/oratab 2>/dev/null)
 # Ошибка
 [ $? != 0 ] && exit 1
 # Разделитель JSON-списка
 es=''
 # Обработка списка
 for db in $DBStr; do
  # SID БД
  export ORACLE_SID=$db
  # Получение списка имен табличных пространств
  ExecSql 'SELECT tablespace_name FROM dba_tablespaces;'
  # Обработка списка
  for ts in $ResStr; do
   # JSON-форматирование имени в строке вывода
   OutStr="$OutStr$es{\"{#DBNAME}\":\"$db\",\"{#TSNAME}\":\"$ts\"}"
   es=","
  done
 done
 # Вывод списка в формате JSON
 echo "{\"data\":[$OutStr]}"

# Статистика БД
else
 # SID БД
 db=$1
 export ORACLE_SID=$1

 # Форматы вывода чисел
 fmint='FM99999999999999990'
 fmfloat='FM99999990.9999'
 # SQL-подстроки получения значения статистики
 ValueSysStatStr=" to_char(value, '$fmint') FROM v\$sysstat WHERE name = "
 TimeWaitedSystemEventStr=" to_char(time_waited, '$fmint') FROM v\$system_event se, v\$event_name en WHERE se.event(+) = en.name AND en.name = "
 ValueResourceLimitStr=" '$fmint') FROM v\$resource_limit WHERE resource_name = "
 # Массив SQL-запросов значений элементов данных
 aParSql=(
"'checkactive', to_char(case when inst_cnt > 0 then 1 else 0 end,'$fmint')
  FROM  (select count(*) inst_cnt FROM v\$instance
  WHERE status = 'OPEN' AND logins = 'ALLOWED' AND database_status = 'ACTIVE')"

"'rcachehit', to_char((1 - (phy.value - lob.value - dir.value) / ses.value)* 100, '$fmfloat')
  FROM  v\$sysstat ses, v\$sysstat lob, v\$sysstat dir, v\$sysstat phy
  WHERE ses.name = 'session logical reads'
        AND dir.name = 'physical reads direct'
        AND lob.name = 'physical reads direct (lob)'
        AND phy.name = 'physical reads'"

"'dsksortratio', to_char(d.value/(d.value + m.value)*100, '$fmfloat')
  FROM  v\$sysstat m, v\$sysstat d
  WHERE m.name = 'sorts (memory)' AND d.name = 'sorts (disk)'"

"'activeusercount', to_char(count(*)-1, '$fmint')
  FROM  v\$session
  WHERE username is not null AND status='ACTIVE'"

"'usercount', to_char(count(*)-1, '$fmint')
  FROM  v\$session
  WHERE username is not null"

"'dbsize', to_char(sum(NVL(a.bytes - NVL(f.bytes, 0), 0)), '$fmint')
  FROM  sys.dba_tablespaces d,
        (select tablespace_name, sum(bytes) bytes from dba_data_files group by tablespace_name) a,
        (select tablespace_name, sum(bytes) bytes from dba_free_space group by tablespace_name) f
  WHERE d.tablespace_name = a.tablespace_name(+)
        AND d.tablespace_name = f.tablespace_name(+)
        AND NOT (d.extent_management like 'LOCAL' AND d.contents like 'TEMPORARY')"

"'dbfilesize', to_char(sum(bytes), '$fmint')
  FROM  dba_data_files"

"'uptime', to_char((sysdate-startup_time)*86400, '$fmint')
  FROM  v\$instance"

"'hparsratio', to_char(h.value/t.value*100,'$fmfloat')
  FROM  v\$sysstat h, v\$sysstat t
  WHERE h.name = 'parse count (hard)' AND t.name = 'parse count (total)'"

"'lastarclog', to_char(max(SEQUENCE#), '$fmint')
  FROM  v\$log
  WHERE archived = 'YES'"

"'lastapplarclog', to_char(max(lh.SEQUENCE#), '$fmint')
  FROM  v\$loghist lh, v\$archived_log al
  WHERE lh.SEQUENCE# = al.SEQUENCE# AND applied='YES'"

"'processescurrent', to_char(current_utilization,$ValueResourceLimitStr'processes'"
"'sessionscurrent', to_char(current_utilization,$ValueResourceLimitStr'sessions'"
"'processeslimit', to_char(limit_value,$ValueResourceLimitStr'processes'"
"'sessionslimit', to_char(limit_value,$ValueResourceLimitStr'sessions'"

"'commits',$ValueSysStatStr'user commits'"
"'rollbacks',$ValueSysStatStr'user rollbacks'"
"'deadlocks',$ValueSysStatStr'enqueue deadlocks'"
"'redowrites',$ValueSysStatStr'redo writes'"
"'tblscans',$ValueSysStatStr'table scans (long tables)'"
"'tblrowsscans',$ValueSysStatStr'table scan rows gotten'"
"'indexffs',$ValueSysStatStr'index fast full scans (full)'"
"'netsent',$ValueSysStatStr'bytes sent via SQL*Net to client'"
"'netresv',$ValueSysStatStr'bytes received via SQL*Net from client'"
"'netroundtrips',$ValueSysStatStr'SQL*Net roundtrips to/from client'"
"'logonscurrent',$ValueSysStatStr'logons current'"

"'freebufwaits',$TimeWaitedSystemEventStr'free buffer waits'"
"'bufbusywaits',$TimeWaitedSystemEventStr'buffer busy waits'"
"'logswcompletion',$TimeWaitedSystemEventStr'log file switch completion'"
"'logfilesync',$TimeWaitedSystemEventStr'log file sync'"
"'logprllwrite',$TimeWaitedSystemEventStr'log file parallel write'"
"'enqueue',$TimeWaitedSystemEventStr'enqueue'"
"'dbseqread',$TimeWaitedSystemEventStr'db file sequential read'"
"'dbscattread',$TimeWaitedSystemEventStr'db file scattered read'"
"'dbsnglwrite',$TimeWaitedSystemEventStr'db file single write'"
"'dbprllwrite',$TimeWaitedSystemEventStr'db file parallel write'"
"'directread',$TimeWaitedSystemEventStr'direct path read'"
"'directwrite',$TimeWaitedSystemEventStr'direct path write'"
"'latchfree',$TimeWaitedSystemEventStr'latch free'"
 )

 # Формирование строки запросов значений элементов данных из массива
 SqlStr=''
 for p in "${aParSql[@]}"; do
  SqlStr="${SqlStr}SELECT ${p};
"
 done

 # Получение и добавление в строку вывода значений элементов данных
 OutStr=''
 ExecSql "$SqlStr"
 # Разделитель полей во вводимой строке - для построчной обработки
 IFS=$'\n'
 for par in $ResStr; do
  # Проверка наличия значения
  [ $par == ${par#* } ] || OutStr="$OutStr- oracle.${par%% *}[$db] ${par#* }\n"
 done

 # Получение данных по табличным пространствам
 ExecSql "SELECT df.tablespace_name || ' ' || totalspace || ' ' || nvl(freespace, 0)
  FROM
  (SELECT tablespace_name, SUM(bytes) totalspace
    FROM dba_data_files
    GROUP BY tablespace_name) df,
  (SELECT tablespace_name, SUM(Bytes) freespace
    FROM dba_free_space
    GROUP BY tablespace_name) fs
  WHERE df.tablespace_name = fs.tablespace_name (+);
  SELECT tf.tablespace_name || ' ' || totalspace || ' ' || (totalspace - used)
  FROM
  (SELECT tablespace_name, SUM(bytes) totalspace
    FROM dba_temp_files
    GROUP BY tablespace_name) tf,
  (SELECT tablespace_name, used_blocks*8192 used
    FROM v\$sort_segment) ss
  WHERE tf.tablespace_name = ss.tablespace_name;"

 # Добавление данных по табличным пространствам в строку вывода
 for par in $ResStr; do
  # Имя табличного пространства
  ts=${par%% *}
  # Выделение значений полного и свободного размеров табличного пространства
  par=${par#* }
  OutStr="$OutStr- oracle.tablespace.size[$db,$ts] ${par%% *}\n"
  OutStr="$OutStr- oracle.tablespace.free[$db,$ts] ${par#* }\n"
 done

 # Отправка строки вывода серверу Zabbix. Параметры zabbix_sender:
 #  --config		файл конфигурации агента;
 #  --host		имя узла сети на сервере Zabbix;
 #  --input-file	файл данных('-' - стандартный ввод)
 echo -en $OutStr | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
 # Возврат статуса сервиса - 'работает'
 echo 1
 exit 0
fi
