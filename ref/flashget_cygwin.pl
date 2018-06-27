#!/usr/bin/perl -w
use strict;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);

my $source_url = "http://cygwin.elite-systems.org/";
my $target_dir = "d:\\temp\\cygwin\\";
my $flashget = "C:\\Program Files\\FlashGet\\FLASHGET.EXE";


system $flashget, $source_url . "setup.ini", $target_dir;
system $flashget, $source_url . "md5.sum", $target_dir;
system $flashget, $source_url . "setup.bz2", $target_dir;

my $ticker = 0;
while (! (-e $target_dir . "setup.ini" && -e $target_dir . "md5.sum")) {
    sleep 1;
    die "setup file is not exist in 5 minutes.\n" if (++$ticker > 300);
}

chdir $target_dir or die "Can't CD $target_dir: $!\n";

open MD5SUM, "<md5.sum" or die "Can't open md5.sum: $!\n";;
my (%md5);
while (<MD5SUM>) {
    /^(\S+)\s+(\S+)/;
    $md5{$2} = $1;
}
close MD5SUM;

die "setup file error.\n" if (file_md5_hex("setup.ini") ne $md5{"setup.ini"});

my $skipit = 1;
my $urldirname;
my $urlfound = 1;
my @anomalypackage;
my @obsoletepackage;
my $lastpackage;

open SETUPINI, "<setup.ini" or die "Can't open setup.ini: $!\n";
while (<SETUPINI>) {
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
            $urldirname = substr($1, 0, rindex($1, "/"));
            $urldirname =~ y!/!\\!;
            system $flashget, $source_url . $1, $target_dir . $urldirname;
            $urlfound = 1;
        }
    }
}
close SETUPINI;

system $flashget, "http://www.cygwin.com/setup.exe", $target_dir;

print STDERR "\nObsolete Package:\n", join "\n", @obsoletepackage;
print STDERR "\nURL not found for following Package:\n", join("\n", @anomalypackage);

