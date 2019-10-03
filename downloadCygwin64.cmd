@echo off

docygwin.pl --source http://mirrors.zju.edu.cn/cygwin/ --target "d:\temp\cygwin64" --aria2c .\aria2c.exe --setupproxy 127.0.0.1:7070 --skip32 --noskip64 --noskipsetup --noskippackage --noskipdlpackage --skipdlexist --validatedigest --verbose 1

