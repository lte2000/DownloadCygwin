@echo off
REM -----------------------------------------------------------------
REM Description: launch docygwin to validate cygwin
REM $Id: validateCygwin.cmd,v 1.1 2011-04-23 12:34:45 jyliu Exp $
REM -----------------------------------------------------------------

docygwin.pl --target "d:\temp\cygwin64" --skip32 --noskip64 --validate --validatedigest --nodeleteorphans --noskipsetup --noskippackage --verbose 1