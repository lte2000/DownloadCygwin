@echo off

docygwin.pl --source http://mirrors.ustc.edu.cn/cygwin/ --target "d:\temp\cygwin" --aria2c .\aria2c.exe --noskip32 --skip64 --skipsetup --noskippackage --noskipdlpackage --skipdlexist --validatedigest --verbose 1
