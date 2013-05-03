#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_by_snmp
# Version : 0.3
# Date    : Mar 27, 2012
# Author  : William Leibzon - william(at)leibzon.org
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# =========================== PROGRAM LICENSE =================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ===================== INFORMATION ABOUT THIS PLUGIN =========================
#
# This plugin is used in conjunction with other plugins to retrieve data made
# available using snmp extend and exec and provide this to other plugins for
# processing. This also allows to execute plugins remote plugin using snmpd
# and return the results to Nagios as if it was a local plugin.
#
# This is not like check_snmp as it does not itself check any results (just
# like check_by_ssh is not the same as check_ssh). Similar to NRPE the use of
# check_by_snmp is to enable retrieving results of plugins from remote system
# using SNMP or to enable plugins to be executed normally but using data from
# remote system passed through SNMP.
#
# This program is written and maintained by:
#   William Leibzon - william(at)leibzon.org
#
# ============================= SETUP NOTES ====================================
#
# To find all available options do:
#   ./check_by_snmp -help
#
# All SNMP Versions (1,2,3) and authentication options are supported and
# similar to my other check_snmp plugins.
#
# The options specific to this plugin are -E, -O, -S, -T, -F and --exec.
#
# -E is used to specify one or more extend names configured in snmpd.conf.
#    Usually this will be only one but more than one can also be specified if
#    you want to retrieve data from multiple files. Then separate names by ','.
#
#    In snmpd you configure extend option as in this example:
#        extend cpustat /bin/cat /proc/stat
#    which would be added to snmpd.conf if you want to get /proc/stat data.
#    Same way you can also execute nagios plugins if they are on a remote system.
#
# -O is used to specify one or more OIDs where you are providing data with SNMP exec.
#    You can not mix -E and -O, in fact same snmpd version will probably not
#    support both (snmp exec was depreciated when snmp extends came out).
#
#    In snmpd you provide this data with exec option being added, for example:
#        exec .1.3.6.1.4.1.2021.201 cpustat /bin/cat /proc/stat
#    can be added to snmpd.conf if you want to get /proc/stat data.
#    Exact OID is your choice; and don't just copy above - although that number
#    is ok, it maybe reserved or in use on your system if you do not check.
#
# -S will output the data retrieved from SNMP into standard output. This is
#    default behavior even if you do not specify this option. This is basically
#    what you want if you are using this to execute remote plugin. However
#    check_by_snmp does a little more than just dump data as it will also exit
#    with same exit code as remote command (usualy nagios plugin) and it gives
#    nagios exit errors if SNMP connection can not be established.
#
#    If more than one Extend name or OID are specified, than exit code is from
#    last one though it really does not make mush sense to specify more than one
#    when you're basically using check_by_snmp to execute remote plugin
#
# -F option is used to specify which files the remote data should be written to
#    on nagios server. If you have a plugin on nagios that is expecting certain
#    file you can use this to make it available to the plugin. Be warned that you
#    may have multiple of the same plugin executed for different remote systems
#    so really each file should be unique for each run which is why -T is better.
#    -F can also be useful for debugging as even if you write to standard output
#    you can use this to also write data to some debug/log file.
#
# -T option will have this plugin write data to temporary file name of its choice.
#    The directory is normally /tmp but if you want you can specify different
#    directory as an optional parameter to -T
#
# -- or --exec is an option that lets you execute another plugin on a nagios system.
#    The first parameter after --exec should be command to be executed and then
#    parameters.
#
#    Please note that you MUST NOT specify --exec="command". This is really not your
#    standard option, it basically just indicates where ARG processing should end
#    and rest is used as ARGV parameters for a command to be executed.
#
#    You would use this option when real processing is to be done by some other
#    nagios plugin which would use data retrieved from a remote system with
#    check_by_snmp. Very often these would be dumping of files in /proc,
#    but other uses are also possible. The plugin you are executing should
#    allow to customize and read data from somewhere other than its normal
#    location and allow specify this location as a parameter. Instead of
#    actual file you would specify %FILE1% (and %FILE2% and so on if you
#    specified multiple extends or data OIDs) and these would be replaced
#    with actual file where data has been written to especially if you use
#    -T where this plugin creates temporary files.
#
#    When using -T (which is what I recommend), command execution is done by
#    forking and then plugin waits for forked plugin to finish, removes temporary
#    file it wrote and returns with same exit code as executed plugin.
#
#    You can also do without temporary files with -S and then check_by_snmp can
#    just pipe data it got from SNMP as standard input for plugin being executed
#    with --exec.
#
#    And if you are using -F then check_by_snmp will just use exec to replace
#    itself with specified command. If files specified in -F is a temporary file
#    name, you are responsible for deleting it.
#
# -v is a debug option when you're testing this plugin directly on the shell
#    command line, you will find it useful if you run into any problems
#
# ========================= SETUP EXAMPLES ==================================
#
# For example on how to set this up I will use check_drbd plugin by Brandon Lee Poyner
# (you can find it on exchange.nagios.org) as it happened to be good victim and can
# be used with check_by_snmp in multiple ways:
#
#   1) -S option with no --exec (this is default behavior when no options are specified)
#	Returns results from SNMP to standard output. This is what you may call "snmp cat"
#	and so most similar to check_nrpe or check_by_ssh in that it lets you simply
#	call remote nagios plugin to be executed by SNMPd and returns results to Nagios:
#
#      Example of setting up this way with drbd (drbd-0.5.6 on exchange) is:
#
#       /etc/snmp/snmpd.conf of a remote system:
#         exec .1.3.6.1.4.1.2021.202 check_drbd /usr/lib/nagios/plugins/check_drbd-0.5.2 -D All
#       Command definition in nagios:
#         define command {
#               command_name check_drbd
#               command_line $USER1$/check_by_snmp -O 1.3.6.1.4.1.2021.202 -H $HOSTADDRESS$ -L sha,aes -l $_HOSTSNMP_V3_USER$ -x $_HOSTSNMP_V3_AUTH$ -X $_HOSTSNMP_V3_PRIV$ -S
#         }
#
#   2) -T with --exec
#	In this second case the plugin will write data from SNMP into one
#	or more temporary files and execute specified nagios plugin. The plugin
#	will parse arguments in the actual check command to be executed and replace
#        %FILE1% with a name of the first file it wrote
#        %FILE2% with a name of the 2nd file it wrote
#        ...
#      If these were temporary files, they will be deleted after plugin finished
#
#      Example of setting up this way with drbd (drbd-0.5.2 on exchange) is:
#
#	/etc/snmp/snmpd.conf of a remote system:
#  	  exec .1.3.6.1.4.1.2021.202 procdrbd /bin/cat /proc/drbd
#
#	Command definition in nagios:
#         define command {
#               command_name check_drbd
#               command_line $USER1$/check_by_snmp -O 1.3.6.1.4.1.2021.202 -H $HOSTADDRESS$ -L sha,aes -l $_HOSTSNMP_V3_USER$ -x $_HOSTSNMP_V3_AUTH$ -X $_HOSTSNMP_V3_PRIV$ -T --exec $USER1$/check_drbd-0.5.2 -p %FILE1% -d All
#         }
#
#   3) -S with --exec
#      Third case is similar to 2 and also involves execution of actual plugin.
#      Unlike case 2 no temporary files are created and results are just piped
#      from check_by_snmp to standard input of plugin it is executing.
#
#      Example of setting up this way with drbd is:
#
#       /etc/snmp/snmpd.conf of a remote system:
#         exec .1.3.6.1.4.1.2021.202 procdrbd /bin/cat /proc/drbd
#
#       Command definition in nagios:
#	  define command {
#        	command_name check_drbd
#        	command_line $USER1$/check_by_snmp -O 1.3.6.1.4.1.2021.202 -H $HOSTADDRESS$ -L sha,aes -l $_HOSTSNMP_V3_USER$ -x $_HOSTSNMP_V3_AUTH$ -X $_HOSTSNMP_V3_PRIV$ -S --exec $USER1$/check_drbd-0.5.2 -p - -d All
#	  }
#
#    4) -F with --exec
#	Last case which is my least favorite is to specify actual files to
#	write with -F option and then execute another plugin which will know
#	these file names and read them for processing. If these are meant to
#	be temporary files you are responsible with making sure these are deleted.
#
#	In this case unlike 2) and 3) above the plugin will not fork
#	to execute command and wait for it to finish, instead it does exec
#	and replaces itself with specified command/plugin. This may make
#	it slightly faster but not by much. And do note that the called
#       plugin will not be executed under nagios embedded perl where as
#       in other cases it actually will.
#
#    Note that -F option can be used together with -S, in which case data is
#    written to specified file(s) in addition to standard output. This will work
#    both with --exec and without. This is most useful for debugging.
#
# ==================== CHANGES/RELEASE, TODO  ===============================
#
#  Versions:
#    0.1  - December 2011  : development and testing
#    0.2  - Dec 30,  2011  : date of a fist public release
#    0.21 - Dec 31,  2011  : added killing of forked process to timeout alarm
#			     small documentationfixes and updates
#    0.22 - Jan 07, 2012   : Added pipe redirection for both in and out for
#			     plugin being executed by this one. This should make
#			     it compatible with embedded perl
#    0.25 - Mar 05, 2012   : Added -m option to specify message size and
#                            increased default size to 10k.
#    0.3  - Mar 27, 2012   : The plugin now support both SNMP exec and SNMP
#			     extend. Extend replaced exec in new versions of
#			     SNMP daemon but most of my systems (RHEL servers)
#			     do not support it yet. Also fixed some of the
#			     horrible documentation I originally written.
#  TODO:
#  1) I'm planning to release embedded SNMP perl agent that would provide data
#     from /proc all together rather than having to specify each file you
#     want with separate "exec ..." or "extend ..". This plugin will have
#     additional option to support this agent.
#  2) Please email me (william(at)leibzon.org) if you want additional features.
#
# ========================== START OF PROGRAM CODE ===========================

use strict;
use Getopt::Long;
use File::Temp qw/ tempfile tempdir /;
use POSIX qw(dup2);

# Nagios specific
our $TIMEOUT;
our %ERRORS;
use lib "/usr/lib/nagios/plugins";
eval 'use utils qw(%ERRORS $TIMEOUT)';
if ($@) {
 $TIMEOUT = 25;
 %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
}

our $no_snmp=0;
eval 'use Net::SNMP';
if ($@) {
  $no_snmp=1;
}

# These are nsExtendResult and nsExtendOutLine table bases
my $oid_ExtendExitStatus="1.3.6.1.4.1.8072.1.3.2.3.1.4";
my $oid_ExtendDataLines="1.3.6.1.4.1.8072.1.3.2.4.1.2";

my $o_timeout_exec=$TIMEOUT;	# general timeout
my $o_help=     undef;          # help option
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # version info option

my $opt_extlist=undef;		# List of Extend names to e retrieved
my @extends=	();		#
my $opt_oidlist= undef;		# List of OIDs to retrieve data from
my @oids=	();		#
my $opt_filelist=undef;		# List of files to write
my @files=();			#

my $o_exec=	undef;		# Execute specified plugin
my $o_tempfiles= undef;		# Create temp files and delete after execution of a plugin
my $o_stdout=	undef;		# "Cat" option, just output data from SNMP
my @exec_args=();		# arguments to be passed to executed command

# Login and other options specific to SNMP
my $o_port =            161;    # SNMP port
my $o_community =       undef;  # community
my $o_version2  =       undef;  # use snmp v2c
my $o_login=            undef;  # Login for snmpv3
my $o_passwd=           undef;  # Pass for snmpv3
my $v3protocols=        undef;  # V3 protocol list.
my $o_authproto=        'md5';  # Auth protocol
my $o_privproto=        'des';  # Priv protocol
my $o_privpass=         undef;  # priv password
my $o_host=     	undef;  # hostname
my $o_timeout_snmp=	5;	# snmp timeout
my $o_msgsize=		10000;  # snmp messge size

my $Version='0.3';
my $pid = undef;

sub p_version { print "check_by_snmp version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v | -V | -h] | [-O oid[,oid2,oid3... | -E extend1,extend2,extend3...] [-F file1[,<file2,..] | -T | -S] -H <host> (-C <snmp_community>) [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>) [-p <port>] [-t <timeout>] [ -- command arguments ] \n";
}

sub isnum { # Return true if arg is a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 1 ;}
  return 0;
}

sub help {
   print "\nCheck By SNMP (using Extend or Exec) for Nagios, version ",$Version,"\n";
   print "GPL licence, (c) 20011-2012 William Leibzon\n\n";
   print_usage();
   print <<EOT;

Debug & Console Options:
 -v, --verbose
   print extra debugging information
 -h, --help
   print this help message
 -V, --version
   prints version number

Standard Options:
 -E, --extend=<extend table name>[,<extend table name>[,<extend table name>...]]
   If you added "extend name command" in /etc/snmp/snmpd.conf such as
     "exec cpustat /bin/cat /proc/stat"
   then "-E cpustat" would return data from executing "/bin/cat /proc/stat".
   You can specify more than one such name here to be queried at once,
   wuth at least one extend name or exec OID (see below) required.
 -O, --oid=<oid>[,<oid>[,<oid>..]]
   OID of where results have been put with snmp exec. At least one is required.
   You put data in snmp by adding for example the following to /etc/snmp/snmpd.conf
     "exec .1.3.6.1.4.1.2021.201 cpustat /bin/cat /proc/stat"
   And specifying '-O 1.3.6.1.4.1.2021.201' when calling this plugin
 -F, --fileout=<name>[,<name>[,<name>...]]
   Name of the files to write data read from SNMP to. If you're using this, there
   should be exacly the same number of files specified as OIDs specified with -O
   Any existing files will be overridden on each call
 -T,--tempfiles[=<tempdir>]
   Put data into temporary file names and delete after execution of plugin
   (Note: this option requires --exec).
   Optionally you can specify temporary directory, if you dont /tmp will be used.
 -S, --stdout
   Output all results to stdout. This is default if -F and -T are not specified
 -- command arguments | --exec command arguments
   Anything after -- or after --exec is treated as a command to be called
   after this plugin to process the data, normally this is another nagios plugin
   that is written to read the data and output nagios status. Arguments will be
   parsed for appearance of %FILE1%, %FILE2%", etc and replaced with file names
   where data from SNMP has been dumped to.

   Note that this MUST be the last argument to this plugin as everything after
   is treated as arguments to another plugin even if they look like they could
   apply to this plugin. Also note that the commands and arguments should not
   be enclosed as "..." - these are not one argument, the plugin will keep
   the reminder as an ARGV array and pass it on to new command.
 -e | --exec_timeout=seconds
   Timeout waiting for command started with --exec to finish
   Default is 25 seconds or whatever NAGIOS is set to

SNMP Options:
 -H, --hostname=HOST
   name or IP address of host to check (if not localhost)
 -C, --community=COMMUNITY NAME
   community name for the SNMP agent (used with v1 or v2c protocols)
 -2, --v2c
   use snmp v2c (can not be used with -l, -x)
 -l, --login=LOGIN ; -x, --passwd=PASSWD
   Login and auth password for snmpv3 authentication
   If no priv password exists, implies AuthNoPriv
 -X, --privpass=PASSWD
   Priv password for snmpv3 (AuthPriv protocol)
 -L, --protocols=<authproto>,<privproto>
   <authproto> : Authentication protocol (md5|sha : default md5)
   <privproto> : Priv protocols (des|aes : default des)
 -p, --port=PORT
   SNMP port (Default 161)
 -t, --snmp_timeout=seconds
   Timeout wating for SNMP data. Default is 5 seconds.
 -m, --msgsize=bytes
   Max SNMP Message Size, default is 10,000
EOT

}

# For verbose output during debugging - don't use it right now
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
    my @my_args=();

    for (my $i=0; $i<scalar(@ARGV); $i++) {
	if (!defined($o_exec)) {
		if ($ARGV[$i] ne "--" && $ARGV[$i] ne "--exec") {
			push @my_args, $ARGV[$i];
		}
		else {
			$o_exec=1;
			$ARGV[$i] = "--"; # GetOptions will stop processing here
		}
	}
	else {
		push @exec_args, $ARGV[$i];
	}
    }
    if (defined($o_exec) && scalar(@exec_args)==0) {
	print "You must specify command to execute after --exec or -- option\n";
	print_usage(); exit $ERRORS{"UNKNOWN"};
    }

    Getopt::Long::Configure ("bundling");
    # Getopt::Long::GetOptionsFromArray(\@my_args,
    GetOptions(
        'v'     => \$o_verb,            'verbose'       => \$o_verb,
        'h'     => \$o_help,            'help'          => \$o_help,
        'H=s'   => \$o_host,            'hostname=s'    => \$o_host,
        'p=i'   => \$o_port,            'port=i'        => \$o_port,
        'C=s'   => \$o_community,       'community=s'   => \$o_community,
         '2'    => \$o_version2,        'v2c'           => \$o_version2,
        'l=s'   => \$o_login,           'login=s'       => \$o_login,
        'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
        'X:s'   => \$o_privpass,        'privpass:s'    => \$o_privpass,
        'L=s'   => \$v3protocols,       'protocols=s'   => \$v3protocols,
        't=i'   => \$o_timeout_snmp,    'snmp_timeout=i' => \$o_timeout_snmp,
	'e=i'	=> \$o_timeout_exec,	'exec_timeout=i' => \$o_timeout_exec,
        'V'     => \$o_version,         'version'       => \$o_version,
	'E=s'	=> \$opt_extlist,	'extend'	=> \$opt_extlist,
	'O=s'	=> \$opt_oidlist,	'oid=s'		=> \$opt_oidlist,
	'F=s'	=> \$opt_filelist,	'fileout=s'	=> \$opt_filelist,
	'T:s'	=> \$o_tempfiles,	'tempfiles:s'	=> \$o_tempfiles,
	'S'	=> \$o_stdout,		'stdout'	=> \$o_stdout,
	'm=i'	=> \$o_msgsize,		'msgsize=i'	=> \$o_msgsize
    );

    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}; }
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}; }
    if (defined($o_exec)) {
        verb("External command to be executed: ".join(' ',@exec_args));
    }

    # Various checks that snmp options are all given
    if ($no_snmp) {
        print "Can't locate Net/SNMP.pm\n"; print_usage(); exit $ERRORS{"UNKNOWN"};
    }
    if (!defined($opt_oidlist) && !defined($opt_extlist)) {
	print "At least one Extended Name or SNMP OID must be specified\n";
	print_usage();exit $ERRORS{"UNKNOWN"};
    }
    if (defined($opt_oidlist) && defined($opt_extlist)) {
	print "You can not specify both Exnteded name and Exec OID\n";
	print_usage();exit $ERRORS{"UNKNOWN"};
    }
    if (defined($opt_oidlist)) {
	@oids = split(',',$opt_oidlist);	
    }
    if (defined($opt_extlist)) {
	@extends = split(',',$opt_extlist);
    }
    if (! defined($o_host) ) # check host and filter
    {
	print "SNMP OID specified but not host name!\n";
	print_usage(); exit $ERRORS{"UNKNOWN"};
    }
    # check snmp information
    if ((defined($o_login) || defined($o_passwd))
	&& (defined($o_community) || defined($o_version2)) )
    {
	print "Can't mix snmp v1,2c,3 protocols!\n";
	print_usage(); exit $ERRORS{"UNKNOWN"};
    }
    if (defined ($v3protocols)) {
       	if (!defined($o_login))
	{
		print "Put snmp V3 login info with protocols!\n";
		print_usage(); exit $ERRORS{"UNKNOWN"};
	}
        my @v3proto=split(/,/,$v3protocols);
       	if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {
		$o_authproto=$v3proto[0];  #auth protocol
	}
        if (defined ($v3proto[1])) {
		$o_privproto=$v3proto[1];  #priv protocol
	}
        if ((defined ($v3proto[1])) && (!defined($o_privpass))) {
		print "Put snmp V3 priv login info with priv protocols!\n";
		print_usage(); exit $ERRORS{"UNKNOWN"};
        }
    }
    if (!defined($o_community) && (!defined($o_login) || !defined($o_passwd)))
    {
	print "Put snmp login info!\n";
	print_usage(); exit $ERRORS{"UNKNOWN"};
    }

    if (defined($opt_filelist)) {
	if (defined($o_tempfiles)) {
		print "You can use one of either -F and -T together\n";
		print_usage(); exit $ERRORS{"UNKNOWN"};
	}
	@files = split ',' ,$opt_filelist;
	if (scalar(@files) != (scalar(@oids)+scalar(@extends))) {
		print "Number of specified files must be the same as extend names or OIDs";
		print_usage(); exit $ERRORS{"UNKNOWN"};
	}
    }
    if (defined($o_tempfiles)) {
	if (defined($o_stdout)) {
		print "You can use one of either -S and -T together\n";
		print_usage(); exit $ERRORS{"UNKNOWN"};
        }
	if (!defined($o_exec)) {
		print "Using -T also requires --exec\n";
		print_usage(); exit $ERRORS{"UNKNOWN"};
	}
	if ($o_tempfiles eq '') {
		$o_tempfiles = '/tmp';
	}
    }
    else {
	$o_stdout = 1 if !defined($o_stdout) && (!defined($o_exec) || !defined($opt_filelist)); # default if -F and -T not specified
    }
}

sub replace_macros {
  my $args  = shift;
  my $files = shift;
  my ($i, $j, $reg, $rep);
  for ($i=1;$i<scalar(@{$args});$i++) {
	for ($j=1;$j<=scalar(@{$files});$j++) {
		$reg='%FILE'.$j.'%';	
		$rep=$files->[$j-1];
		# verb("Checking '".$args->[$i]."' with regex '".$reg."'");
		if ($args->[$i] =~ /$reg/) {
			verb("Replacing '".$reg."' in '".$args->[$i]."' with '".$rep."'");
			$args->[$i] =~ s/$reg/$rep/g;
		}
	}
  }
}

sub snmp_session {
  # Connect to host
  my ($session,$error);

  if ( defined($o_login) && defined($o_passwd)) {
    # SNMPv3 login
    if (!defined ($o_privpass)) {
     verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
     ($session, $error) = Net::SNMP->session(
      -hostname         => $o_host,
      -version          => '3',
      -port             => $o_port,
      -username         => $o_login,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -timeout          => $o_timeout_snmp
     );
    } else {
     verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
     ($session, $error) = Net::SNMP->session(
      -hostname         => $o_host,
      -version          => '3',
      -username         => $o_login,
      -port             => $o_port,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -privpassword     => $o_privpass,
      -privprotocol     => $o_privproto,
      -timeout          => $o_timeout_snmp
     );
    }
  } else {
    if (defined ($o_version2)) {
      # SNMPv2 Login
      ($session, $error) = Net::SNMP->session(
        -hostname  => $o_host,
            -version   => 2,
        -community => $o_community,
        -port      => $o_port,
        -timeout   => $o_timeout_snmp
      );
    } else {
      # SNMPV1 login
      ($session, $error) = Net::SNMP->session(
        -hostname  => $o_host,
        -community => $o_community,
        -port      => $o_port,
        -timeout   => $o_timeout_snmp
      );
    }
  }

  if (!defined($session)) {
    printf("ERROR opening session: %s with host %s\n", $error, $o_host);
    exit $ERRORS{"UNKNOWN"};
  }

  $session->max_msg_size($o_msgsize);

  return $session;
}

# Get the alarm signal (just in case snmp timout screws up)
$SIG{'ALRM'} = sub {
     print "ERROR: Alarm signal (Nagios time-out)\n";
     kill 9, $pid if defined($pid);
     exit $ERRORS{"UNKNOWN"};
};

########## MAIN #######

check_options();

# Check gobal timeout if plugin screws up
if (defined($o_timeout_exec)) {
  verb("Alarm at : $o_timeout_exec + 5");
  alarm($o_timeout_exec+5);
} else {
  verb("no timeout defined, setting to : $o_timeout_snmp + 20");
  alarm ($o_timeout_snmp+20);
}

my $oid_exitcode;	  # Exit Code OID for Extend
my @slines=();            # Printing of stdout is delayed, here they are collected
my $retcode = undef;	  # return exit value of the last executed command
my ($i,$b,$e);

# Convert Extend Name into OIDs which are base + ASCII code of each character in the name
for($i=0; $i<scalar(@extends);$i++) {
   my @chars = split //, $extends[$i];
   $oids[$i]=$oid_ExtendDataLines.'.'.scalar(@chars);
   $oid_exitcode=$oid_ExtendExitStatus.'.'.scalar(@chars);
   foreach my $c (@chars) {
	$oids[$i] .= '.' . ord($c);
	$oid_exitcode .= '.' . ord($c);
   }
   verb("Converted Extends Name '".$extends[$i]."' to Data Lines OID ".$oids[$i]);
   verb("Converted Extends Name '".$extends[$i]."' to Exit Status OID ".$oid_exitcode);
}

# Read the data from SNMP
my $fln = 0;
my $session = snmp_session();

foreach my $oid (@oids) {
   my @lines; # main array where each line retrieved from SNMP is stored at
              # $lines[1] is snmp name for this, $lines[2] is command it executed
              # $lines[3] is exit status and $lines[4] and up are return text
              # the last line is 0 and should be ignored
   verb("Retrieving SNMP Table ".$oid);
   my $result = $session->get_table( -baseoid => $oid );

   if (!defined($result)) {
	printf("ERROR: retrieving OID %s table: %s.\n", $oid, $session->error);
	$session->close();
    	exit $ERRORS{"UNKNOWN"};
   }
   foreach my $k (Net::SNMP::oid_lex_sort(keys %{$result})) {
	push @lines, $result->{$k};
	verb("Got line: ".$result->{$k});
   }
   if (scalar(@extends)==0 && scalar(@lines)<5) {
	print "ERROR: not enough data returned by SNMP at oid '".$oid."'.";
	print " ".$lines[1]." was run and " if defined($lines[1]);
	print " exit code was ".$lines[3] if defined($lines[3]);
	print "\n";
	exit $ERRORS{"CRITICAL"};
   }

   my $fh = undef;
   if (defined($o_tempfiles)) {
	($fh, $files[$fln]) = tempfile("check_by_snmp_XXXXXX", DIR => $o_tempfiles);
	if (!defined($fh)) { print "Can not create temporary file - $!"; exit $ERRORS{"UNKNOWN"}; }
   }
   if (defined($opt_filelist)) {
	open ($fh, ">", $files[$fln]);
	if (!defined($fh)) { print "Can not open file ".$files[$fln]." for writing - $!"; exit $ERRORS{"UNKNOWN"}; }
   }
   if (scalar(@extends)>0) {
	$b=0;
	$e=scalar(@lines);
   }
   else {
	$b=4;
	$e=scalar(@lines)-2;
   }
   if (defined($fh)) {
   	for ($i=$b; $i<$e;$i++) {
		print $fh $lines[$i];
		print $fh "\n";
	}
   	close($fh);
   }
   if (defined($o_stdout)) {
        for ($i=$b; $i<$e;$i++) {
		push @slines, $lines[$i];   # actual output out is delayed
        }
	$retcode=$lines[3] if scalar(@extends)==0;
   }
   $fln++;
}

# Get exit code from last Extend command if necessary
if (scalar(@extends)>0 && defined($o_stdout)) {
   verb("Retrieving Exit Status SNMP OID ".$oid_exitcode);
   my $result = $session->get_request(-varbindlist=>[$oid_exitcode]);
   if (!defined($result)) {
	print "ERROR: Could not retrieve $oid_exitcode: ".$session->error.".\n";
	exit $ERRORS{"UNKNOWN"};
   }
   verb("Got exit status (oid $oid_exitcode) is ".$result->{$oid_exitcode});
   $retcode=$result->{$oid_exitcode};
}

$session->close();

# Fork process that will execute external command
if ($o_exec) {
   replace_macros(\@exec_args,\@files);
   verb("Command to be executed (after MACRO processing): ".join(' ',@exec_args));
   if (defined($o_stdout) || defined($o_tempfiles)) {
   	pipe(OUT_FROMPIPE, OUT_TOPIPE) or die "Could not create pipe - $!";
	pipe(IN_FROMPIPE, IN_TOPIPE) or die "Could not create pipe - $!";
	$pid = fork();
	if (!defined($pid)) {
		print "Error, could not do fork - $!";
		exit $ERRORS{"UNKNOWN"};
	}
   	if ($pid) {
	    close OUT_FROMPIPE;
	    close IN_TOPIPE;
	    if (defined($o_stdout)) {
	    	print OUT_TOPIPE "$_\n" foreach(@slines);
	    }
   	    close OUT_TOPIPE;
	    # and waitpid here
	    if (waitpid($pid,0)==-11) {
		print "ERROR - child process executing '".$exec_args[0]."' got killed\n";
		exit $ERRORS{"UNKNOWN"};
	    }
	    print $_ while(<IN_FROMPIPE>);
	    close IN_FROMPIPE;
	    $retcode = $? >> 8;
	    verb("Child exec terminated. Returned status is ".$retcode);
	    if ($o_tempfiles) {
		foreach my $fl (@files) {
			verb("Deleting temporary file $fl");
			if (!unlink($fl)) {
				# this is not an error, the called program
				# may have deleted the file already
				verb("Could not remove file $fl - $!");
			}
		}
	    }
	    # was: exit $retcode;
	    # the actual exit is now below and it checks for valid nagios exit code
   	}
   	else {
            verb("Replacing ourselve with external command (child thread):");
            verb(join(' ',@exec_args));
	    close OUT_TOPIPE;
	    close IN_FROMPIPE;
	    open(STDIN, "<&=".fileno(OUT_FROMPIPE)) or die "Could not redirect STDIN - $!";
	    # below will not work with embedded perl, so have to use dup2
	    # open(STDOUT, ">&=".fileno(IN_TOPIPE)) or die "Could not redirect STDOUT - $!";
	    dup2(fileno(IN_TOPIPE),1);
            if (!exec(@exec_args)) {
              print "ERROR - Could not execute '".join(' ',@exec_args)."' - $!\n";
              exit $ERRORS{"UNKNOWN"};
	    }
   	}
   }
   else {
	verb("Replacing ourselve with external command:");
	verb(' ',join(@exec_args));
	if (!exec(@exec_args)) {
	  print "ERROR - Could not execute '".join(' ',@exec_args)."' - $!\n";
	  exit $ERRORS{"UNKNOWN"};
	}
   }
}
elsif (defined($o_stdout)) {
	print "$_\n" foreach(@slines);
	if (!defined($retcode)) { exit $ERRORS{"OK"}; }
}

# In case of -S or --exec the plugin will exit with return code of another command
# but since this is a nagios plugin, I double-check its a valid return code
if (defined($retcode)) {
	for my $k (keys %ERRORS) {
		if ($ERRORS{$k} eq $retcode) {
			verb("Exiting with '".$k."' nagios status");
			exit $retcode;
		}
	}
	print "ERROR: The return code $retcode from program is not a nagios exit code\n";
	exit $ERRORS{"UNKNOWN"};
}

print "ERROR - something went wrong\n";
exit $ERRORS{"UNKNOWN"};
