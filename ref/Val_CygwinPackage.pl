#!/usr/bin/perl -w
use strict;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);

my ($skipit) = 1;
my ($errorcnt) = 0;

chdir $ARGV[0] or die "Can't CD $ARGV[0]: $!\n" if ($#ARGV >= 0);

open MD5SUM, "<md5.sum" or die "Can't open md5.sum: $!\n";;
my (%md5);
while (<MD5SUM>) {
    /^(\S+)\s+(\S+)/;
    $md5{$2} = $1;
}
my ($tmp);
for $tmp qw(setup.ini setup.bz2) {
    if (! -e $tmp) {
        print "ERROR: $tmp NOT FOUND.\n";
        $errorcnt++;
    } elsif (file_md5_hex($tmp) eq $md5{$tmp}) {
        print "$tmp: $md5{$tmp} OK.\n";
    } else {
        print "ERROR MD5: $tmp\n";
        $errorcnt++;
    }
}
close MD5SUM;

die "setup file error.\n" if ($errorcnt);

open SETUPINI, "<setup.ini" or die "Can't open setup.ini: $!\n";
while (<SETUPINI>) {
    $skipit = 0 if (/^@ (.+)/);
    $skipit = 1 if (/^\[prev\]$/ || /^category: _obsolete$/);
  
    if (! $skipit) {
        if (/^install: (\S+) \S+ (\S+)/) {
            if (! -e $1) {
                print "ERROR: $1 NOT FOUND.\n";
                $errorcnt++;
            } elsif (file_md5_hex($1) eq $2) {
                print "$1: $2 OK.\n";
            } else {
                print "ERROR MD5: $1\n";
                $errorcnt++;
            }
        }
    }
}

close SETUPINI;

if ($errorcnt) {
    print STDERR "There're $errorcnt error detected when validate the package list.\nPlease check the log.\n";
} else {
    print STDERR "All package is correct.\n";
}
