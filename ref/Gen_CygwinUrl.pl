#!/usr/bin/perl -w
use strict;

print qq!<HTML>\n<HEAD>\n<TITLE>CYGWIN PACKAGE URL</TITLE>\n!;
print qq!<META http-equiv=Content-Type content="text/html; charset=iso-8859-1">\n!;
print qq!<BASE href="http://cygwin.elite-systems.org/">\n!;
print qq!</HEAD>\n<BODY>\n!;

my $skipit = 1;
my $urlfilename;
my $urlfound = 1;
my @anomalypackage;
my @obsoletepackage;
my $lastpackage;

while (<>) {
    print $_, "<BR>\n" if (/^setup-timestamp:/);
    print $_, "<BR>\n" and last if (/^setup-version:/);
}

print "<br><br><br><br><b><u>CYGWIN Package list:</b></u><br>\n";
print "<a href=md5.sum>md5.sum</a><br>\n<a href=setup.bz2>setup.bz2</a><br>\n<a href=http://www.cygwin.com/setup.exe>setup.exe</a><br>\n<a href=setup.ini>setup.ini</a><br>\n";

while (<>) {
    if (/^@ (.+)/) {
        $skipit = 0 ;
        if (! $urlfound) {
            push @anomalypackage, $lastpackage;
        }
        $lastpackage = $1;
        $urlfound = 0;
    }
       
    $skipit = 1 if (/^\[prev\]$/);
    
    if (/^category: _obsolete$/) {
        $skipit = 1; #don't process anymore
        push @obsoletepackage, $lastpackage;
        $urlfound = 1; #avoid put in @anomalypackage
    }
    
    if (! $skipit) {
        if (/^install: (\S+).*/) {
            $urlfilename = substr($1, rindex($1, "/") + 1);
            print "<a href=\"$1\">$urlfilename</a><br>\n";
            $urlfound = 1;
        }
    }
}    

print "<br><br><br><br><b><u>Obsolete Package:</u></b><br>\n", join "<br>\n", @obsoletepackage;
print "<br><br><br><br><font color=\"#ff0000\"><b><u>URL not found for following Package:</u></b><br>\n", join("<br>\n", @anomalypackage), "</font>";

print qq!</BODY>\n</HTML>!;