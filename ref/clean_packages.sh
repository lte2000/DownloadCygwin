# find, delete packageds that is not in setup.ini
cd /cygdrive/d/temp/cygwin
find release -type f ! -exec grep -q -F \{\} setup.ini \; -print
## find release -type f ! -exec grep -q -F \{\} setup.ini \; -print -delete
# find, delete empty directory
find release -type d -empty -print
## find release -type d -empty -print -delete