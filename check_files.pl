#!/usr/bin/perl
#
# ============================== SUMMARY =====================================
#
# Program  : check_files.pl
# Version  : 0.416
# Date     : May 05, 2013
# Author   : William Leibzon - william@leibzon.org
# Summary  : This is a nagios plugin that counts files in a directory and
#            checks their age an size. Various thresholds on this can be set.
# Licence  : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# =========================== PROGRAM LICENSE ================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GnU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ===================== INFORMATION ABOUT THIS PLUGIN ========================
#
# This is a nagios plugin that checks number of files of specified type
# in a directory and can give an error if there are too few or too few.
# It can also check files age, file size and set thresholds based on these
# parameters such as report an error if files are too old.
#
# This program is written and maintained by:
#   William Leibzon - william(at)leibzon.org
#
# =============================== SETUP NOTES ================================
#
# List of files to check are specified with -F option. These should be
# specified in a way you'd specify files for ls, so for example to check
# all perl files you use "*.pl" which is specified as:
#    $ ./check_files.pl -L Files -F '*.pl' -w 4 -c 7
# (above will give a warning if there are > 4 *.pl files and critical alert if > 7)
#
# You can specify more than one file type to check, for example:
#    $ ./check_files.pl -L Files -F '*.pl,*.sh' -w 4,3 -c 7,5
# (above will give a warning if there are more than 4 .pl or more than 3 *.sh files
#  and CRITICAL alert if there are more than 7 .pl or more than 5 *.sh files)
#
# And these are examples provided by Patrick Bailat for options he added:
#  Compute the sum size of files:
#    $ ./check_files.pl -D /opt/oradata -F "t" -f -S -H "10.0.0.1"
#    OK - Sum of file sizes is 3897 octet, 2 t files found | 't'=2 size_sum=3897o
#  Search largest file:
#    $ ./check_files.pl -D /opt/oradata -F "t" -f -s -H "10.0.0.1"
#    OK - Largest size file is 3896 octet, 2 t files found | 't'=2 size_largest=3896o size_smallest=1o
#
# About Threhold Format:
#
#   Warning and critical levels are specified with '-w' and '-c' and each one
#   must have exactly same number of values (separated by ',') as number of
#   file type checks specified with '-F'. Any values you dont want
#   to compare you specify as ~. There are also number of other one-letter
#   modifiers that can be used before actual data value to direct how data is
#   to be checked. These are as follows:
#      > : issue alert if data is above this value (default)
#      < : issue alert if data is below this value
#      = : issue alert if data is equal to this value
#      ! : issue alert if data is NOT equal to this value
#
#   Supported are also two specifications of range formats:
#     number1:number2   issue alert if data is OUTSIDE of range [number1..number2]
#                 i.e. alert if data<$number1 or data>$number2
#     @number1:number2  issue alert if data is WITHIN range [number1..number2]
#                 i.e. alert if data>=$number and $data<=$number2
#
#   A special modifier '^' can also be used to disable checking that warn values
#   are less than (or greater than) critical values (it is rarely needed).
#
# Additional Options:
#
#   You can check file age with '--age' option which allows to set threshold
#   if any file (in any of the file specs given with -F) is older than specified
#   number of seconds. The option either takes one number separated by ',' for
#   WARNING and CRITICAL alerts. If you want only CRITICAL specify WARNING as ~.
#   For example -a '~,60' would give CRITICAL alert if any file is older than minute
#
#   Just '-a' will show how old found files are which was the behavior prior to 0.36
#   version even if -a was not given as an option.
#
#   You can also check file size with '--size' option which allows to set threshold
#   if any file (in any of the file specs given with -F) is larger than specified
#   number of octets (bytes). The option either takes one number separated by ','
#   for WARNING and CRITICAL alerts. If you want only CRITICAL specify WARNING as ~.
#   For example -s '~,60' would give CRITICAL alert if any file is larger than 60
#   octets (bytes)
#
#   If you want performance output then use '-f' option. The plugin will then
#   output number of files of each type and age of oldest and newest files.
#
# Execution Options:
#
#   This plugin checks list of files by executing 'ls' on a local system where
#   it is run. It can also execute ls on a remote system or process the output
#   from ls command executed through some other plugin. Options -C, -H and -I
#   are used to specify how and where to execute 'ls' and process results.
#
#   With -I the plugin will expect output from "ls -l" in standard input.
#
#   With -C you specify actual shell command and it is executed by the plugin.
#
#   With option -H plugin executes ls on a specified host using ssh, it is expected
#   that you'd have proper keys for this option to work. This is simple option is
#   basically a special case of -C and if you want something more complex use -C
#
#   Note: I first wrote -C but found that -I is easier to use and cleaner as
#         far as nagios command specification. Patrick Bailat added -H option.
#
# ========================== VERSION CHANGES AND TODO =========================
#
#  [0.2]  Apr 19, 2012 - First version written based on check_netstat.pl 0.351
#  [0.3]  Apr 21, 2012 - Added -l -r and -T options and fixed bugs
#  [0.32] Apr 21, 2012 - Added -I as an alternative to -C
#  [0.33] Apr 27, 2012 - Fixed bug with determining file ages
#  [0.34] Jun 22, 2012 - Added better reporting of file age than just seconds
#  [0.35] Aug 21, 2012 - Option '-T' was broken. Bug reported by Jeremy Mauro
#  [0.36] Sep 20, 2012 - Made reporting of age optional only when -a option is given.
#                        This is a suggestion by Bernhard Eisenschmid
#  [0.37] Jan 21, 2013 - Added -s option for check file size (Patrick Bailat)
#  [0.38] Jan 22, 2013 - Added -S option for check sum of file size (Patrick Bailat)
#  [0.39] Jan 23, 2013 - Added -H option for execute ls -l by ssh (Patrick Bailat)
#  [0.40] Feb 10, 2013 - Documentation cleanup. New release.
#  [0.41] Mar 23, 2013 - Fixed bug in parse_threshold function
#  [0.416] May 3, 2013 - Fixed bugs reported by Joerg Heinemann that caused failures under
#                        embedded perl. Bugs were in open_shell_stream() and parse_lsline()
#
#  TODO: This plugin is using early threshold check code that became the base
#        of Naglio library and should be updated to use the library later
#
# ========================== LIST OF CONTRIBUTORS =============================
#
# The following individuals have contributed code, patches, bug fixes and ideas to
# this plugin (listed in last-name alphabetical order):
#
#    Patrick Bailat
#    Vincent Besançon
#    Bernhard Eisenschmid
#    William Leibzon
#    Jeremy Mauro
#
# Open source community is grateful for all your contributions.
#
# ========================== START OF PROGRAM CODE ============================

use strict;
use Getopt::Long;
use Date::Parse;

# Nagios specific
use lib "/usr/lib/nagios/plugins";
our $TIMEOUT;
our %ERRORS;
eval 'use utils qw(%ERRORS $TIMEOUT)';
if ($@) {
 $TIMEOUT = 20;
 %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
}

my $Version='0.416';

my $o_help=         undef; # help option
my $o_timeout=      10;    # Default 10s Timeout
my $o_verb=         undef; # verbose mode
my $o_version=      undef; # version info option
my $o_perf=         undef; # Performance data option
my $o_files=        undef; # What files(s) to check
my @o_filesLv=      ();    # array for above list
my @o_filesL=       ();    # array of regex based on above
my $o_warn=         undef; # warning level option
my @o_warnLv=       ();    # array from warn options, before further processing
my @o_warnL=        ();    # array of warn options, each array element is an array of threshold spec
my $o_crit=         undef; # Critical level option
my @o_critLv=       ();    # array of critical options before processing
my @o_critL=        ();    # array of critical options, each element is an array of threshold spec
my $o_dir=          undef; # directory in which to check files
my $o_age=          undef; # option to specify threshold of file age in seconds
my $o_age_warn=     undef; # processed warning and critical thresholds for file age
my $o_age_crit=     undef; # critical threshold for age
my $o_size=         undef; # option to specify threshold of file size in octet
my $o_size_warn=    undef; # processed warning and critical thresholds for file size
my $o_size_crit=    undef; # critical threshold for size
my $o_sumsize=      undef; # option to specify threshold of sum of file size in octet
my $o_sumsize_warn= undef; # processed warning and critical thresholds for sum of file size
my $o_sumsize_crit= undef; # critical threshold for sum of file size
my $o_recurse=      undef; # recurse into subdirectories
my $o_filetype=     undef; # option to look into only files or only directories
my $o_lsfiles=      undef; # will cause ls to actually look for specified files
my $o_label=        undef; # optional label
my $o_cmd=          undef; # specify shell command here that does equivalent to 'ls -l'
my $o_stdin=        undef; # instead of executing 'ls -l', expect this data from std input
my $o_host=         undef; # optional hostadress execute ls -l by ssh

my $ls_pid=         undef;

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub print_version { print "$0: $Version\n" };

sub print_usage {
    print "Usage: $0 [-v] [-t <timeout>] -D <directory> -F <files to check> -w <warn level(s)> -c <crit level(s)> [-a [<warn age>,<crit age>]] [-s [<warn size>,<crit size>]] [-S [<warn size>,<crit size>]] [-f] [-r] [-l] [-T files|dir] [-L label] [-V] [-H <hostaddress> | -I | -C <cmd that does 'ls -l>']\n";
}

# Return true if arg is a number - in this case negative and real numbers are not allowed
sub isnum {
    my $num = shift;
    if ( $num =~ /^[+]?(\d*)$/ ) { return 1 ;}
    return 0;
}

sub perf_name {
  my $iname = shift;
  $iname =~ s/'\/\(\)/_/g; #' get rid of special characters in performance description name
  return "'".$iname."'";
}

# help function used when checking data against critical and warn values
sub check_threshold {
    my ($attrib, $data, $th_array) = @_;
    my $mod = $th_array->[0];
    my $lv1 = $th_array->[1];
    my $lv2 = $th_array->[2];

    # verb("debug check_threshold: $mod : ".(defined($lv1)?$lv1:'')." : ".(defined($lv2)?$lv2:''));
    return "" if !defined($lv1) || ($mod eq '' && $lv1 eq '');
    return " " . $attrib . " is " . $data . " (equal to $lv1)" if $mod eq '=' && $data eq $lv1;
    return " " . $attrib . " is " . $data . " (not equal to $lv1)" if $mod eq '!' && $data ne $lv1;
    return " " . $attrib . " is " . $data . " (more than $lv1)" if $mod eq '>' && $data>$lv1;
    return " " . $attrib . " is " . $data . " (more than $lv2)" if $mod eq ':' && $data>$lv2;
    return " " . $attrib . " is " . $data . " (more than or equal $lv1)" if $mod eq '>=' && $data>=$lv1;
    return " " . $attrib . " is " . $data . " (less than $lv1)" if ($mod eq '<' || $mod eq ':') && $data<$lv1;
    return " " . $attrib . " is " . $data . " (less than or equal $lv1)" if $mod eq '<=' && $data<=$lv1;
    return " " . $attrib . " is " . $data . " (in range $lv1..$lv2)" if $mod eq '@' && $data>=$lv1 && $data<=$lv2;
    return "";
}

# this is a help function called when parsing threshold options data
sub parse_threshold {
    my $thin = shift;

    # link to an array that holds processed threshold data
    # array: 1st is type of check, 2nd is value2, 3rd is value2, 4th is option, 5th is nagios spec string representation for perf out
    my $th_array = [ '', undef, undef, '', '' ];
    my $th = $thin;
    my $at = '';

    $at = $1 if $th =~ s/^(\^?[@|>|<|=|!]?~?)//; # check mostly for my own threshold format
    $th_array->[3]='^' if $at =~ s/\^//; # deal with ^ option
    $at =~ s/~//; # ignore ~ if it was entered
    if ($th =~ /^\:([-|+]?\d+\.?\d*)/) { # :number format per nagios spec
        $th_array->[1]=$1;
        $th_array->[0]=($at !~ /@/)?'>':'<=';
        $th_array->[5]=($at !~ /@/)?('~:'.$th_array->[1]):($th_array->[1].':');
    }
    elsif ($th =~ /([-|+]?\d+\.?\d*)\:$/) { # number: format per nagios spec
        $th_array->[1]=$1;
        $th_array->[0]=($at !~ /@/)?'<':'>=';
        $th_array->[5]=($at !~ /@/)?'':'@';
        $th_array->[5].=$th_array->[1].':';
    }
    elsif ($th =~ /([-|+]?\d+\.?\d*)\:([-|+]?\d+\.?\d*)/) { # nagios range format
        $th_array->[1]=$1;
        $th_array->[2]=$2;
        if ($th_array->[1] > $th_array->[2]) {
            print "Incorrect format in '$thin' - in range specification first number must be smaller then 2nd\n";
            print_usage();
            exit $ERRORS{"UNKNOWN"};
        }
        $th_array->[0]=($at !~ /@/)?':':'@';
        $th_array->[5]=($at !~ /@/)?'':'@';
        $th_array->[5].=$th_array->[1].':'.$th_array->[2];
    }
    if (!defined($th_array->[1])) {
        $th_array->[0] = ($at eq '@')?'<=':$at;
        $th_array->[1] = $th;
        $th_array->[5] = '~:'.$th_array->[1] if ($th_array->[0] eq '>' || $th_array->[0] eq '>=');
        $th_array->[5] = $th_array->[1].':' if ($th_array->[0] eq '<' || $th_array->[0] eq '<=');
        $th_array->[5] = '@'.$th_array->[1].':'.$th_array->[1] if $th_array->[0] eq '=';
        $th_array->[5] = $th_array->[1].':'.$th_array->[1] if $th_array->[0] eq '!';
    }
    if ($th_array->[0] =~ /[>|<]/ && !isnum($th_array->[1])) {
        print "Numeric value required when '>' or '<' are used !\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }
    # verb("debug parse_threshold: $th_array->[0] and $th_array->[1]");
    $th_array->[0] = '=' if !$th_array->[0] && !isnum($th_array->[1]) && $th_array->[1] ne '';
    if (!$th_array->[0] && isnum($th_array->[1])) { # this is just the number by itself, becomes 0:number check per nagios guidelines
        $th_array->[2]=$th_array->[1];
        $th_array->[1]=0;
        $th_array->[0]=':';
        $th_array->[5]=$th_array->[2];
    }
    return $th_array;
}

# this function checks that for numeric data warn threshold is within range of critical threshold
# where within range depends on actual threshold spec and normally just means less
sub threshold_specok {
    my ($warn_thar,$crit_thar) = @_;
    return 0 if (defined($warn_thar->[1]) && !isnum($warn_thar->[1])) || (defined($crit_thar->[1]) && !isnum($crit_thar->[1]));
    return 1 if defined($warn_thar) && defined($warn_thar->[1]) &&
    defined($crit_thar) && defined($crit_thar->[1]) &&
    isnum($warn_thar->[1]) && isnum($crit_thar->[1]) &&
    $warn_thar->[0] eq $crit_thar->[0] &&
    (!defined($warn_thar->[3]) || $warn_thar->[3] !~ /\^/) &&
    (!defined($crit_thar->[3]) || $crit_thar->[3] !~ /\^/) &&
    (($warn_thar->[1]>$crit_thar->[1] && ($warn_thar->[0] =~ />/ || $warn_thar->[0] eq '@')) ||
        ($warn_thar->[1]<$crit_thar->[1] && ($warn_thar->[0] =~ /</ || $warn_thar->[0] eq ':')) ||
        ($warn_thar->[0] eq ':' && $warn_thar->[2]>=$crit_thar->[2]) ||
        ($warn_thar->[0] eq '@' && $warn_thar->[2]<=$crit_thar->[2]));
    return 0;  # return with 0 means specs check out and are ok
}

sub help {
    print "\nFile(s) Age and Count Monitor Plugin for Nagios version ",$Version,"\n";
    print " by William Leibzon - william(at)leibzon.org\n\n";
    print_usage();
    print <<EOD;
-h, --help
    print this help message
-V, --version
    prints version number
-t, --timeout=INTEGER
    timeout for command to finish (Default : 5)
-L, --label
    output label (what prints first on status line)
-v, --verbose
    print extra debugging information

File and Directory Selection options:

-F, --files=STR[,STR[,STR[..]]]
    Which files to check. What is here is similar to what you use for listing
    file with ls i.e. *.temp would look for all temp files. This is converted
    to a regex and NOT an actual ls command input, so some errors are possible.
-D, --dir=<STR>
    Directory name in which to check files. If this is specifies all file names
    given in -F will be relative to this directory.
-T, --filetype='files'|'dir'
    Allows to specify if we should count only files or only directories.
    Default is to count both and ignore file type.
-r, --recurse
    When present ls will do 'ls -r' and recursive check in subdirectories
-l, --lsfiles
    When present this adds specified file spec to ls. Now ls will list
    only files you specified with -F where as by default 'ls -l' will
    list all files in directory and choose some with regex. This option
    should be used if there are a lot of files in a directory.
    WARNING: using this option will cause -r not to work on most system

Exection Options:

-C, --cmd=STR
    By default the plugin will chdir to specified directory, do 'ls -l'
    and parse results. Here you can specify alternative cmd to execute
    that provides the data. This is used, for example, when files are
    to be checked on a remote system, in which case here you could be
    using 'ssh'.
-I, --stdin
    Instead of executing "ls -l" directory or command specified with -C
    plugin expects to get results in standard input. This is basically an
    alternative to -C which may not work in all cases
-H, --hostaddress=<STR>
    This option followed by the IP address or the server name execute "ls"
    on the remote server with ssh. Beware the script must be run with an account
    that has its public key to the remote server.
    This option does not work with the -C option

Threshold Checks and Performance Data options:

-f, --perfparse
    Give number of files and file oldest file age in perfout
-w, --warn=STR[,STR[,STR[..]]]
    Warning level(s) for number of files - must be a number
    Warning values can have the following prefix modifiers:
       > : warn if data is above this value (default)
       < : warn if data is below this value
       = : warn if data is equal to this value
       ! : warn if data is not equal to this value
       ~ : do not check this data (must be by itself)
       ^ : this disables checks that warning is less than critical
    Threshold values can also be specified as range in two forms:
       num1:num2  - warn if data is outside range i.e. if data<num1 or data>num2
       \@num1:num2 - warn if data is in range i.e. data>=num1 && data<=num2
-c, --crit=STR[,STR[,STR[..]]]
    Critical level(s) (if more than one file spec, must have multiple values)
    Critical values can have the same prefix modifiers as warning, except '^'
-a, --age[=WARN[,CRIT]]
    Show file age if no WARN/CRIT threshold parameter specified.
    Check to make sure files are not older than the specified threshold(s).
    This number is in seconds. Also supports same extended spec as -w and -c
-s, --size[=WARN[,CRIT]]
    Show file size if no WARN/CRIT threshold parameter specified.
    Check to make sure files are not larger than the specified threshold(s).
    This number is in octet/byte. Also supports same extended spec as -w and -c
-S, --sumsize[=WARN[,CRIT]]
    Show sum of file sizes if no WARN/CRIT threshold parameter specified.
    Check to make sure sum of file sizes are not larger than the specified threshold(s).
    This number is in octet/byte. Also supports same extended spec as -w and -c

EOD
}

sub check_options {
    my $i;
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v'     => \$o_verb,        'verbose'       => \$o_verb,
        'h'     => \$o_help,        'help'          => \$o_help,
        't:i'   => \$o_timeout,     'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,     'version'       => \$o_version,
        'L:s'   => \$o_label,       'label:s'       => \$o_label,
        'c:s'   => \$o_crit,        'crit:s'        => \$o_crit,
        'w:s'   => \$o_warn,        'warn:s'        => \$o_warn,
        'f'     => \$o_perf,        'perfparse'     => \$o_perf,
        'F:s'   => \$o_files,       'files:s'       => \$o_files,
        'a:s'   => \$o_age,         'age:s'         => \$o_age,
        's:s'   => \$o_size,        'size:s'        => \$o_size,
        'S:s'   => \$o_sumsize,     'sumsize:s'     => \$o_sumsize,
        'D:s'   => \$o_dir,         'dir:s'         => \$o_dir,
        'C:s'   => \$o_cmd,         'cmd:s'         => \$o_cmd,
        'r'     => \$o_recurse,     'recurse'       => \$o_recurse,
        'l'     => \$o_lsfiles,     'lsfiles'       => \$o_lsfiles,
        'T:s'   => \$o_filetype,    'filetype:s'    => \$o_filetype,
        'I'     => \$o_stdin,       'stdin'         => \$o_stdin,
        'H:s'   => \$o_host,        'hostaddress:s' => \$o_host,
    );

    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}; }

    if (defined($o_version)) { print_version(); exit $ERRORS{"UNKNOWN"}; }

    @o_filesLv=split(/,/,$o_files) if defined($o_files);
    if (!defined($o_files) || scalar(@o_filesLv)==0) {
        print "You must specify files to check on with '-F'\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }

    @o_filesLv=split(/,/, $o_files);
    for (my $i=0; $i<scalar(@o_filesLv); $i++) {
        $o_filesL[$i] = parse_filespec($o_filesLv[$i]);
        verb("Translated filespec '".$o_filesLv[$i]."' to regex '".$o_filesL[$i]."'");
    }

    if (defined($o_warn) || defined($o_crit)) {
        @o_filesLv=split(/,/, $o_files);
        @o_warnLv=split(/,/ ,$o_warn) if defined($o_warn);
        @o_critLv=split(/,/ ,$o_crit) if defined($o_crit);
        if (scalar(@o_warnLv)!=scalar(@o_filesLv) || scalar(@o_critLv)!=scalar(@o_filesLv)) {
            if (scalar(@o_warnLv)==0 && scalar(@o_critLv)==scalar(@o_filesLv)) {
                verb('Only critical value check is specified - setting warning to ~');
                for($i=0;$i<scalar(@o_filesLv);$i++) { $o_warnLv[$i]='~'; }
            }
            elsif (scalar(@o_critLv)==0 && scalar(@o_warnLv)==scalar(@o_filesLv)) {
                verb('Only warning value check is specified - setting critical to ~');
                for($i=0;$i<scalar(@o_filesLv);$i++) { $o_critLv[$i]='~'; }
            }
            else {
                printf "Number of specified warning levels (%d) and critical levels (%d) must be equal to the number checks specified at '-F' (%d). If you need not set threshold specify it as '~'\n", scalar(@o_warnLv), scalar(@o_critLv), scalar(@o_filesL);
                print_usage();
                exit $ERRORS{"UNKNOWN"};
            }
        }
        for (my $i=0; $i<scalar(@o_filesLv); $i++) {
            $o_warnL[$i] = parse_threshold($o_warnLv[$i]);
            $o_critL[$i] = parse_threshold($o_critLv[$i]);
            if (threshold_specok($o_warnL[$i],$o_critL[$i])) {
                print "Problem with warn threshold '".$o_warnL[$i][5]."' and/or critical threshold '".$o_critL[$i][5]."'\n";
                print "All warning and critical values must be numeric or ~. Warning must be less then critical\n";
                print "or greater then when '<' is used or within or outside of range for : and @ specification\n";
                print "Note: to override less than check prefix warning value with ^\n";
                print_usage();
                exit $ERRORS{"UNKNOWN"};
            }
        }
    }

    if (defined($o_age)) {
        my @agetemp = split(',',$o_age);
        $o_age_warn = parse_threshold($agetemp[0]) if defined($agetemp[0]) && $agetemp[0] ne '';
        $o_age_crit = parse_threshold($agetemp[1]) if defined($agetemp[1]) && $agetemp[1] ne '';
    }

    if (defined($o_size)) {
        my @sizetemp = split(',',$o_size);
        $o_size_warn = parse_threshold($sizetemp[0]) if defined($sizetemp[0]) && $sizetemp[0] ne '';
        $o_size_crit = parse_threshold($sizetemp[1]) if defined($sizetemp[1]) && $sizetemp[1] ne '';
    }

    if (defined($o_sumsize)) {
        my @sumsizetemp = split(',',$o_sumsize);
        $o_sumsize_warn = parse_threshold($sumsizetemp[0]) if defined($sumsizetemp[0]) && $sumsizetemp[0] ne '';
        $o_sumsize_crit = parse_threshold($sumsizetemp[1]) if defined($sumsizetemp[1]) && $sumsizetemp[1] ne '';
    }

    if (defined($o_filetype)) {
        $o_filetype = lc $o_filetype;
        $o_filetype = 'file' if $o_filetype eq 'files';
        $o_filetype = 'dir' if $o_filetype eq 'dirs';
        if ($o_filetype ne 'file' && $o_filetype ne 'dir') {
            print "Filetype must be one word - either 'file' or 'dir'\n";
            print_usage();
            exit $ERRORS{"UNKNOWN"};
        }
    }

    if ((defined($o_stdin) && defined($o_cmd)) ||
        (defined($o_stdin) && defined($o_host)) ||
        (defined($o_host) && defined($o_cmd))) {
        print "Can use only one of -C or -I or -H\n";
        print_usage();
        exit $ERRORS{"UNKNOWN"};
    }
}

sub parse_filespec {
    my $spec = shift;
    $spec =~ s/\./\\\./g;
    $spec =~ s/\?/\.\?/g;
    $spec =~ s/\*/\.\*/g;
    return $spec;
}

# ls -l line example:
#   -rwxr-xr-x  1 WLeibzon users    21747 Apr 20 23:04 check_files.pl
sub parse_lsline {
    my @parsed = split (/\s+/, shift);
    my %ret = ('type' => 'unset');
    # parse file mode into std number
    if (defined($parsed[0]) && $parsed[0] =~ /([-d])(.{3})(.{3})(.{3})/) {
        my ($file_type,$mod_user, $mod_group, $mod_all) = ($1,$2,$3,$4);
        if ($file_type eq 'd') {
            $ret{'type'}='dir';
        }
        else {
            $ret{'type'}='file';
        }
        $ret{'mode'} = 0;
        $ret{'mode'} += 400 if $mod_user =~ /r/;
        $ret{'mode'} += 200 if $mod_user =~ /w/;
        $ret{'mode'} += 100 if $mod_user =~ /x/;
        $ret{'mode'} += 40 if $mod_group =~ /r/;
        $ret{'mode'} += 20 if $mod_group =~ /w/;
        $ret{'mode'} += 10 if $mod_group =~ /x/;
        $ret{'mode'} += 4 if $mod_all =~ /r/;
        $ret{'mode'} += 2 if $mod_all =~ /w/;
        $ret{'mode'} += 1 if $mod_all =~ /x/;

        $ret{'nfiles'} = $parsed[1] if defined($parsed[1]); # number of files, dir start with 2
        $ret{'user'} = $parsed[2] if defined($parsed[2]);
        $ret{'group'} = $parsed[3] if defined($parsed[3]);
        $ret{'size'} = $parsed[4] if defined($parsed[4]);
        $ret{'time_line'} = $parsed[5].' '.$parsed[6].' '.$parsed[7] if defined($parsed[5]) && defined($parsed[6]) && defined($parsed[7]);
        $ret{'filename'} = $parsed[8] if defined($parsed[8]);
        $ret{'time'} = str2time($ret{'time_line'}) if defined($ret{'time_line'});
    }
    return \%ret;
}

sub div_mod { return int( $_[0]/$_[1]) , ($_[0] % $_[1]); }

sub readable_time {
    my $total_sec = shift;
    my ($sec,$mins,$hrs,$days);
    ($mins,$sec) = div_mod($total_sec,60);
    ($hrs,$mins) = div_mod($mins,60);
    ($days,$hrs) = div_mod($hrs,24);
    my $txtout="";
    $txtout .= "$days days " if $days>0;
    $txtout .= "$hrs hours " if $hrs>0;
    $txtout .= "$mins minutes " if $mins>0 && ($days==0 || $hrs==0);
    $txtout .= "$sec seconds" if ($sec>0 || $mins==0) && ($hrs==0 && $days==0);
    return $txtout;
}

sub open_shell_stream {
  my $shell_command_ref = shift;
  my $cd_dir=undef;
  my $shell_command=undef;

  if (defined($o_stdin)) {
    $shell_command = "<stdin>";
    $$shell_command_ref = $shell_command if defined($shell_command_ref);
    return \*STDIN;
  }
  else {
    if ($o_dir) {
        if (not defined($o_host)) {
            if (!chdir($o_dir)) {
                print "UNKNOWN ERROR - could not chdir to $o_dir - $!";
                exit $ERRORS{'UNKNOWN'};
            } else {
                verb("Changed to directory '".$o_dir."'");
            }
        } else {
            $cd_dir="\"cd ".$o_dir." && ";
        }
    }
    if (defined($o_cmd)) {
        verb("Command Specified: ".$o_cmd);
        $shell_command=$o_cmd;
    } else {
        if(defined($o_host)) {
            $shell_command = "ssh -o BatchMode=yes -o ConnectTimeout=30 ".$o_host." ";
        }
        else {
            $shell_command = "";
        }
        $shell_command .= $cd_dir if defined($cd_dir);
        $shell_command .= "LANG=C ls -l";
        verb("Command: ".$shell_command);
    }
    $shell_command .= " -R" if defined($o_recurse);
    $shell_command .= " ".join(" ",@o_filesLv) if defined($o_lsfiles);
    $shell_command .= "\"" if defined($cd_dir);

    # I would have preferred open3 [# if (!open3($cin, $cout, $cerr, $shell_command))]
    # but there are problems when using it within nagios embedded perl
    verb("Executing ".$shell_command." 2>&1");
    $ls_pid=open(SHELL_DATA, "$shell_command 2>&1 |");
    if (!$ls_pid) {
        print "UNKNOWN ERROR - could not execute $shell_command - $!";
        exit $ERRORS{'UNKNOWN'};
    }
    $$shell_command_ref = $shell_command if defined($shell_command_ref);
    return \*SHELL_DATA;
  }
  return undef; # it should never get here
}

# Get the alarm signal (just in case timeout screws up)
$SIG{'ALRM'} = sub {
    print ("ERROR: Alarm signal (Nagios time-out)\n");
    kill 9, $ls_pid if defined($ls_pid);
    exit $ERRORS{"UNKNOWN"};
};

########## MAIN ##############

check_options();
verb("check_files.pl plugin version ".$Version);

# Check global timeout if something goes wrong
if (defined($TIMEOUT)) {
  verb("Alarm at ".($TIMEOUT+10));
  alarm($TIMEOUT+10);
} else {
  verb("no timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

# next part of the code builds list of attributes to be retrieved
my $statuscode = "OK";
my $statusinfo = "";
my $statusdata = "";
my $perfdata = "";
my $chk = "";
my $i;
my $shell_command = "";
my $nlines=0;
my @ls=();
my $oldest_filetime=undef;
my $oldest_filename=undef;
my $newest_filetime=undef;
my $newest_filename=undef;
my $smallest_filesize=undef;
my $smallest_filesizename=undef;
my $largest_filesize=undef;
my $largest_filesizename=undef;
my @nmatches=();
my $READTHIS=undef;
my $matched=0;
my $temp;
my $sum_filesize=0;

$READTHIS = open_shell_stream(\$shell_command);
# go through each line
while (<$READTHIS>) {
    chomp($_);

    verb("got line: $_");
    $ls[$nlines]=parse_lsline($_);

    foreach my $k (keys %{$ls[$nlines]}) {
        $temp .= ' '.$k .'='. $ls[$nlines]{$k};
    }
    verb ("    parsed:".$temp);

    if (defined($ls[$nlines]{'filename'}) && (!defined($o_filetype) ||
       (defined($o_filetype) && $ls[$nlines]{'type'} eq $o_filetype))) {
        $matched=0;
        for (my $i=0; $i<scalar(@o_filesL); $i++) {
            if ($ls[$nlines]{'filename'} =~ /$o_filesL[$i]/) {
                $nmatches[$i] = 0 if !defined($nmatches[$i]);
                $nmatches[$i]++;
                verb("    file matches regex '".$o_filesL[$i]."' for file spec '".$o_filesLv[$i]."'");
                $matched=1;
            }
        }

        if ($matched==1 && defined($ls[$nlines]{'time'})) {
            if (!defined($newest_filetime) || $ls[$nlines]{'time'}>$newest_filetime) {
                $newest_filetime=$ls[$nlines]{'time'};
                $newest_filename=$ls[$nlines]{'filename'};
            }
            if (!defined($oldest_filetime) || $ls[$nlines]{'time'}<$oldest_filetime) {
                $oldest_filetime=$ls[$nlines]{'time'};
                $oldest_filename=$ls[$nlines]{'filename'};
            }
        }

        if ($matched==1 && defined($ls[$nlines]{'size'})) {
            $sum_filesize += $ls[$nlines]{'size'};
            if (!defined($largest_filesize) || $ls[$nlines]{'size'}>$largest_filesize) {
                $largest_filesize=$ls[$nlines]{'size'};
                $largest_filesizename=$ls[$nlines]{'filename'};
            }
            if (!defined($smallest_filesize) || $ls[$nlines]{'size'}<$smallest_filesize) {
                $smallest_filesize=$ls[$nlines]{'size'};
                $smallest_filesizename=$ls[$nlines]{'filename'};
            }
        }

    }
    $nlines++;
}

if (!defined($o_stdin) && !close(SHELL_DATA)) {
    print "UNKNOWN ERROR - execution of $shell_command resulted in an error $? - $!";
    exit $ERRORS{'UNKNOWN'};
}

if ($nlines eq 0) {
    print "UNKNOWN ERROR - did not receive any results";
    exit $ERRORS{'UNKNOWN'};
}

# Check time
my $tnow = time();
verb("Date ".$tnow." Oldest_filetime: ".$oldest_filetime." Newest_filetime: ".$newest_filetime);
my $oldest_secold=$tnow-$oldest_filetime if defined($oldest_filetime);
my $newest_secold=$tnow-$newest_filetime if defined($newest_filetime);
verb("Oldest file has age of ".$oldest_secold." seconds and newest ".$newest_secold." seconds");
if (defined($o_age) && defined($oldest_secold)) {
    if (defined($o_age_crit) && ($chk = check_threshold($oldest_filename." ",$oldest_secold,$o_age_crit)) ) {
        $statuscode = "CRITICAL";
        $statusinfo .= "," if $statusinfo;
        $statusinfo .= $chk." seconds old";
    }
    if (defined($o_age_warn) && ($chk = check_threshold($oldest_filename." ",$oldest_secold,$o_age_warn)) && $statuscode eq 'OK' ) {
        $statuscode = "WARNING" if $statuscode eq "OK";
        $statusinfo .= "," if $statusinfo;
        $statusinfo .= $chk." seconds old";
    }
    if ($statuscode eq 'OK') {
        $statusdata .= "," if ($statusdata);
        $statusdata .= " Oldest timestamp is ".readable_time($oldest_secold)." old";
    }
}

# Check size
verb("Largest file has size of ".$largest_filesize." octet and smallest ".$smallest_filesize." octet");
if (defined($o_size) && defined($largest_filesize)) {
    my $flag_data=0;
    if (defined($o_size_crit) && ($chk = check_threshold($largest_filesizename." ",$largest_filesize,$o_size_crit)) ) {
        $flag_data=1;
        $statuscode = "CRITICAL";
        $statusinfo .= "," if $statusinfo;
        $statusinfo .= $chk." bytes";
    }
    if (defined($o_size_warn) && ($chk = check_threshold($largest_filesizename." ",$largest_filesize,$o_size_warn)) && ($statuscode eq 'OK' || $statuscode eq 'WARNING') ) {
        $flag_data=1;
        $statuscode = "WARNING" if $statuscode eq "OK";
        $statusinfo .= "," if $statusinfo;
        $statusinfo .= $chk." bytes";
    }
    if ($flag_data==0) {
        $statusdata .= "," if ($statusdata);
        $statusdata .= " Largest size file is ".$largest_filesize." bytes";
    }
}

# Check sum of file sizes
if (defined($o_sumsize) && $sum_filesize > 0) {
    my $flag_data=0;
    verb("Sum of file sizes is ".$sum_filesize." octet");
    if (defined($o_sumsize_crit) && ($chk = check_threshold("Sum of file sizes ",$sum_filesize,$o_sumsize_crit)) ) {
        $flag_data=1;
        $statuscode = "CRITICAL";
        $statusinfo .= "," if $statusinfo;
        $statusinfo .= $chk." octet";
    }
    if (defined($o_sumsize_warn) && ($chk = check_threshold("Sum of file sizes ",$sum_filesize,$o_sumsize_warn)) && ($statuscode eq 'OK' || $statuscode eq 'WARNING') ) {
        $flag_data=1;
        $statuscode="WARNING" if $statuscode eq "OK";
        $statusinfo .= "," if $statusinfo;
        $statusinfo .= $chk." bytes ";
    }
    if ($flag_data==0) {
        $statusdata .= "," if ($statusdata);
        $statusdata .= " Sum of file sizes is ".$sum_filesize." bytes";
    }

}

# loop to check if warning & critical attributes are ok
for ($i=0;$i<scalar(@o_filesL);$i++) {
    $nmatches[$i]=0 if !defined($nmatches[$i]);
    if ($chk = check_threshold($o_filesLv[$i],$nmatches[$i],$o_critL[$i])) {
        $statuscode = "CRITICAL";
        $statusinfo .= "," if $statusinfo;
        $statusinfo .= $chk;
    } elsif ($chk = check_threshold($o_filesLv[$i],$nmatches[$i],$o_warnL[$i])) {
        $statuscode="WARNING" if $statuscode eq "OK";
        $statusinfo .= "," if $statusinfo;
        $statusinfo .= $chk;
    } else {
        $statusdata .= "," if ($statusdata);
        $statusdata .= " ".$nmatches[$i]." ". $o_filesLv[$i] ." files found";
    }
    $perfdata .= " ". perf_name($o_filesLv[$i]) ."=". $nmatches[$i] if defined($o_perf);

    if (defined($o_perf) && defined($o_warnL[$i][5]) && defined($o_critL[$i][5])) {
        $perfdata .= ';' if $o_warnL[$i][5] ne '' || $o_critL[$i][5] ne '';
        $perfdata .= $o_warnL[$i][5] if $o_warnL[$i][5] ne '';
        $perfdata .= ';'.$o_critL[$i][5] if $o_critL[$i][5] ne '';
    }
}

# perffata for age
if (defined($o_perf) && defined($o_age)) {
    $oldest_secold=0 if !defined($oldest_secold);
    $newest_secold=0 if !defined($newest_secold);
    $perfdata .= " age_oldest=".$oldest_secold."s";
    $perfdata .= ';' if (defined($o_age_warn) && $$o_age_warn[5] ne '') || (defined($o_age_crit) && $$o_age_crit[5] ne '');
    $perfdata .= $$o_age_warn[5] if defined($$o_age_warn[5]) && $$o_age_warn[5] ne '';
    $perfdata .= ';'.$$o_age_crit[5] if defined($$o_age_crit[5]) && $$o_age_crit[5] ne '';
    $perfdata .= " age_newest=".$newest_secold."s";
}

# perffata for size
if (defined($o_perf) && defined($o_size)) {
    $largest_filesize=0 if !defined($largest_filesize);
    $smallest_filesize=0 if !defined($smallest_filesize);
    $perfdata .= " size_largest=".$largest_filesize."o";
    $perfdata .= ';' if (defined($o_size_warn) && $$o_size_warn[5] ne '') || (defined($o_size_crit) && $$o_size_crit[5] ne '');
    $perfdata .= $$o_size_warn[5] if defined($$o_size_warn[5]) && $$o_size_warn[5] ne '';
    $perfdata .= ';'.$$o_size_crit[5] if defined($$o_size_crit[5]) && $$o_size_crit[5] ne '';
    $perfdata .= " size_smallest=".$smallest_filesize."o";
}

# perffata for sum of file sizes
if (defined($o_perf) && defined($o_sumsize)) {
    $perfdata .= " size_sum=".$sum_filesize."o";
    $perfdata .= ';' if (defined($o_sumsize_warn) && $$o_sumsize_warn[5] ne '') || (defined($o_sumsize_crit) && $$o_sumsize_crit[5] ne '');
    $perfdata .= $$o_sumsize_warn[5] if defined($$o_sumsize_warn[5]) && $$o_sumsize_warn[5] ne '';
    $perfdata .= ';'.$$o_sumsize_crit[5] if defined($$o_sumsize_crit[5]) && $$o_sumsize_crit[5] ne '';
}

$o_label .= " " if $o_label ne '';
print $o_label . $statuscode;
print " -".$statusinfo if $statusinfo;
print " -".$statusdata if $statusdata;
print " |".$perfdata if $perfdata;
print "\n";

exit $ERRORS{$statuscode};
