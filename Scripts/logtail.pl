#!/usr/bin/perl -w
# Вывод добавленной с последнего запуска сценария части файла журнала

use strict;
use Getopt::Long;


# Хэш опций командной строки
my %Opts = ();
# Обработка командной строки
GetOptions(\%Opts, 'logfile=s', 'offset=s');
$Opts{logfile} and $Opts{offset} or
 print(STDERR "Ошибка: параметры --logfile=журнал --offset=смещение\n") and
 exit(66);

# Открытие файла журнала, номер и размер файла журнала
open(LOGFILE, $Opts{logfile}) and my($ino, $size) = (stat($Opts{logfile}))[1, 7]
 or print(STDERR "Ошибка: открытие файла '$Opts{logfile}'\n") and exit 66;

# Получение номера файла журнала и смещения в нем из файла смещения
my($inode, $offset);
open(OFFSET, $Opts{offset}) and $_ = <OFFSET> and close(OFFSET) and
 ($inode, $offset) = /^(\d+)\t(\d+)$/ or ($inode, $offset) = (0, 0);

# Номер файла журнала не изменился
if($inode == $ino){
 # Файл журнала не изменился - выход
 $offset == $size and exit(0);
 # Смещение меньше размера файла журнала и позиция в файле журнала - смещение
 # или аналогично первому запуску
 $offset < $size and seek(LOGFILE, $offset, 0) or $inode = 0;
}

# Сохранен номер файла журнала - запуск не первый
if($inode){
 # Вывод строк журнала
 while(<LOGFILE>){ print $_; }
 # Смещение в файле журнала после последней строки
 $size = tell(LOGFILE);
}
# Закрытие файла журнала
close(LOGFILE);

# Сохранение номера и смещения файла журнала в файле смещения
open(OFFSET, ">$Opts{offset}") and print(OFFSET "$ino\t$size") and close(OFFSET)
 or print(STDERR "Ошибка: файл смещения $Opts{offset}\n") and exit(73);

exit 0;
