#!/usr/bin/perl -w

#-----------------------------------------------------------------
# Description: core file for DownloadCygwin
# $Id: docygwin.pl,v 1.2 2011-04-24 04:09:44 jyliu Exp $
#-----------------------------------------------------------------

use strict;
use Getopt::Long;
use Digest::file qw(digest_file_hex);
use File::Find;
use Data::Dumper qw(Dumper);

my $source = "http://mirrors.ustc.edu.cn/cygwin/";
my $target = "d:\\temp\\cygwin\\";
my $aria2c = "aria2c.exe";
my $skip64 = 0;
my $skip32 = 0;
my $validate = 0;
my $validatedigest = 1;
my $deleteorphans = 0;
my $showpackageinfo = 0;
my $skipsetup = 0;
my $skipdlsetup = 0;
my $skippackage = 0;
my $skipdlpackage = 0;
my $skipdlexist = 0;
my $verbose = 0;
my $custompackages = "cygwinpackage.ini";
my $setupproxy = "";

my %x86_packages;
my %x86_64_packages;
my %x86_to_download_packages;
my %x86_to_exclude_packages;
my %x86_64_to_download_packages;
my %x86_64_to_exclude_packages;
my %union_to_download_packages;
my %union_to_exclude_packages;
my @include_category;
my @exclude_category;
my @include_package;
my @exclude_package;

sub showUsage()
{
    print <<END_HELP_TEXT;
Usage: $0 [OPTION...]
   --source URL     = (mirror) URL to download cygwin.
                      default is $source
   --target DIR     = target DIR to store cygwin.
                      default is $target
   --aria2c PATH    = path for aria2c.exe (include file name).
                      default is $aria2c   

   --skip64         = skip x86_64 packages process.
   --skip32         = skip x86 packages process.

   --validate       = to validate the packages instead of download.
   --novalidatedigest = don't validate the package's digest.
   --deleteorphans  = remove orphaned packages and empty directory
                      during validating.

   --showpackageinfo = print category and package information and quit.

   --skipsetup      = skip setup files process.
   --skipdlsetup    = no real download action for setup files.
   --skippackage    = skip packages process.
   --skipdlpackage  = no real download action for packages.
   --skipdlexist    = don't download if the package exist and validation
                      is correct
   --custompackages PATH = path for custom specified categories and packages
                           which to be included or excluded.
                           defaut is $custompackages
   --setupproxy PROXY    = proxy only for download setup files. 
   --verbose        = detail info
   --help           = this help          
END_HELP_TEXT
}

sub parseOptions()
{
    my $needhelp;
    my $result = GetOptions(
         "source=s"         => \$source,
         "target=s"         => \$target,
         "aria2c=s"         => \$aria2c,
         "skip64!"          => \$skip64,
         "skip32!"          => \$skip32,  
         "validate"         => \$validate,
         "validatedigest!"  => \$validatedigest,
         "deleteorphans!"   => \$deleteorphans,
         "showpackageinfo"  => \$showpackageinfo,
         "skipsetup!"       => \$skipsetup,
         "skipdlsetup!"     => \$skipdlsetup,
         "skippackage!"     => \$skippackage,
         "skipdlpackage!"   => \$skipdlpackage,
         "skipdlexist!"     => \$skipdlexist,
         "custompakcages=s" => \$custompackages,
         "setupproxy=s"     => \$setupproxy,
         "verbose:+"        => \$verbose,
         "help|h|?"         => \$needhelp
    );
    
    if ($needhelp || !$result) {
        showUsage;
        die "\n";
    }
    
    $source = $source . "/" if substr($source, -1) ne "/";
    $target = $target . "\\" if substr($target, -1) ne "\\";
}

sub processCustomPackage()
{
    if (not open PKGINI, "<$custompackages") {
        print "Warning: Can't open $custompackages: $!\n";
        print "Process custom packages specifiation skipped.\n";
        return;
    }
    my $section;
    while (<PKGINI>) {
        s/^\s+|\s+$//g;
        if (! $_) {
            next;
        } elsif (/^\[(.+)\]$/) {
            $section = $1;
        } else {
            if ($section eq "include_category") {
                push @include_category, $_;
            } elsif ($section eq "exclude_category") {
                push @exclude_category, $_;
            } elsif ($section eq "include_package") {
                push @include_package, $_;
            } elsif ($section eq "exclude_package") {
                push @exclude_package, $_;
            }
        }
    }
    close PKGINI;
    #print Dumper \@include_category, \@exclude_category, \@include_package, \@exclude_package;
}

#sub parseOptions()
#{
#    my $needhelp;
#    my $result = GetOptions(
#         "source=s"         => \$source,
#         "target=s"         => \$target,
#         "flashget=s"       => \$flashget,
#         "useflashget"      => sub {$useflashget=1; $usearia2c=0},
#         "usecuteftp"       => sub {$useflashget=0; $usearia2c=0},
#         "usearia2c"        => sub {$useflashget=0; $usearia2c=1},
#         "aria2c=s"         => \$aria2c,
#         "legacy"           => sub {$legacy = "-legacy"},
#         "validate"         => \$validate,
#         "validatedigest!"   => \$validatedigest,
#         "skipsetup!"       => \$skipsetup,
#         "skipexist!"       => \$skipexist,
#         "skip64!"          => \$skip64,
#         "skip32!"          => \$skip32,  
#         "skiprarelyuse!"    => \$skipRarelyUse,
#         "skippackage!"     => \$skippackage,
#         "deleteorphans!"    => \$deleteorphans,
#         "showpackageinfo!" => \$showpackageinfo,
#         "verbose:+"        => \$verbose,
#         "help|h|?"         => \$needhelp
#    );
#    
#    # not support flashget, cuteftp anymore
#    $useflashget=0; $usearia2c=1;
#    
#    # not support legacy anymore
#    $legacy = "";
#    
#    if ($needhelp || !$result) {
#        showUsage;
#        die "\n";
#    }
#    
#    #die "ERROR: Directory \"$target\" is not exist.\n" if ! -d $target;
#    $source = $source . "/" if substr($source, -1) ne "/";
#    $target = $target . "\\" if substr($target, -1) ne "\\";
#    #die "ERROR: Program \"$flashget\" is not exist.\n" if ! -f $flashget;
#    $setup = "$setup$legacy";
#    my $saveto = $target;
#    $saveto =~ s/\\$//;
#    $flashgetHead = <<ENDOFHEAD;
#\@echo off    
#set flashget="$flashget"
#start "" \%flashget\%
#ping -n 5 127.0.0.1 >nul 2>&1
#set source=$source
#set saveto=$saveto
#ENDOFHEAD
#    $cuteftpHead = <<ENDOFHEAD;
#if not defined =0then' \@wscript %0 //E:VBSCRIPT & goto :eof
#end if
#Dim s
#Set s = CreateObject("CuteFTPPro.TEConnection")
#s.MaxConnections = 10
#s.Host = "$source"
#s.LocalFolder = "$saveto"
#ENDOFHEAD
#}


sub downloadSetup()
{
    my $getsetup = "_get_setup.cmd";
    open GETSETUP, ">$getsetup" or die "ERROR: Can't create $getsetup: $!\n";
    my @arch_setup = ("setup.ini", "setup.bz2", "setup.xz");
    my @x86_setup = @arch_setup;
    push @x86_setup, map { $_ . ".sig"} @arch_setup;
    my @x86_64_setup = @x86_setup;

    #print GETSETUP "$aria2c -Z -j10 --allow-overwrite=true -d$target $source$setup.ini.sig $source$setup.ini $source$setup.bz2 $source$setup.bz2.sig http://cygwin.com/$setup.exe http://cygwin.com/$setup.exe.sig";
    my $setupexe = "";
    if (! $skip32) {
        my $srcurl = join(" ", map { "${source}x86/" . $_ } @x86_setup);
        print GETSETUP "$aria2c -Z --conf-path=aria2c.conf -d${target}x86 $srcurl\n";
        $setupexe = "https://cygwin.com/setup-x86.exe https://cygwin.com/setup-x86.exe.sig";
    }
    if (! $skip64) {
        my $srcurl = join(" ", map { "${source}x86_64/" . $_ } @x86_64_setup);
        print GETSETUP "$aria2c -Z --conf-path=aria2c.conf -d${target}x86_64 $srcurl\n";
        $setupexe = $setupexe . " https://cygwin.com/setup-x86_64.exe https://cygwin.com/setup-x86_64.exe.sig";
    }
    if ($setupexe) {
        my $proxy;
        if ($setupproxy) {
            $proxy = "--all-proxy=$setupproxy";
        }
        print GETSETUP "$aria2c -Z --conf-path=aria2c.conf $proxy -d$target $setupexe\n";
    }
    close GETSETUP;

    if (! $skipdlsetup) {
        system "$getsetup";
    }
}

#sub downloadSetup()
#{
#    my $getsetup = "_get_$setup.cmd";
#    open GETSETUP, ">$getsetup" or die "ERROR: Can't create $getsetup: $!\n";
#    my @arch_setup = ("$setup.ini", "$setup.bz2", "$setup.xz");
#    my @x86_setup = @arch_setup;
#    push @x86_setup, map { $_ . ".sig"} @arch_setup;
#    my @x86_64_setup = @x86_setup;
#    
#
#    if ($usearia2c) {
#        #print GETSETUP "$aria2c -Z -j10 --allow-overwrite=true -d$target $source$setup.ini.sig $source$setup.ini $source$setup.bz2 $source$setup.bz2.sig http://cygwin.com/$setup.exe http://cygwin.com/$setup.exe.sig";
#        my $setupexe = "";
#        if (! $skip32) {
#            my $srcurl = join(" ", map { "${source}x86/" . $_ } @x86_setup);
#            print GETSETUP "$aria2c -Z -j10 --allow-overwrite=true -d${target}x86 $srcurl\n";
#            $setupexe = "https://cygwin.com/$setup-x86.exe https://cygwin.com/$setup-x86.exe.sig";
#        }
#        if (! $skip64) {
#            my $srcurl = join(" ", map { "${source}x86_64/" . $_ } @x86_64_setup);
#            print GETSETUP "$aria2c -Z -j10 --allow-overwrite=true -d${target}x86_64 $srcurl\n";
#            $setupexe = $setupexe . " https://cygwin.com/$setup-x86_64.exe https://cygwin.com/$setup-x86_64.exe.sig";
#        }
#        if ($setupexe) {
#            print GETSETUP "$aria2c -Z -j10 --max-connection-per-server=5 --min-split-size=1M --allow-overwrite=true -d$target $setupexe\n";
#        }
#    } else {
#        print GETSETUP $useflashget ? <<ENDOFFLASHGET : <<ENDOFCUTEFTP;
#$flashgetHead
#%flashget% "\%source\%$setup.ini" "%saveto%"
#%flashget% "\%source\%$setup.ini.sig" "%saveto%"
#%flashget% "\%source\%$setup.bz2" "%saveto%"
#%flashget% "\%source\%$setup.bz2.sig" "%saveto%"
#%flashget% "http://cygwin.com/$setup.exe" "%saveto%"
#%flashget% "http://cygwin.com/$setup.exe.sig" "%saveto%"
#ENDOFFLASHGET
#$cuteftpHead
#s.Download "$setup.ini.sig"
#s.Download "$setup.ini"
#s.DownloadAsync "$setup.bz2"
#s.DownloadAsync "$setup.bz2.sig"
#s.Host = "http://cygwin.com/"
#s.DownloadAsync "$setup.exe"
#s.DownloadAsync "$setup.exe.sig"
#Set s = Nothing
#ENDOFCUTEFTP
#    }
#    close GETSETUP;
#
#    if (! $skipsetup) {
#        if ($usearia2c) {
#            #system "$getsetup";
#        } else {
#            print "Warning: $target$setup.* will be deleted.\n" if $verbose >= 1;
#            unlink <$target$setup.*>;
#            if ($usearia2c) {
#                system "$getsetup";
#            } else {
#                system "$getsetup >nul 2>&1";
#            }
#            my $ticker = 0;
#            while (! (-e "$target$setup.ini" && -e "$target$setup.ini.sig")) {
#                sleep 3;
#                die "ERROR: setup file is not exist in 5 minutes.\n" if (++$ticker > 100);
#            }
#        }
#    }
#}

sub validateSetup()
{
    my @sig_file;
    my @arch_setup = ("setup.ini", "setup.bz2", "setup.xz");
    if (! $skip32) {
        push @sig_file, $target . "setup-x86.exe.sig";
        push @sig_file, map { $target . "x86\\" . $_ . ".sig"} @arch_setup;
    }
    if (! $skip64) {
        push @sig_file, $target . "setup-x86_64.exe.sig";
        push @sig_file, map { $target . "x86_64\\" . $_ . ".sig"} @arch_setup;
    }
    for (@sig_file) {
        my $result = `gpgv --keyring .\\cygwin.gpg $_ 2>&1`;
        die "ERROR: $_ signature check failed.\n$result\n" if $?;
        print "$_ signature check OK.\n" if $verbose >= 4;
    }    
}

sub genPackageList()
{
    # generate %x86_packages %x86_64_packages
    foreach my $arch (("x86", "x86_64")) {
        if (($arch eq "x86" && ! $skip32) || ($arch eq "x86_64" && ! $skip64)) {
            open SETUPINI, "<${target}$arch\\setup.ini" or die "ERROR: Can't open ${target}$arch\\setup.ini: $!\n";
            local $/ = undef;
            my $content = <SETUPINI>;
            close SETUPINI;
            my $packagevar;
            if ($arch eq "x86") {
                $packagevar = \%x86_packages;
            } else {
                $packagevar = \%x86_64_packages;
            }
            
            my @raw_package_list = split(/\n(?=@)/, $content);
            shift @raw_package_list;
            for (@raw_package_list) {
                my @lines = split "\n";
                my $package_name;
                my @category;
                my @requires;
                my $path;
                my $size;
                my $md5;
                my $sdesc;
                for (@lines) {
                    if (/^@ (.+)/) {
                        $package_name = $1;
                    } elsif (/^category: (.+)/) {
                        @category = split " ", $1;
                    } elsif (/^requires: (.+)/) {
                        @requires = split " ", $1;
                    } elsif (/^install: (\S+)\s+(\S+)\s+(\S+)/) {
                        $path = $1;
                        $size = $2;
                        $md5 = $3;
                    } elsif (/^sdesc: "(.*)"/) {
                        $sdesc = $1;
                    } elsif (/^\[.*\]$/) {
                        last;
                    }
                }
                # no path? try [test]
                if (! $path) {
                    my $in_test = 0;
                    for (@lines) {
                        if (/^\[test\]$/) {
                            $in_test = 1;
                            next;
                        }
                        if ($in_test && /^install: (\S+)\s+(\S+)\s+(\S+)/) {
                            print "$package_name use install path in [test].\n";
                            $path = $1;
                            $size = $2;
                            $md5 = $3;
                            last;
                        }
                        if (/^\[.*\]$/) {
                            $in_test = 0;
                        }
                    }
                }
                die "ERROR: Can't get package_name $_\n" if ! $package_name;
                die "ERROR: Can't get path $_\n" if ! $path;
                ## need declare %x86_packages without my;
                ## ${"${arch}_packages"}{$package_name} = {"category"=>[@category], "requires"=>[@requires], "path"=>$path, "size"=>$size, "md5" => $md5};
                $packagevar->{$package_name} = {"category"=>[@category], "requires"=>[@requires], "path"=>$path, "size"=>$size, "md5" => $md5, "sdesc"=>$sdesc};
            }
        }
    }
    # generate %x86_to_download_packages %x86_64_to_download_packages
    foreach my $arch (("x86", "x86_64")) {
        my $packagevar;
        my $todownloadvar;
        my $toexcludevar;
        if ($arch eq "x86") {
            $packagevar = \%x86_packages;
            $todownloadvar = \%x86_to_download_packages;
            $toexcludevar = \%x86_to_exclude_packages;
        } else {
            $packagevar = \%x86_64_packages;
            $todownloadvar = \%x86_64_to_download_packages;
            $toexcludevar = \%x86_64_to_exclude_packages;
        }
        
        my $to_be_included;
        LOOPPKG: while (my ($name, $attr) = each %$packagevar) {
            $to_be_included = 0;
            foreach (@include_package) {
                if (/^reg:(.+)$/) {
                    if ($name =~ /$1/) {
                        $to_be_included = 1;
                        next LOOPPKG;
                    }
                } elsif ($name eq $_) {
                    $to_be_included = 1;
                    next LOOPPKG;
                }
            }
            foreach (@exclude_package) {
                if (/^reg:(.+)$/) {
                    if ($name =~ /$1/) {
                        $to_be_included = 0;
                        next LOOPPKG;
                    }
                } elsif ($name eq $_) {
                    $to_be_included = 0;
                    next LOOPPKG;
                }
            }
            $to_be_included = 1;
            my @filtered_category;
            for (@{$attr->{"category"}}) {
                if ($_ ~~ @include_category) {
                    push @filtered_category, $_;
                } elsif (not $_ ~~ @exclude_category) {
                    push @filtered_category, $_;
                }
            }
            if (! @filtered_category) {
                $to_be_included = 0;
                next LOOPPKG;
            }
            #$attr->{"category"} = [@filtered_category];
        } continue {
            if ($to_be_included) {
                $$todownloadvar{$name} = $attr;
            } else {
                $$toexcludevar{$name} = $attr;
            }
        }
        
        my $package_list_modified;
        do {
            $package_list_modified = 0;
            while (my ($name, $attr) = each %$todownloadvar) {
                for (@{$attr->{"requires"}}) {
                    if (! exists $$todownloadvar{$_}) {
                        $$todownloadvar{$_} = $$packagevar{$_};
                        delete $$toexcludevar{$_};
                        print "$arch package $_ is added as required by $name.\n" if $verbose >= 5;
                        if ("_obsolete" ~~ $$packagevar{$_}{"category"}) {
                            my $category = join ", ", @{$$packagevar{$_}{"category"}};
                            print "    $_ is in category $category.\n" if $verbose >= 5;
                        }
                        $package_list_modified = 1;
                    }
                }
            }
        } while $package_list_modified;
    }
    # generate %union_to_download_packages
    %union_to_download_packages = %x86_to_download_packages;
    while (my ($name, $attr) = each %x86_64_to_download_packages) {
        if (! exists $x86_to_download_packages{$name}) {
            $union_to_download_packages{$name} = $attr;
        } elsif ($$attr{"path"} ne $x86_to_download_packages{$name}{"path"}) {
            print "package $name exists in both x86 and x86_64, with different path $x86_to_download_packages{$name}{'path'}, $$attr{'path'}\n" if $verbose >= 5;
            $union_to_download_packages{$name . "[x86_64]"} = $attr;
        }
    }
    %union_to_exclude_packages = %x86_to_exclude_packages;
    while (my ($name, $attr) = each %x86_64_to_exclude_packages) {
        if (! exists $x86_to_exclude_packages{$name}) {
            $union_to_exclude_packages{$name} = $attr;
        } elsif ($$attr{"path"} ne $x86_to_exclude_packages{$name}{"path"}) {
            print "package $name exists in both x86 and x86_64, with different path $x86_to_exclude_packages{$name}{'path'}, $$attr{'path'}\n" if $verbose >= 5;
            $union_to_exclude_packages{$name . "[x86_64]"} = $attr;
        }
    }
}

sub commify {
    my $input = shift;
    $input = reverse $input;
    $input =~ s<(\d\d\d)(?=\d)(?!\d*\.)><$1,>g;
    return scalar reverse $input;
}
    
sub printPackageInfo()
{
    foreach my $pkg (("x86", "x86_64", "x86_to_download", "x86_64_to_download", "union_to_download")) {
        my $totalsize = 0;
        my %categorysize;
        my %categorycount;
        my %categorycontent;
        my $packagevar;
        my $toexcludevar;
        
        if ($pkg eq "x86") {
            $packagevar = \%x86_packages;
        } elsif ($pkg eq "x86_64") {
            $packagevar = \%x86_64_packages;
        } elsif ($pkg eq "x86_to_download") {
            $packagevar = \%x86_to_download_packages;
            $toexcludevar = \%x86_to_exclude_packages;
        } elsif ($pkg eq "x86_64_to_download") {
            $packagevar = \%x86_64_to_download_packages;
            $toexcludevar = \%x86_64_to_exclude_packages;
        } elsif ($pkg eq "union_to_download") {
            $packagevar = \%union_to_download_packages;
            $toexcludevar = \%union_to_exclude_packages;
        }
        while (my ($name, $attr) = each %$packagevar) {
            $totalsize += $attr->{"size"};
            for (@{$attr->{"category"}}) {
                $categorycount{$_}++;
                $categorysize{$_} += $attr->{"size"};
                push @{$categorycontent{$_}}, $name;
            }
        }
        print "#" x 70, "\n";
        print "$pkg information:\n";
        print "Total size: ", commify($totalsize), "\n";
        print "Category:\n";
        for (sort(keys(%categorycount))) {
            print "    $_: $categorycount{$_} ", commify($categorysize{$_}), "\n";
            if ($verbose >= 3) {
                foreach (sort {uc($a) cmp uc($b)} @{$categorycontent{$_}}) {
                    print "        $_: ", commify($$packagevar{$_}{'size'}), "\n";
                }
            }
        }
        if ($verbose >= 1) {
            print "Packages:\n";
            if ($pkg ~~ ["x86_to_download", "x86_64_to_download", "union_to_download"]) {
                foreach (sort {$$packagevar{$b}{'size'} <=> $$packagevar{$a}{'size'}} keys(%$packagevar)) {
                    print "    $_: ", commify($$packagevar{$_}{'size'}), "\n";
                }
            } else {            
                foreach (sort {uc($a) cmp uc($b)} keys(%$packagevar)) {
                    print "    $_: $$packagevar{$_}{'size'}\n";
                }
            }
        }
        if ($verbose >= 2) {
            print "Packages excluded:\n";
            if ($pkg ~~ ["x86_to_download", "x86_64_to_download", "union_to_download"]) {
                foreach (sort {uc($a) cmp uc($b)} keys(%$toexcludevar)) {
                    print "    $_: $$toexcludevar{$_}{'size'} $$toexcludevar{$_}{'sdesc'}\n";
                }
            }
        }        
    }
}

#sub genPackageList_old()
#{
#    my $skipit = 1;
#    my $urlfound = 1;
#    my $lastpackage;
#    open SETUPINI, "<$target$setup.ini" or die "ERROR: Can't open $target$setup.ini: $!\n";
#    while (<SETUPINI>) {
#        if (/^@ (.+)/) {
#            $skipit = 0 ;
#            push @anomalypackages, $lastpackage if !$urlfound;
#            $lastpackage = $1;
#            $urlfound = 0;
#        }
#        
#        if ($skip64) {
#            if (/^@ (.*64.*)/) {
#                $skipit = 1; #don't process anymore
#                push @skippackages, $lastpackage;
#                $urlfound = 1; #avoid put in @anomalypackage
#            }
#        }
#        
#        if (! $skipit && /^\[prev\]$/) {
#            $skipit = 1;
#        }
#        
#        if (! $skipit && /^category: _obsolete$/) {
#            $skipit = 1; #don't process anymore
#            push @obsoletepackages, $lastpackage;
#            $urlfound = 1; #avoid put in @anomalypackage
#        }
#
#        # don't need these packages ?? 
#        if (! $skipit && $skipRarelyUse && /^category: (.*Accessibility.*|.*Debug.*|.*Games.*|.*Publishing.*)/i) {
#            $skipit = 1; #don't process anymore
#            push @skippackages, $lastpackage;
#            $urlfound = 1; #avoid put in @anomalypackage
#        }
#        
#        if (! $skipit) {
#            if (/^install: (\S+) \S+ (\S+)/) {
#                $packages{$1} = $2;
#                $urlfound = 1;
#            }
#            if ($urlfound == 0 && /^source: (\S+) \S+ (\S+)/) {
#                $packages{$1} = $2;
#                $urlfound = 1;
#            }
#        }
#    }
#    close SETUPINI;
#    print "INFO: Obsolete Packages:\n", "-" x 60, "\n", join("\n", @obsoletepackages), "\n\n" if $verbose >= 2 && @obsoletepackages > 0;
#    print "INFO: URL not found for following Packages:\n", "-" x 60, "\n", join("\n", @anomalypackages), "\n\n" if $verbose >= 2 && @anomalypackages > 0;
#    if (@skippackages > 0) {
#        print "INFO: Skipped Packages:\n", "-" x 60, "\n", join("\n", @skippackages), "\n\n";
#    }
#}

# only aria2c
sub downloadPackages()
{
    my $getpackage = "_get_package.cmd";
    my $getpackage_in = "_get_package.in";
    my $getpackage_session = "_get_package.session";
    my $skipit;

    open GETPACKAGE, ">$getpackage" or die "ERROR: Can't create $getpackage: $!\n";
    open GETPACKAGE_IN, ">$getpackage_in" or die "ERROR: Can't create $getpackage_in: $!\n";

    while (my ($name, $attr) = each %union_to_download_packages) {
        my $path = $$attr{"path"};
        my $md5 = $$attr{"md5"};
        my $size = $$attr{"size"};
        my $fullfilename = $target . $path;
        $skipit = 0;
        if ($skipdlexist && -e "$fullfilename") {
            if ($validatedigest) {
                if (digest_file_hex("$fullfilename", "SHA-512") eq $md5) {
                    $skipit = 1;
                } else {
                    print "Warning: $fullfilename MD5 error, will download again.\n" if $verbose >= 1;
                }
            } else {
                if (-s "$fullfilename" == $size) {
                    $skipit = 1
                } else {
                    print "Warning: $fullfilename size error, will download again.\n" if $verbose >= 1;
                }
            }
        }

        print GETPACKAGE_IN "#" if $skipit; 
        print GETPACKAGE_IN "$source$path\n";
        my $dirname = $path;
        $dirname =~ s!/[^/]+$!!;
        $dirname = $target . $dirname;
        $dirname =~ y!\\!/!;
        print GETPACKAGE_IN "#" if $skipit; 
        print GETPACKAGE_IN " dir=$dirname\n";
    }
    close GETPACKAGE_IN;
    print GETPACKAGE <<ENDOFARIA2C;
$aria2c --conf-path=aria2c.conf --save-session=$getpackage_session -i$getpackage_in
ENDOFARIA2C
    close GETPACKAGE;

    if (! $skipdlpackage) {
        system "$getpackage";
        if (-s $getpackage_session) {
            print "There're some files unfinished. Please run\n";
            print "  $aria2c --conf-path=aria2c.conf -i$getpackage_session\n";
        }
    }
}

#sub downloadPackages_old()
#{
#    my $pathfilename;
#    my $fatal;
#    my $getpackage = "_get_package$legacy.cmd";
#    my $getpackage_in = "_get_package$legacy.in";
#    my $getpackage_session = "_get_package$legacy.session";
#    my $skipit;
#
#    open GETPACKAGE, ">$getpackage" or die "ERROR: Can't create $getpackage: $!\n";
#    if ($usearia2c) {
#        open GETPACKAGE_IN, ">$getpackage_in" or die "ERROR: Can't create $getpackage_in: $!\n";
#    } else {
#        print GETPACKAGE $useflashget ? $flashgetHead : $cuteftpHead;
#    }
#    while (my ($pkg, $md5) = each %packages) {
#        $pathfilename = $target . $pkg;
#        if ($skipexist && -e "$pathfilename") {
#            if (digest_file_hex("$pathfilename", "MD5") eq $md5) {
#                $skipit = 1;
#            } else {
#                print "Warning: $pathfilename MD5 error, will be deleted.\n" if $verbose >= 1;
#                unlink "$pathfilename";
#                $skipit = 0;
#            }
#        } else {
#            $skipit = 0;
#        }
#        if ($usearia2c) {
#            print GETPACKAGE_IN "#" if $skipit; 
#            print GETPACKAGE_IN "$source$pkg\n";
#            my $pathname = $pkg;
#            $pathname =~ s!/[^/]+$!!;
#            $pathname = $target . $pathname;
#            $pathname =~ y!\\!/!;
#            print GETPACKAGE_IN "#" if $skipit; 
#            print GETPACKAGE_IN " dir=$pathname\n";
#        } elsif ($useflashget) {
#            my $pathname = $pkg;
#            $pathname =~ s!/[^/]+$!!;
#            $pathname =~ y!/!\\!;
#            print GETPACKAGE "rem " if $skipit;
#            if (length($source . $pkg) + length($target . $pathname) > 253) {
#                print GETPACKAGE "ERROR: Too Long. ";
#                $fatal = 1;
#            }
#            print GETPACKAGE "\%flashget\% \"\%source\%$pkg\" \"\%saveto\%\\$pathname\"\n";
#        } else {
#            my $pathname = $pkg;
#            $pathname =~ y!/!\\!;
#            print GETPACKAGE "'" if $skipit;
#            print GETPACKAGE "s.DownloadAsync \"$pkg\", \"$pathname\"\n";
#        }
#    }
#    if ($usearia2c) {
#        close GETPACKAGE_IN;
#        print GETPACKAGE <<ENDOFARIA2C;
#$aria2c -s1 -j40 --auto-file-renaming=false --allow-overwrite=true --save-session=$getpackage_session -i$getpackage_in
#ENDOFARIA2C
#    } else {
#        print GETPACKAGE "Set s = Nothing\n" if !$useflashget;
#        close GETPACKAGE;
#    }
#    
#    die "ERROR: Can't complete the download. Path may be too long.\n" if $fatal;
#    if (!$skippackage) {
#        if ($usearia2c) {
#            system "$getpackage" if !$skippackage;
#            if (-s $getpackage_session) {
#                print "There're some files unfinished. Please run\n";
#                print "  $aria2c -j40 -i$getpackage_session\n";
#            }
#        } else {
#            system "$getpackage  >nul 2>&1"
#        }
#    }
#}

sub validatePackages()
{
    my $errorcnt;
    my @all_path;
    # check md5
    while (my ($name, $attr) = each %union_to_download_packages) {
        my $path = $$attr{"path"};
        my $md5 = $$attr{"md5"};
        my $size = $$attr{"size"};
        push @all_path, $path;
        
        my $fullfilename = $target . $path;
        if (! -e "$fullfilename") {
            print "ERROR: $fullfilename is NOT FOUND.\n";
            $errorcnt++;
        } elsif ($validatedigest) {
            if (digest_file_hex($fullfilename, "SHA-512") eq $md5) {
                print "$path: MD5 OK.\n" if $verbose >= 2;
            } else {
                print "ERROR MD5: $fullfilename\n";
                $errorcnt++;
            }
        } else {
            if (-s "$fullfilename" == $size) {
                print "$path: size OK.\n" if $verbose >= 2;
            } else {
                print "ERROR SIZE: $fullfilename\n";
                $errorcnt++;
            }
        }
    }
    # check orhpan files
    my @setupfiles = ("setup-x86.exe", "setup-x86.exe.sig", "x86/setup.bz2", "x86/setup.bz2.sig", "x86/setup.ini", "x86/setup.ini.sig", "x86/setup.xz", "x86/setup.xz.sig");
    push @all_path, @setupfiles;
    s/x86/x86_64/ foreach @setupfiles;
    push @all_path, @setupfiles;
    if (1) {
        my $dir = $target;
        $dir =~ y!\\!/!;
        finddepth( sub {
                if (-d) {
                    my $num = () = <$_/* $_/.*>;
                    if ($num == 2) {
                        if ($deleteorphans) {
                            print "Warning: Empty directory $File::Find::name will be deleted.\n";
                            rmdir;
                        } else {
                            print "Warning: Empty directory $File::Find::name found.\n";
                        }
                    }
                    return;
                }
                my $name  = $File::Find::name;
                $name =~ s/^\Q$dir//;
                if (! ($name ~~ @all_path)) {
                    if ($deleteorphans) {
                        print "Warning: Unused file $File::Find::name will be deleted.\n";
                        unlink;
                    } else {
                        print "Warning: Unused file $File::Find::name found.\n";
                    }
                }
            }, "$dir");
    }

    if ($errorcnt) {
        print "\nThere're $errorcnt error detected when validate the package list.\nPlease check the log.\n";
    } else {
        print "\nAll packages are correct.\n";
    }
    return $errorcnt;
}

#sub validateCygwin_old()
#{
#    my $errorcnt;
#    
#    foreach ("ini", "bz2", "exe") {
#        my $a = `gpgv --keyring .\\cygwin.gpg ${target}$setup.$_.sig 2>&1`;
#        if ($?) {
#            print "ERROR: ${target}$setup.$_ signature check failed.\n$a\n";
#            $errorcnt++;
#        }
#    }
#
#    if ($deleteorphans) {
#        finddepth( sub {
#                if (-d) {
#                    my $num = () = <$_/* $_/.*>;
#                    if ($num == 2) {
#                        print "Warning: Empty directory $File::Find::name will be deleted.\n" if $verbose >= 1;
#                        rmdir;
#                    }
#                    return;
#                }
#                my $name  = $File::Find::name;
#                $name =~ s/^\Q$target//;
#                $name =~ y!\\!/!;
#                if (! exists $packages{$name}) {
#                    print "Warning: Unused file $File::Find::name will be deleted.\n" if $verbose >= 1;
#                    unlink;
#                }
#            }, "${target}release$legacy");
#    }
#
#    while (my ($pkg, $md5) = each %packages) {
#        if (! -e "$target$pkg") {
#            print "ERROR: $target$pkg is NOT FOUND.\n";
#            $errorcnt++;
#        #} elsif (digest_file_hex($target . $pkg, "MD5") eq $md5) {
#        } elsif (digest_file_hex($target . $pkg, "SHA-512") eq $md5) {
#            #print "$1: $2 OK.\n";
#        } else {
#            print "ERROR MD5: $target$pkg\n";
#            $errorcnt++;
#        }
#    }
#
#    if ($errorcnt) {
#        print STDERR "\nThere're $errorcnt error detected when validate the package list.\nPlease check the log.\n";
#    } else {
#        print STDERR "\nAll packages are correct.\n";
#    }
#    return $errorcnt;
#}


sub main()
{
    parseOptions;
    processCustomPackage;
    if ($validate) {
        validateSetup;
        if (! $skippackage) {
            genPackageList;
            validatePackages;
        }
    } elsif ($showpackageinfo) {
        validateSetup;
        genPackageList;
        printPackageInfo;
    }else {
        downloadSetup if ! $skipsetup;
        validateSetup;
        if (! $skippackage) {
            genPackageList;
            downloadPackages;
        }
    }
}
main;

