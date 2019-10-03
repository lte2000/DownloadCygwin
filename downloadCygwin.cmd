@echo off

docygwin.pl --source http://mirrors.ustc.edu.cn/cygwin/ --target "d:\temp\cygwin" --aria2c .\aria2c.exe --setupproxy 127.0.0.1:7070 --noskip32 --noskip64 --noskipsetup --noskippackage --noskipdlpackage --skipdlexist --validatedigest --verbose 1

