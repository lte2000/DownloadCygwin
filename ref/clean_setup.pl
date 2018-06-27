#! /usr/bin/perl -w

require 5.005;

# Delete old files from Cygwin setup.exe archive subdirectories

# Name of file:  cleanup_setup.pl
#
# Type of file:  Perl script
#
# Author:        Michael A. Chase <mchase@ix.netcom.com>
#
# Purpose:       Clean out setup.exe archive subdirectories.

=head1 NAME

clean_setup.pl - Cleanup Cygwin setup.exe local directory tree

=head1 SYNOPSIS

    clean_setup.pl [opt]

=head1 DESCRIPTION

Parse setup.ini files in the local directory tree and use the newest one
containing each particular package to determine which files are listed.
If requested, delete unlisted files and move active files out of the mirror
site subdirectory trees to the base directory tree.

=head1 SYNTAX

=head2 Options

Most options may be shortened to their first one or two letters.

Flag options may be turned off by prefixing them with 'no'
(e.g., -noDDir for -DDir).

=item -help

List options.
The current state of each option is shown in parenthesis.

=item -[no]DDir

Delete empty directories.

=item -[no]DFile

Delete unlisted files.

=item -[no]DSetup

Delete unused setup.ini files.

To avoid deleting active setup.ini files, a setup.ini will not
be deleted if it was the newest source of information for any packages.
Note that only one setup.ini of a given age and coverage will be used.

=item -[no]CSetup

Copy the most used setup.ini file to the base directory.

=item -[no]MFile

Move files to the base directory tree.

If the same file exists in multiple locations, a complaint is issued and
none will be moved to the base directory tree.

Files must be the correct length according to the latest setup.ini to be
moved.

=item -[no]prevobsolete

Treat [prev] files as unlisted (i.e. Delete or Archive them if -DFile or
-archive is used).
Option -prev has no effect if this option is active.
The option may be abbreviated as -prevobs or -po.

=item -[no]keepold

Keep old files that are listed in old setup.ini files if no newer version was
found.
The option may be abbreviated as -ko.

=item -[no]curr

Report missing [curr] files.

=item -[no]prev

Report missing [prev] files.

=item -[no]test

Report missing [test] files.

=item -[no]install

Report missing install archives.

=item -[no]source

Report missing source archives.

=item -base dir

Local files base directory is 'dir'.
By default, this is the current directory.

=item -archive dir

Move unlisted files to 'dir' preserving subdirectory structure.
If not absolute, it is relative to the local files base directory.
If 'dir' is not empty, it overrides -DFile.
By default, 'dir' is empty.

=item -missing file

Write list of missing files to 'file'.
If there are no missing files, remove 'file'.
The file names are the same as given in setup.ini.

=item -missingprefix prefix

Prepend 'prefix' to filenames in list of missing files saved for -missing.
The prefix may be anything including commands with their own options.
The option may be abbreviated as -mp.

=item -H mask

Ignore packages that match filename wildcard mask 'mask'.

=item -I mask

Ignore files and directories that match filename wildcard mask 'mask'.

=item -option file

Read additional options from 'file' in ., base directory, or program directory.
The options in 'file' are interpreted as if they replaced '-o file' in the
command line.
There may be more than one -option option in a command line or options file.
Blank lines and comments starting with '#' or ';' are ignored.
All lines after a line containing "__END__" are also ignored.

=head1 EXAMPLES

   # List only, ignore XFree and apache packages
   clean_setup.pl -H "XFree*" -H "apache*" -H "mod_*"

   # Delete unlisted files and empty directories
   clean_setup.pl -DDir -DFile -DSetup

   # Include options from .clean_setup and archive.opt
   clean_setup.pl -o .clean_setup -o archive.opt

=head1 AUTHOR

Michael A. Chase <mchase@ix.netcom.com>

=cut
# Syntax:        See $HelpText Below
#--------------------------  MODIFICATION HISTORY -----------------------------
$VERSION = '1.0700';
# 030702 M. Chase       Add ability to keep packages and versions listed in
#                          old setup.ini files.
#                          Suggested by a patch from David Kilroy.
#                       Folded %aInstall and %aSource into single hash.
# $VERSION = '1.0600';
# 030202 M. Chase       Remove missing files list file if no missing files.
#                          Suggested by a patch from Max Bowsher.
#                       Merge setup.ini information instead of using only one.
#                       Add my_gmtime() and use it for setup.ini times.
# $VERSION = '1.0502';
# 030103 M. Chase       Change setup parse results to hash so binary only or
#                          source only mirrors are handled correctly.
#                          Suggested by a patch from Jason Tishler.
# $VERSION = '1.0501';
# 020806 M. Chase       Add -prevobsolete based on patch from Max Bowsher.
# $VERSION = '1.0500';
# 020806 M. Chase       Add -archive, -missingprefix.
#                       Report missing source and binary files separately with
#                          byte counts.
#                       Suggested by Max Bowsher.
#                       Add -option.
# $VERSION = '1.0402';
# 020524 M. Chase       Add -CSetup.  Some setup.exe's choke on ./setup.ini.
#                       Remove -exp.
#                       Add POD.
# $VERSION = '1.0401';
# 020430 M. Chase       Add -missing.  Suggested by V. Quetschke.
# $VERSION = '1.0400';
# 020427 M. Chase       Rename options and split file and directory delete.
#                       Get default base directory from /etc/setup/last-cache.
# $VERSION = '1.0302';
# 020423 M. Chase       Add -source, -install, -H options.
#                       Removed directory names from Missing Files list.
# $VERSION = '1.0301';
# 020417 M. Chase       Stop lc()ing file names during setup.ini parsing.
# $VERSION = '1.0300';
# 020416 M. Chase       Ignore setup.ini while collecting archive file names.
#                       Remove directories in reverse length order.
# $VERSION = '1.0202';
# 020416 M. Chase       Properly ignore directories in obsolete file search.
# $VERSION = '1.0201';
# 020404 M. Chase       Ignore files found more than once in move loop.
#                       Protect against attempts to move files from different
#                          trees over each other in the base tree.
# $VERSION = '1.0200';
# 020326 M. Chase       Properly handle directory case.
#                       Optionally move archives to base directory tree.
# $VERSION = '1.0100';
# 020212 M. Chase       Handle multiple setup.ini files and file sources.
# $VERSION = '1.0000';
# 010422 M. Chase       First draft.

use FindBin qw( $RealBin $RealScript );
use File::Basename qw( &basename &dirname &fileparse );
use File::Find;
use File::Spec;
use File::Path qw( &mkpath );
use File::Copy qw( &copy &move );
use Getopt::Long;
use Text::ParseWords qw( shellwords );

use strict;
use integer;
use vars qw( $VERSION );
use vars qw( %hPkg );
local %hPkg;

# Initialize options
my $bDDir     = 0;
my $bDFile    = 0;
my $bDSetup   = 0;
my $bCSetup   = 0;
my $bMFile    = 0;
my $bPrevObs  = 0;
my $bKeepOld  = 0;
my $bCurr     = 1;
my $bPrev     = 1;
my $bTest     = 1;
my %bList     = qw( bin 1 src 0 );
my $sMissList = "";
my $sMissPfx  = "";
my @sHide     = ();
my @sIgnore   = ();
my $sDir0     = fwd_slash( File::Spec -> rel2abs( "." ) );
my $sArchive  = "";

# Get default setup local files directory from /etc/setup/last-cache
# This only works if using a Cygwin aware Perl.
if ( -r "/etc/setup/last-cache" ) {
   if ( ! open( LAST, "< /etc/setup/last-cache" ) ) {
      print "Can't open /etc/setup/last-cache, $!\n";
   }
   else {
      $_ = <LAST>;
      close LAST;
      s,\s+$,,;
      $sDir0 = fwd_slash( $_ ) if length $_;
   }
}

# Syntax description
sub usage {
   my ( $sOpt, $sVal, @sMsg ) = @_;

   chdir $sDir0 or print "Can't use $sDir0 as base directory, $!\n";
   $sDir0 = fwd_slash( File::Spec -> rel2abs( "." ) );

   my $sHelpText = <<END_HELP_TEXT;
Cleanup Cygwin setup.exe local directories
syntax: $RealScript [opt]
Opt: ($VERSION)
   -option file  = Read options from file
   -[no]DDir     = [Don't] Delete directories ($bDDir)
   -[no]DFile    = [Don't] Delete files not in setup.ini ($bDFile)
   -[no]DSetup   = [Don't] Delete unused setup.ini files ($bDSetup)
   -[no]CSetup   = [Don't] Copy latest setup.ini file to base directory ($bCSetup)
   -[no]MFile    = [Don't] Move files to base directory tree ($bMFile)
   -[no]prevobs  = [Don't] Treat [prev] files as unlisted ($bPrevObs)
   -[no]keepold  = [Don't] Keep files listed in old setup.ini if none newer ($bKeepOld)
   -[no]curr     = [Don't] Report missing [curr] files ($bCurr)
   -[no]prev     = [Don't] Report missing [prev] files ($bPrev)
   -[no]test     = [Don't] Report missing [test] files ($bTest)
   -[no]install  = [Don't] Report missing install archives ($bList{bin})
   -[no]source   = [Don't] Report missing source archives ($bList{src})
   -base dir     = Local files base directory ($sDir0)
   -archive dir  = Move unlisted files to directory ($sArchive)
   -missing file = Write list of missing files to file ($sMissList)
   -mp prefix    = Prepend prefix to lines written to -missing file ($sMissPfx)
   -H mask       = Ignore packages that match mask, multiple allowed
   -I mask       = Ignore files and directories that match mask, multiple allowed
      mask is a filename wildcard mask, not a regular expression
Arg: None
Doc: perldoc $RealScript
END_HELP_TEXT
# Balance quotes in here document # ' # "

   my $nRet = 'help' eq $sOpt ? 0 : 0 + $sVal;
   select STDERR if $nRet;
   foreach ( @sMsg, $sHelpText ) { s/\s+$//; print "$_\n"; }
   exit $nRet;
}

# Parse command line
my @aOptions = (
   'DDir|DD!'                 => \$bDDir,
   'DFile|DF!'                => \$bDFile,
   'DSetup|DS!'               => \$bDSetup,
   'CSetup|CS!'               => \$bCSetup,
   'MFile|MF!'                => \$bMFile,
   'prevobsolete|prevobs|po!' => \$bPrevObs,
   'keepold|ko!'              => \$bKeepOld,
   'curr|c!'                  => \$bCurr,
   'prev|p!'                  => \$bPrev,
   'test|t!'                  => \$bTest,
   'install|i!'               => \($bList{"bin"}),
   'source|s!'                => \($bList{"src"}),
   'base|b=s'                 => \$sDir0,
   'archive|a=s'              => \$sArchive,
   'missing|m=s'              => \$sMissList,
   'missingprefix|mp=s'       => \$sMissPfx,
   'Hide|H=s@'                => \@sHide,
   'Ignore|I=s@'              => \@sIgnore,
   'option|opt|o=s'           => \&opt_file,
);
Getopt::Long::config( qw( no_ignore_case no_auto_abbrev require_order ) );
GetOptions(
   @aOptions,
   'help|h' => \&usage ) or usage( 'die', 1 );

# Finalize related options
chdir $sDir0 or usage( 'die', 1, "Can't change directory to $sDir0, $!\n" );
$sDir0 = fwd_slash( File::Spec -> rel2abs( "." ) );
if ( $sArchive ) {
   $bDFile   = 0;
   $sArchive = fwd_slash( File::Spec -> rel2abs( $sArchive, $sDir0 ) );
}

# Report arguments
my $sOpt = '';
$sOpt .= "\nDeleting empty directores"                   if $bDDir;
$sOpt .= "\nDeleting files not in setup.ini"             if $bDFile;
$sOpt .= "\nDeleting obsolete setup.ini files"           if $bDSetup;
$sOpt .= "\nCopying latest setup.ini to base directory"  if $bCSetup;
$sOpt .= "\nMoving archives to base directory tree"      if $bMFile;
$sOpt .= "\nRegarding [prev] files as unlisted"          if $bPrevObs;
$sOpt .= "\nKeeping files listed in old setup.ini if none newer"       if $bKeepOld;
$sOpt .= "\nWriting list of missing files to $sMissList" if $sMissList;
$sOpt .= "\nMissing file prefix is $sMissPfx"            if $sMissPfx;
$sOpt .= "\nMoving unlisted files to $sArchive"          if $sArchive;
$sOpt .= "\nIgnoring files and directories: " . join ' ',  map { "'$_'" }
   @sIgnore if @sIgnore;
$sOpt .= "\nIgnoring packages: "   . join ' ',  map { "'$_'" } @sHide if @sHide;
print <<HERE;
Base Directory: $sDir0$sOpt
HERE

# Build file or directory name matcher
#    Adapted from Recipe 6.10 in Perl Cookbook
sub rfMatch {
   my ( $bDefault, $op, @sMask ) = @_; # @sMask must be a lexical array
   return sub { return $bDefault; } if 3 > @_;
   my $sExpr = join " $op\n",
      map {
         # Convert file expansion mask to regular expression
         $sMask[$_] =~ s/\./\\./g;
         $sMask[$_] =~ s/\?/.?/g;
         $sMask[$_] =~ s/\*/.*/g;
         "m:^\$sMask[$_]\$:oi";
         } 0 .. $#sMask;
   my $rfMatch = eval "sub { local \$_ = shift;\nreturn $sExpr; };";
   die $@ if $@;
   return $rfMatch;
}
local *bHide   = rfMatch( 0, '||', @sHide );
local *bIgnore = rfMatch( 0, '||', @sIgnore );

# Find and parse setup.ini files, collect other filenames at the same time
my ( %aSetup, $sRel, $sPkg, $sName, %sTarBall, %bDir, %nPkg );
my ( %hKnownFiles, %hSetupForPackage );
my $wanted = sub {
   # Skip ., .., and files and directories in ignore list
   if ( '.' eq $_ || '..' eq $_ ) {
      $File::Find::prune = 1 if '..' eq $_;
      return;
   }
   if ( $sArchive && $sArchive eq fwd_slash( $File::Find::name ) ) {
      $File::Find::prune = 1;          # Prune if archive directory
      return;
   }
   if ( bIgnore( $_ ) ) {
      $File::Find::prune = 1 if -d $_; # Prune if a directory
      return;
   }

   # Handle directory or file
   $sRel = sRel( $File::Find::dir, $sDir0 );
   if ( -d $_ ) { $bDir{sRel( $File::Find::name, $sDir0 )} = 1; }
      # Remember directory name for possible removal
   elsif ( "setup.ini" eq $_ ) {
      # Parse setup.ini
      my %hSetup;
      $hSetup{'ftime'} = (stat( $_ ))[9];

      # Get list of files to leave alone, includes subdirectory path
      # setup-timestamp: 1012849221
      # install: latest/bash/bash-2.05-1.tar.gz 576828
      # source:  latest/bash/bash-2.05-1-src.tar.gz 1792319
      my ( $bHide, $sGroup, $sType, $sKind );
      my ( $sFile, $sSize, $sVol, $sSubDir, $sName );
      $sPkg = $bHide = $sGroup = $sKind = '';
      my $sSetup = $File::Find::name;
      open( SETUP, $sSetup ) or usage( 'die', 1, "Can't open $sSetup, $!" );
      while ( <SETUP> ) {
         ( $sType, $sFile, $sSize )  = split /\s+/, $_;
         $sKind = "";
         if    ( 'setup-timestamp:' eq $sType ) { $hSetup{"time"} = $sFile; }
                                                  # Actually timestamp
         elsif ( s/^@\s+// ) {
            s/\s+$//;
            $sPkg   = $_;
            $bHide  = bHide( $_ );
            $sGroup = '[curr]';
         }
         elsif ( $bHide )                           { next; } # Hidden package
         elsif ( '[' eq substr( $_, 0, 1 ) ) { s/\s+$//; $sGroup = $_; } # ]
         elsif ( $bPrevObs && '[prev]' eq $sGroup ) {}  # Ignore [prev] entries
         elsif ( 'install:' eq $sType )             { $sKind = "bin"; }
         elsif ( 'source:'  eq $sType )             { $sKind = "src"; }

         if ( $sKind ) {
            ( $sVol, $sSubDir, $sName ) = File::Spec -> splitpath( $sFile );
            $sSubDir         = fwd_slash( File::Spec -> canonpath( $sSubDir ) );
            $hKnownFiles{$sName}    = [ $sRel, $sPkg, $sKind, $sGroup, $sSize ];
            $hSetup{$sKind}{$sPkg}{$sGroup} = [ $sSize, $sSubDir, $sName ];
            ++$nPkg{$sPkg};
            $sKind = "";
         }
      }
      close SETUP;
      usage( 'die', 1, "Nothing found in $sSetup" )
         if ! exists $hSetup{"time"} ||
            ! exists $hSetup{"bin"} && ! exists $hSetup{"src"};
      $aSetup{$sRel} = \%hSetup;
   }
   elsif ( ".tar.bz2" eq substr( $_, -8 ) || ".tar.gz" eq substr( $_, -7 ) ) {
      # Save name of archive file
      $sTarBall{$_}{fwd_slash( File::Spec -> canonpath( $sRel ) )} = -s $_;
   }
   # Currently ignoring other types of files
};
find( $wanted, $sDir0 );
usage( "die", 1, "No setup.ini files found" ) if ! %aSetup;

# Choose latest information for each package and note obsolete setup.ini files
my ( %aFile, %nNewest, $tNewest, $sNewest, $sKind, @sOldSetup );
my @sAllSetup = sort keys %aSetup;
my @sPkg      = sort keys %nPkg;

# Choose latest setup.ini separately for each binary and source package
foreach $sPkg ( @sPkg ) {
   $sNewest = "";
   $tNewest = 0;
   foreach ( @sAllSetup ) {
      next if $tNewest >= $aSetup{$_}{"time"};
      if  ( exists $aSetup{$_}{"bin"}{$sPkg} ||
            exists $aSetup{$_}{"src"}{$sPkg} ) {
         $tNewest = $aSetup{$_}{"time"};
         $sNewest = $_;
      }
   }
   if ( length $sNewest ) {
      foreach $sKind ( qw( bin src ) ) {
         if ( exists $aSetup{$sNewest}{$sKind} &&
              exists $aSetup{$sNewest}{$sKind}{$sPkg} ) {
            *hPkg = $aSetup{$sNewest}{$sKind}{$sPkg};
            foreach ( sort keys %hPkg ) {
               $aFile{$sKind}{$hPkg{$_}[2]}     = [ $_, @{$hPkg{$_}}[0..1] ];
               $hSetupForPackage{$sPkg}{$sKind} = $sNewest;
            }
         }
      }
      ++$nNewest{$sNewest};
   }
}

# Check found files against those listed in latest setup.ini
my ( @sDir, $sDir, $sFile, @sDup, %sMove, @sUnlisted, @sWrongSize );
NAME_LOOP:
foreach $sName ( sort keys %sTarBall ) {
   @sDir  = sort keys %{$sTarBall{$sName}};
   $sDir  = $sDir[0];
   $sFile = fwd_slash( File::Spec -> catfile( $sDir, $sName ) );
   if    ( 1 < @sDir ) {
      # More than one copy of a file was found
      push @sDup, "$sName: " . join( ", ", map { sUnPercent( $_ ) } @sDir );
      next;
   }
   foreach $sKind ( qw( bin src ) ) {
      if ( exists $aFile{$sKind}{$sName}  ) {
         if    ( $sDir eq $aFile{$sKind}{$sName}[2] ) {} # Already in right place
         elsif ( $sTarBall{$sName}{$sDir} != $aFile{$sKind}{$sName}[1] ) {
            # Wrong size
            push @sWrongSize,
               "$sFile: $sTarBall{$sName}{$sDir} != $aFile{$sKind}{$sName}[1]" .
               " in " . sUnPercent( $sDir );
         }
         else {
            $sMove{$sFile} =fwd_slash(
               File::Spec -> catfile( $aFile{$sKind}{$sName}[2], $sName ) );
         }
         next NAME_LOOP;
      }
   }

   # Not found, check in old setup.ini files
   my $bKeep = 0;
   my ( $sSetup, $sPkg, $sGroup, $sSize );
   if ( $bKeepOld && exists $hKnownFiles{$sName} ) {
      ( $sSetup, $sPkg, $sKind, $sGroup, $sSize ) = @{$hKnownFiles{$sName}};
    # print "$sFile is referenced by $sSetup as part of $sPkg\n";

      # Did we find an active source or binary file for that package?
      $bKeep = 1;
      foreach $sKind ( qw( bin src ) ) {
         if ( exists $hSetupForPackage{$sPkg}{$sKind} ) {
            *hPkg = $aSetup{$hSetupForPackage{$sPkg}{$sKind}}{$sKind}{$sPkg};
            foreach $sGroup ( sort keys %hPkg ) {
               $bKeep = 0, next if exists $sTarBall{$hPkg{$sGroup}[2]};
            }
         }
      }
   }

   if ( $bKeep ) {
      # Report keeping file and keep setup.ini
      print "Keeping $sFile: latest is not found.\n";
      ++$nNewest{$sSetup};
      if ( exists $aSetup{$sSetup}{$sKind}{$sPkg} ) {
         $aFile{$sKind}{$sName} = [ $sGroup,
            @{$aSetup{$sSetup}{$sKind}{$sPkg}{$sGroup}}[0, 1] ];
         redo;
      }
   }
   else {
      # File not in any setup.ini
      push @sUnlisted, $sFile;
   }
}

# Identify used and unused setup.ini files
print "Used setup.ini files:\n";
foreach ( @sAllSetup ) {
   if ( ! exists $nNewest{$_} ) { push @sOldSetup, $_; }
   else {
      printf "  %4d %-19s %s\n", $nNewest{$_},
         my_gmtime( $aSetup{$_}{"time"} ), sUnPercent( sRel( $_ ) );
   }
}
print "Unused setup.ini files:\n" if @sOldSetup;
foreach ( @sOldSetup ) {
   printf "  %4s %-19s %s\n", "",
      my_gmtime( $aSetup{$_}{"time"} ), sUnPercent( sRel( $_ ) );
   unlink "$_/setup.ini" or print "      *** Can't remove, $!" if $bDSetup;
}

# Check for missing files
my ( @sMissingBin, @sMissingSrc, $raMissing ) = ();
my %nBytes = qw( bin 0 src 0 );
foreach $sKind ( qw( bin src ) ) {
   if ( $bList{$sKind} ) {
      $raMissing = "bin" eq $sKind ? \@sMissingBin : \@sMissingSrc;
      foreach ( keys %{$aFile{$sKind}} ) {
         if ( ! exists $sTarBall{$_} &&
               ( $bCurr || '[curr]' ne $aFile{$sKind}{$_}[0] ) &&
               ( $bPrev || '[prev]' ne $aFile{$sKind}{$_}[0] ) &&
               ( $bTest || '[test]' ne $aFile{$sKind}{$_}[0] ) ) {
            $nBytes{$sKind} += $aFile{$sKind}{$_}[1];
            push @$raMissing, [ @{$aFile{$sKind}{$_}}[0, 1, 2], $_,
                  format_bytes( $aFile{$sKind}{$_}[1] ) ];
         }
      }
      @$raMissing =
         sort { $$a[0] cmp $$b[0] || $$a[2] cmp $$b[2] || $$a[1] <=> $$b[1] }
         @$raMissing;
   }
}

# Complain about errors
print join( "\n   ", "\nDuplicate Files",  @sDup ),       "\n" if @sDup;
print join( "\n   ", "\nWrong Size Files", @sWrongSize ), "\n" if @sWrongSize;

# Report missing files
print join( "\n   ", "\nMissing Install Files: " .
   format_bytes( $nBytes{"bin"} ) . ", " . scalar @sMissingBin . " files",
   map { join " ", @$_[0, 4, 3] } @sMissingBin ), "\n" if @sMissingBin;
print join( "\n   ", "\nMissing Source Files: "  .
   format_bytes( $nBytes{"src"} ) . ", " . scalar @sMissingSrc . " files",
   map { join " ", @$_[0, 4, 3] } @sMissingSrc ), "\n" if @sMissingSrc;
if ( $sMissList ) {
   if ( @sMissingBin || @sMissingSrc ) {
      if ( ! open( OUT, "> $sMissList" ) ) {
         print "*** Can't write to $sMissList, $!";
      }
      else {
         foreach ( @sMissingBin, @sMissingSrc ) {
            print OUT $sMissPfx,
               fwd_slash( File::Spec -> catfile( @$_[2, 3] ) ), "\n";
         }
         close OUT;
      }
   }
   elsif ( -f $sMissList ) {
      unlink( "$sMissList" ) or print "*** Can't unlink $sMissList, $!";
   }
}

# Move queued files to base directory tree
if ( %sMove ) {
   print $bMFile ? "\n" : "\nNot ", "Moving files to base directory tree\n";
   my ( $sFrom, $sTo );
   foreach $sFrom ( sort keys %sMove ) {
      $sTo  = $sMove{$sFrom};
      $sDir = dirname( $sTo );
      print sUnPercent( "   $sFrom -> $sDir\n" );
      if ( -e $sTo ) { print "      *** Target already exists\n"; }
      elsif ( $bMFile ) {
         mkpath( $sDir ) if ! -d $sDir;
         move( $sFrom, $sTo ) or print "      *** Can't move, $!\n";
      }
   }
}

# Move or remove files not listed in any setup.ini
if ( @sUnlisted ) {
   my ( $sWhat, $sFrom, $sTo, $sFile );
   if    ( $sArchive ) { $sWhat =       "Moving"; }
   elsif ( $bDFile )   { $sWhat =     "Removing"; }
   else                { $sWhat = "Not removing"; }
   print "\n$sWhat files not in setup.ini\n";
   foreach $sFrom ( @sUnlisted ) {
      print sUnPercent( "   $sFrom\n" );
      if    ( $sArchive ) {
         $sFile = $sFrom;
         foreach $sDir ( @sAllSetup ) {
            last if $sFile =~ s,^$sDir/,,;
         }
         $sTo   = fwd_slash( File::Spec -> catdir( $sArchive, $sFile ) );
         $sDir  = dirname( $sTo );
         mkpath( $sDir ) if ! -d $sDir;
         move( $sFrom, $sTo ) or print "      *** Can't move, $!\n";
      }
      elsif ( $bDFile ) {
         unlink( $sFrom )     or print "      *** Can't remove, $!\n";
      }
   }
}

# Remove empty directories
my ( @g, $bFound );
foreach $sRel ( sort { length $b <=> length $a || $a cmp $b } keys %bDir ) {
   @g = glob( File::Spec -> catfile( $sRel, "*" ) );
   if ( ! @g ) {
      print $bDDir ? "\n" : "\nNot ", "Removing Empty Directories\n"
         if ! $bFound++;
      print sUnPercent( "   $sRel\n" );
      if ( $bDDir ) {
         rmdir $sRel or print "      *** Can't rmdir, $!\n";
      }
   }
}

# Copy latest setup.ini to base directory
if ( $bCSetup && "." ne $sNewest ) {
   print sUnPercent( "\nCopying setup.ini from $sNewest to $sDir0\n" );
   copy( "$sNewest/setup.ini", "$sDir0/setup.ini" )
      or print "   *** Can't copy setup.ini, $!\n";
}

exit 0;

# Convert backslashes (\) to normal slashes (/)
sub fwd_slash {
   local ( $_ ) = @_;
   s,\\,/,g;
   return $_;
}

# Produce relative file or directory
sub sRel {
   my ( $sAbs, $sBase ) = @_;
   $sBase = "." if ! defined $sBase || ! length $sBase;
   my $sRel = fwd_slash( File::Spec -> abs2rel( $sAbs, $sBase ) );
   $sRel =~ s/^\w://;
   $sRel =  "." if ! length $sRel;
   return $sRel;
}

# Convert %xx to characters
sub sUnPercent {
   local ( $_ ) = @_;

   s/\%([0-9a-f]{2})/chr(hex($1))/gie;
   return $_;
}

# *** Human readable bytes ***
# Adapted from Max Bowsher.
sub format_bytes {
   my $nBytes = shift;
   my @sSuffixes = ( 'B', 'k', 'M', 'G', 'T' );
   no integer;
   while ( $sSuffixes[1] and $nBytes >= 1024.0 ) {
      shift @sSuffixes;
      $nBytes = $nBytes / 1024.0;
   }
   return sprintf( "%6.1f", $nBytes ) . $sSuffixes[0];
}

# Write GMT time as YYYY-MM-DD HH24:MI:SS
sub my_gmtime {
   my ( $t ) = @_;
   my @Now = gmtime( $t || time );
   $Now[5] += 1900; ++$Now[4];
   return sprintf( "%04d-%02d-%02d %02d:%02d:%02d", @Now[5, 4, 3, 2, 1, 0] );
}

# Process options file
# Note: die() is trapped by GetOpt::Long and $@ is treated as an error message
use vars qw( $nDepth );
sub opt_file {
   my ( $sOpt, $sOptFile ) = @_;
   local $nDepth = $nDepth || 0;
   my $sDepth = 1 < ++$nDepth ? "$sOptFile($nDepth)" : $sOptFile;

   # Look for file
   if    ( -r $sOptFile ) {}
   elsif ( -r File::Spec -> rel2abs( $sOptFile, $sDir0 ) ) {
      $sOptFile = File::Spec -> rel2abs( $sOptFile, $sDir0 );
   }
   elsif ( -r File::Spec -> rel2abs( $sOptFile, $RealBin ) ) {
      $sOptFile = File::Spec -> rel2abs( $sOptFile, $RealBin );
   }
   else {
      die "$sDepth: Can't find options file in ., $sDir0, or $RealBin\n";
   }

   # Process option lines
   open( OPT, $sOptFile ) or die "$sDepth: Can't open $sOptFile, $!\n";
   local $_;
   while ( <OPT> ) {
      s/^\s+//; s/\s+$//;
      s/^[;#].*$// || s/\s+[;#].*$//; # Strip comments from end of line
      next if ! length $_;            # Skip empty lines
      last if "__END__" eq $_;

      # Parse options
      local @ARGV = shellwords( $_ );
      GetOptions( @aOptions ) or die "$sDepth: Invalid options\n";
      die join( " ", "$sDepth: Unhandled options:", @ARGV ) . "\n" if @ARGV;
   }
   close OPT;
}
