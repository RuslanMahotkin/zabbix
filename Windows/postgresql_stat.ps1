# Отправка статистики сервера PostgreSQL на сервер Zabbix

# Полное имя исполняемого файла клиента PostgreSQL
$PsqlExec = 'E:\PostgreSQL\9.4.2-1.1C\bin\psql'


function PSql($SQLStr){
# Выполнение запросов вызовом psql. Параметры: 1 - строка SQL-запросов

 # Выполнение запросов:
 #  quiet - без сообщений, только результата запроса;
 #  field-separator= - разделитель полей;
 #  no-align - режим невыравненной таблицы;
 #  tuples-only - только строки результата
 $RespStr = & $PsqlExec --quiet --field-separator=" " --no-align --tuples-only --host=127.0.0.1 --username=zabbix --command="$SQLStr;" template1 2>&1
 # Выполнение запросов успешно - возврат строки результата
 if( $? ){ return $RespStr }
 # Статистика недоступна - возврат статуса сервиса - 'не работает'
 Write-Host 0
 # Выход из сценария
 exit 1
}


# Получение строки списка БД
$DBStr = PSql "SELECT datname FROM pg_stat_database where datname not like 'template%'"

# Есть аргумент командной строки определения БД
if( $args[0] -and $args[0] -eq 'db' ){
 # Трансляция строки списка БД в формат JSON
 $DBStr = $DBStr -split '`n' -join '"},{"{#DBNAME}":"'
 if( $DBStr ){ $DBStr = "{`"{#DBNAME}`":`"" + $DBStr + "`"}" }
 $DBStr = "{`"data`":[" + $DBStr + "]}"
 # Вывод JSON-списка БД
 Write-Host -NoNewLine $DBStr

# Отправка данных
}else{
 # Строка SQL-запросов
 $SelectsStr = '';
 # Добавление в строку запросов статистики по БД
 # Запросы значения поля из таблицы pg_stat_database для БД
 'numbackends', 'deadlocks', 'tup_returned', 'tup_fetched', 'tup_inserted', 'tup_updated',`
  'tup_deleted', 'temp_files', 'temp_bytes', 'blk_read_time', 'blk_write_time',`
  'xact_commit', 'xact_rollback' | Where { $SelectsStr += "select '- postgresql." + $_ +
  "['||datname||'] '||" + $_ + " from pg_stat_database where datname not like 'template%' union " }
 # Комплексные запросы для БД
 $DBStr -split '`n' | Where { $SelectsStr += "select '- postgresql.size[" + $_ +
  "] '||pg_database_size('" + $_ + "') union select '- postgresql.cache[" + $_ +
  "] '||cast(blks_hit/(blks_read+blks_hit+0.000001)*100.0 as numeric(5,2)) from pg_stat_database where datname='" +
  $_ + "' union select '- postgresql.success[" + $_ +
  "] '||cast(xact_commit/(xact_rollback+xact_commit+0.000001)*100.0 as numeric(5,2)) from pg_stat_database where datname='" +
  $_ + "' union "
  }
 
 # Добавление в строку запросов общей статистики
 # Запросы значения количества из таблицы pg_stat_activity: 'параметр' = 'фильтр'
 @{
  'active'   = "state='active'";
  'idle'     = "state='idle'";
  'idle_tx'  = "state='idle in transaction'";
  'server'   = '1=1';
  'waiting'  = "waiting='true'";
 }.GetEnumerator() | Where { $SelectsStr += "select '- postgresql.connections." + $_.Key +
  " '||count(*) from pg_stat_activity where " + $_.Value + " union " }

 # Запросы значения поля из таблицы pg_stat_activity
 'buffers_alloc', 'buffers_backend', 'buffers_backend_fsync', 'buffers_checkpoint',`
  'buffers_clean', 'checkpoints_req', 'checkpoints_timed', 'maxwritten_clean' |
  Where { $SelectsStr += "select '- postgresql." + $_ + " '||" + $_ +
  " from pg_stat_bgwriter union " }

 # Запросы количества медленных запросов из таблицы pg_stat_activity: 'параметр' = 'фильтр'
 @{
  'slow.dml'     = "~* '^(insert|update|delete)'";
  'slow.queries' = "ilike '%'";
  'slow.select'  = "ilike 'select%'";
 }.GetEnumerator() | Where { $SelectsStr += "select '- postgresql." + $_.Key +
  " '||count(*) from pg_stat_activity where state='active' and now()-query_start>'5 sec'::interval and query " +
  $_.Value + " union " }

 # Максимальное количество соединений
 $SelectsStr += "select '- postgresql.connections.max '||setting::int from pg_settings where name='max_connections'"

 # Выполнение запросов и отправка строки вывода серверу Zabbix. Параметры zabbix_sender:
 #  --config      файл конфигурации агента;
 #  --host        имя узла сети на сервере Zabbix;
 #  --input-file  файл данных('-' - стандартный ввод)
 PSql $SelectsStr | c:\Scripts\zabbix_sender.exe --config "c:\Scripts\zabbix_agentd_win.conf" --host "DNS.имя.сервера" --input-file - 2>&1 | Out-Null

 # Возврат статуса сервиса - 'работает'
 Write-Host 1
}
