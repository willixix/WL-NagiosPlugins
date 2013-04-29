#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_netsnmp_memory.pl
# Version : 0.21
# Date    : May 20, 2012
# Authors : William Leibzon - william@leibzon.org
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# ===================== INFORMATION ABOUT THIS PLUGIN =========================
#
# This plugin provides memory statistics data from NetSNMP and calculates percentage
# of used data based on amount of system/user memory as opposed to also including
# buffer/cache by default as other plugins do (which is a problem for heavily used
# servers where disk cache would end up using all unused memory). There is also
# very pretty and useful graph template available for nagiosgrapher for this plugin.
#
# This plugin also serves as an example of using check_snmp_attributes in a way
# where custom expression is written in an array defined in another plugin which
# then directly calls check_snmp_attributes
#
# ============================ EXAMPLES =======================================
#
# Drop this plugin into plugins directory together with check_snmp_attributes.pl
# If directory is sonething other than /usr/lib/nagios/plugins, make sure to modify
# code (closer to end of this file) to specify correct directory. THIS IS A MUST.
#
# Here is also an example for nagios config:
#
# define command {
#        command_name check_netsnmp_memory
#        command_line $USER1$/check_netsnmp_memory.pl -L "Memory Utilization" -A '*' -H $HOSTADDRESS$ -C readcommunity -a $ARG1$ -w $ARG2$ -c $ARG3$
# }
#
# define service{
#        use                             std-service
#        servicegroups                   snmp_data
#        hostgroup_name                  linux
#        service_description             Memory Utilization
#        check_command                   check_netsnmp_memory!'total,user,cached,buffer,%used_real,%used_swap,%user_real,%cached_real'!',,,500MB,,65%,65%,'!',,,800MB,,80%,80%,'
#        notification_options            c,u,r
#        }
#
# ============================= CHANGE HISTORY ===============================
#
# 0.1 - Spring (?) 2008 : Original version of this plugin, released only on my site
#			  in plugins subdirectory and never announced
# 0.15 - December 2011  : Plugin put on Nagios Exchange, documentation above added
# 0.2  - Jan 08,  2012  : Removed retrieval of shared memory as 2.6 kernel had it at 0
#			  and newest 3.0 kernel now report an error when asking for it
#			  If you have an older 2.4 kernel system, use 0.15 version
# 0.21 - May 20,  2012  : As has been pointed out, 1MB is 1024K and not 1000
#
# ========================== START OF PROGRAM CODE ===========================


my @expressions_netsnmpmem = (
        "total_free=snmp(1.3.6.1.4.1.2021.4.11.0),1024,/,round(1),' MB',+",	# Total free, data is reported in kb, we want MB
	"total_real=snmp(1.3.6.1.4.1.2021.4.5.0),1024,/,round(1),' MB',+",	# Total real memory
	"avail_real=snmp(1.3.6.1.4.1.2021.4.6.0),1024,/,round(1),' MB',+",	# Free real memory
	"total_swap=snmp(1.3.6.1.4.1.2021.4.3.0),1024,/,round(1),' MB',+", 	# Total swap
	"avail_swap=snmp(1.3.6.1.4.1.2021.4.4.0),1024,/,round(1),' MB',+",	# Free swap, here "MB" is added to the end as a string
	"min_swap=snmp(1.3.6.1.4.1.2021.4.12.0),1024,/,round(1),' MB',+",
	"buffer=snmp(1.3.6.1.4.1.2021.4.14.0),1024',/,round(1),' MB',+",	# In use buffer memory
	"cached=snmp(1.3.6.1.4.1.2021.4.15.0),1024,/,round(1),' MB',+",		# In use cached memory
	"total=total_real,total_swap,+,' MB [',.,total_real,.,' real ',.,total_swap,.,' swap : ',.,total_free,.,' free]',.",  # Total memory on the system (you can still use it as a number since everything after first few digits would be cut of for numeric calculations, also only number is reported in perf data; I should probably impliment printf function to make formatting and output easier...)
	"used_swap=total_swap,avail_swap,-,round(1),' MB',+",				# Swap memory in use
	'%avail_real=avail_real,total_real,%',					# Percent of available real memory
	'%used_real=total_real,avail_real,-,total_real,%',			# Percent of available memory in use
	'%avail_swap=avail_swap,total_swap,%',					# Percent of swap memory available
	'%used_swap=used_swap,total_swap,%',					# Percent of swap memory in use
	"user=total_real,avail_real,-,total_swap,+,avail_swap,-,buffer,-,cached,-,' MB',+", # Memory used by user (and system and kernel) processes
        '%user_real=user,total_real,%',			# Percent user processes take in relation to total real memory (can be >100%)
	'%cached_real=cached,total_real,%',		# Percent of user disk cache in relation to total real memory
	'%buffer_real=buffer,total_real,%',		# Percent of buffer memory in relation to total real
   );

use lib "/usr/lib/nagios/plugins";
require "check_snmp_attributes.pl";
process_expressions(@expressions_netsnmpmem);
run_plugin();
