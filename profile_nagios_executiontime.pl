#!/usr/bin/perl
#
# ============================== SUMMARY =====================================
#
# Program : profile_nagios_executiontime.pl
# Version : 0.21
# Date    : Jan 15, 2012
# Author  : William Leibzon - william@leibzon.org
# Summary : This is a nagios profiler to find which checks take longer
#           time to execute. Run it directly from unix shell, not as
#           a plugin. There are no parameters, but you may want to
#           change the file with path to your nagios status file
#           if its different than /var/log/nagios/status.dat
# Licence : GPL - summary below, text at http://www.fsf.org/licenses/gpl.txt
# Version History: 0.1 - November 2008 : original release for nagios 2.x
#		   0.2  - Dec 15, 2010 : support for nagios 3.0, simple summary header added
#		   0.21 - Jan 15, 2012 : if nagios is not running, don't give an exception
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
# ========================== START OF PROGRAM CODE ===========================

use strict;

my %service_data = ();
my %host_data = ();
my $file="/var/log/nagios/status.dat";

if (!open (FL, $file)) {
	print "Could not open file $file - $!";
	print "\nPerhaps Nagios is not running?\n";
	exit(1);
}
my $block="";
my $bdata;
while (<FL>) {
	if ( !$block && /\s*(\w+)\s+{/ ) {
		$block=$1;
		$bdata={};
	}
	elsif ( $block && /\s*}/) {
		if (($block eq "host" || $block eq "hoststatus") && defined($bdata->{'host_name'})) {
			$host_data{$bdata->{'host_name'}}=$bdata;
		}
		if (($block eq "service" || $block eq "servicestatus") && defined($bdata->{'host_name'}) && defined($bdata->{'service_description'})) {
			$service_data{$bdata->{'host_name'}.'_____'.$bdata->{'service_description'}}=$bdata;
		}
		$block="";
	}
	elsif ( $block && /\s*(\w+)=(.*)/ ) {
		$bdata->{$1}=$2;
	}
}
close(FL);

my %stats=('_all_'=>{tnum=>0,texec=>0});
my $host;
my $service;
foreach (sort { $service_data{$b}{check_execution_time} <=> $service_data{$a}{check_execution_time} } keys %service_data) {
	if ($service_data{$_}{active_checks_enabled}==1) {
		$host=$service_data{$_}{host_name};
		$service=$service_data{$_}{service_description};
		print "Host: $host Service: $service Check Time: ".$service_data{$_}{check_execution_time}."\n";
		$stats{_all_}{texec}+=$service_data{$_}{check_execution_time};
		$stats{_all_}{tnum}++;
		$stats{$service}={texec=>0,tnum=>0} if !defined($stats{$service});
		$stats{$service}{texec}+=$service_data{$_}{check_execution_time};
		$stats{$service}{tnum}++;
	}
}
print "\n";
if ($stats{'_all_'}{'tnum'}>0) {
  printf "Service: $_   Average Execution Time: %.3f (sec)  NumChecks: %d\n",($stats{$_}{texec}/$stats{$_}{tnum}),$stats{$_}{tnum} foreach (sort { $stats{$a}{texec}/$stats{$a}{tnum} <=> $stats{$b}{texec}/$stats{$b}{tnum} } keys %stats);
  printf "\nTotal Execution Time: %d (sec)   NumChecks: %d   Average Time: %.3f (sec)\n",$stats{'_all_'}{texec},$stats{'_all_'}{tnum},($stats{'_all_'}{texec}/$stats{'_all_'}{tnum});
}
else {
  print "\nCould find data on actively executed checks. Is your nagios configured and running?\n";
}
