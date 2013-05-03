<?php
# ================================ SUMMARY ====================================
#
# File    : check_redis.php
# Version : 0.1
# Date    : June 01, 2012
# Author  : William Leibzon - william@leibzon.org
# Summary : PNP4Nagios template for check_memcached.pl
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# This is considered a supplemental file to check_redis.pl plugin and though
# not distributed in unified package it is distributed under the same licencing
# terms (GNU 2.0 license). Any redisribution of this file in modified form must
# reproduce this summary (modified if appropriate) and must either include
# entire GNU license in a package or list URL where it can be found if
# distributed as a single file.
#
# ===================== INFORMATION ABOUT THIS TEMPLATE =======================
#
# This is a pnp4nagios template for redis database check done with check_redis.pl
# that would graph some status variables returned by this plugin.
#
# Unlike most templates this does not care which order variables are returned in
# and will automatically pick the right ones, so you can just use '-A' option
# from the plugin to return all performance variables (though in that case
# your rrd file will lager and contain extra datat that would not be graphed).
#
# Here is an example of nagios command config:
#
# define command {
#    command_name        check_redis_new
#    command_line        $USER1$/check_redis.pl -H $HOSTADDRESS$ -p $ARG1$ -T $ARG2$ -R -A -M $_HOSTSYSTEM_MEMORY$ -m $ARG3$ -a $ARG4$ -w $ARG5$ -c $ARG6$ -f -P "$SERVICEPERFDATA$"
# }
#
# Arguments and thresholds are:
#  $ARG1 : Port
#  $ARG2 : response time thresholds
#  $ARG3 : memory utilization thresholds
#  $ARG4 : additional variables to be checked
#  $ARG5 : warning thresholds for those variables
#  $ARG6 : critical thresholds for those variables
#
# define service {
#        use                     prod-service
#        hostgroups              redishosts
#        service_description     Redis
#        check_command           check_redis_new!6379!"1,2"!"80,90"!blocked_clients,connected_clients!50,~!100,~
# }
#
# define host {
#         use             prod-server
#         host_name       redis.mynetwork
#         address         redis.mynetwork
#         alias           Redis Stat Server
#         hostgroups      linux,redishosts
#        _SYSTEM_MEMORY  '8G'
# }
#
# ========================= VERSION HISTORY and TODO ==========================
#
# v0.1  - 05/31/2012 : Initial version of the template created. Includes the following:
#			1. Response Times Graph
#			2. Client Connections Graph
#			3. Hits and Misses
#			4. Keys Graph
#			5. Memory Graph
#			6. CPU Usage (this maybe wrong, showing too high)
#
# =============================== END OF HEADER ===============================

$VAR = array(	'total_connections_received' => -1,	# Connections Graph: connections/sec
		'used_memory_rss' => -1,		# Memory Graph: Current memory RSS
		'used_cpu_sys' => -1,			# CPU Load Graph: System, Main Thread
		'connected_clients' => -1,		# Connections Graph: connections now
		'keyspace_hits' => -1,			# Hits and Misses Graph:  hits
		'used_cpu_user_children' => -1,	 	# CPU Load Graph: User, Child Threads
		'keyspace_misses' => -1,		# Hits and Misses graph: misses
		'used_cpu_user' => -1,			# CPU Load Graph: User, Main Thread
		'total_commands_processed' => -1,	# Commands Processed Graph ?
		'mem_fragmentation_ratio' => -1,	# Memory Fragmentation Graph ?
		'used_memory' => -1,			# Memory Graph: Used Memory
		'blocked_clients' => -1,		# Connections Graph: blocked clients
		'expired_keys' => -1,			# Keys Graph: expired keys
		'used_memory_peak' => -1,		# Memory Graph: Memory Peak
		'used_cpu_sys_children' => -1,		# CPU Load Graph: System, Child Threads
		'evicted_keys' => -1,			# Keys Graphs: evicted keys
		'response_time' => -1,			# Respose Time Graph
		'total_keys' => -1,			# Keys Graph: total Keys
		'total_expires' => -1,			# Keys Graph: total_expires
		'memory_utilization' => -1		# Memory Graph: %mem_use
	    );

foreach ($this->DS as $KEY=>$VAL) {
	if (isset($VAR[$VAL['LABEL']])) {
		$VAR[$VAL['LABEL']] = $VAL['DS'];
	}
}

$gindex=0;

if ($VAR['response_time'] != -1) {
  $vindex=$VAR['response_time'];
  $unit=$UNIT[$vindex];
  $ds_name[$gindex] = "Redis Response Time";
  $opt[$gindex] = "--vertical-label \"$unit\" --title \"$servicedesc Response Time on $hostname \" --slope-mode --color=BACK#000000 --color=FONT#F7F7F7 --color=SHADEA#ffffff --color=SHADEB#ffffff --color=CANVAS#000000 --color=GRID#00991A --color=MGRID#00991A --color=ARROW#FF0000 ";
  $def[$gindex] =  rrd::def("var1", $RRDFILE[$vindex], $DS[$vindex], "AVERAGE");
  $def[$gindex] .= "VDEF:slope=var1,LSLSLOPE " ;
  $def[$gindex] .= "VDEF:int=var1,LSLINT " ;
  $def[$gindex] .= "CDEF:proj=var1,POP,slope,COUNT,*,int,+ " ;
  $def[$gindex] .= "LINE2:proj#ff00ff:\"Projection \" " ;
  $def[$gindex] .= "GPRINT:var1:LAST:\"%6.2lf$unit last\" " ;
  $def[$gindex] .= "GPRINT:var1:AVERAGE:\"%6.2lf$unit avg\" " ;
  $def[$gindex] .= "GPRINT:var1:MAX:\"%6.2lf$unit max\\n\" ";
  $def[$gindex] .= "CDEF:sp1=var1,100,/,10,* " ;
  $def[$gindex] .= "CDEF:sp2=var1,100,/,20,* " ;
  $def[$gindex] .= "CDEF:sp3=var1,100,/,30,* " ;
  $def[$gindex] .= "CDEF:sp4=var1,100,/,40,* " ;
  $def[$gindex] .= "CDEF:sp5=var1,100,/,50,* " ;
  $def[$gindex] .= "CDEF:sp6=var1,100,/,60,* " ;
  $def[$gindex] .= "CDEF:sp7=var1,100,/,70,* " ;
  $def[$gindex] .= "CDEF:sp8=var1,100,/,80,* " ;
  $def[$gindex] .= "CDEF:sp9=var1,100,/,90,* " ;
  $def[$gindex] .= "AREA:var1#0000A0:\"Response Time \" " ;
  $def[$gindex] .= "AREA:sp9#0000A0: " ;
  $def[$gindex] .= "AREA:sp8#0000C0: " ;
  $def[$gindex] .= "AREA:sp7#0010F0: " ;
  $def[$gindex] .= "AREA:sp6#0040F0: " ;
  $def[$gindex] .= "AREA:sp5#0070F0: " ;
  $def[$gindex] .= "AREA:sp4#00A0F0: " ;
  $def[$gindex] .= "AREA:sp3#00D0F0: " ;
  $def[$gindex] .= "AREA:sp2#A0F0F0: " ;
  $def[$gindex] .= "AREA:sp1#F0F0F0: " ;
  $gindex++;
}

if ($VAR['total_connections_received'] != -1 ||
    $VAR['connected_clients'] != -1 ||
    $VAR['blocked_clients'] != -1) {
  $vindex_totalconnections=$VAR['total_connections_received'];
  $vindex_connectedclients=$VAR['connected_clients'];
  $vindex_blockedclients=$VAR['blocked_clients'];
  $ds_name[$gindex] = "Redis Client Connections";
  $opt[$gindex] = "--lower-limit=0 --vertical-label \"connections\" --title \"$servicedesc Connections to $hostname\" ";
  $def[$gindex] = "";
  if ($vindex_connectedclients!=-1) {
	$def[$gindex] .= rrd::def("curr_conn", $RRDFILE[$vindex_connectedclients], $DS[$vindex_connectedclients], "AVERAGE");
	$def[$gindex] .= rrd::area("curr_conn", "#00FF00", "Current Number of Connections");
	$def[$gindex] .= rrd::gprint("curr_conn", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
  }
  if ($vindex_totalconnections!=-1) {
	$def[$gindex] .= rrd::def("conn_rate", $RRDFILE[$vindex_totalconnections], $DS[$vindex_totalconnections], "AVERAGE");
	$def[$gindex] .= rrd::line1("conn_rate", "#0000FF", "New Connnections Per Second  ");
	$def[$gindex] .= rrd::gprint("conn_rate", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
  }
  if ($vindex_blockedclients!=-1) {
	$def[$gindex] .= rrd::def("blocked_clients", $RRDFILE[$vindex_blockedclients], $DS[$vindex_blockedclients], "AVERAGE");
	$def[$gindex] .= rrd::line1("blocked_clients", "#FF0000", "Blocked Client Connections   ");
	$def[$gindex] .= rrd::gprint("blocked_clients", array("LAST","MAX","AVERAGE"), "%3.0lf ");
  }
  $gindex++;
}

if ($VAR['keyspace_hits'] != -1 && $VAR['keyspace_misses'] != -1) {
  $vindex_hits=$VAR['keyspace_hits'];
  $vindex_misses=$VAR['keyspace_misses'];
  $ds_name[$gindex] = "Redis Hits and Misses";
  $opt[$gindex] = "--lower-limit=0 --vertical-label \"hits and misses\" --title \"$servicedesc Hits and Misses on $hostname\" ";
  $def[$gindex] = rrd::def("get_hits", $RRDFILE[$vindex_hits], $DS[$vindex_hits], "AVERAGE");
  $def[$gindex] .= rrd::def("get_misses", $RRDFILE[$vindex_misses], $DS[$vindex_misses], "AVERAGE");
  $def[$gindex] .= rrd::area("get_hits", "#00FF00", "Hits     ");
  $def[$gindex] .= rrd::gprint("get_hits", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
  $def[$gindex] .= rrd::area("get_misses", "#FF0000", "Misses   ", "STACK");
  $def[$gindex] .= rrd::gprint("get_misses", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
  $def[$gindex] .= rrd::cdef("hitrate", "get_hits,get_hits,get_misses,+,/,100,*");
  $def[$gindex] .= rrd::comment("- Hit Rate ");
  $def[$gindex] .= rrd::gprint("hitrate", array("LAST", "MAX", "AVERAGE"), "%.2lf%% ");
  $gindex++;
}

if ($VAR['total_keys'] != -1 && $VAR['total_expires'] != -1) {
  $vindex_expiredkeys=$VAR['expired_keys'];
  $vindex_evictedkeys=$VAR['evicted_keys'];
  $vindex_totalkeys=$VAR['total_keys'];
  $vindex_totalexpires=$VAR['total_expires'];
  $ds_name[$gindex] = "Redis Keys Store";
  $opt[$gindex] = "--lower-limit=0 --vertical-label \"keys\" --title \"$servicedesc Keys on $hostname\" ";
  $def[$gindex] = rrd::def("total_keys", $RRDFILE[$vindex_totalkeys], $DS[$vindex_totalkeys], "AVERAGE");
  $def[$gindex] .= rrd::def("total_expires", $RRDFILE[$vindex_totalexpires], $DS[$vindex_totalexpires], "AVERAGE");
  $def[$gindex] .= rrd::area("total_keys", "#6495ED", "Total Keys ");
  $def[$gindex] .= rrd::gprint("total_keys", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
  $def[$gindex] .= rrd::area("total_expires", "#00FFFF", "Will Expire", "");
  $def[$gindex] .= rrd::gprint("total_expires", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
  if ($vindex_expiredkeys!=-1) {
	$def[$gindex] .= rrd::def("expired_keys", $RRDFILE[$vindex_expiredkeys], $DS[$vindex_expiredkeys], "AVERAGE");
	$def[$gindex] .= rrd::line1("expired_keys", "#00FF00", "Expired   ", "");
	$def[$gindex] .= rrd::gprint("expired_keys", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
  }
  if ($vindex_evictedkeys!=-1) {
        $def[$gindex] .= rrd::def("evicted_keys", $RRDFILE[$vindex_evictedkeys], $DS[$vindex_evictedkeys], "AVERAGE");
        $def[$gindex] .= rrd::line1("evicted_keys", "#FF0000", "Evicted   ", "");
        $def[$gindex] .= rrd::gprint("evicted_keys", array("LAST", "MAX", "AVERAGE"), "%3.0lf ");
  }
  $gindex++;
}

if ($VAR['used_memory'] != -1 && $VAR['used_memory_peak']) {
  $vindex_usedmemory=$VAR['used_memory'];
  $vindex_memorypeak=$VAR['used_memory_peak'];
  $vindex_memoryrss=$VAR['used_memory_rss'];
  $vindex_fragmentation=$VAR['mem_fragmentation_ratio'];
  $vindex_utilization=$VAR['memory_utilization'];
  $ds_name[$gindex] = "Redis Memory";
  $opt[$gindex]  = "--lower-limit=0 --vertical-label \"MB\" --title \"$servicedesc Memory Use on $hostname\" ";
  $def[$gindex]  = rrd::def("bytes", $RRDFILE[$vindex_usedmemory], $DS[$vindex_usedmemory], "AVERAGE");
  $def[$gindex] .= rrd::def("maxbytes", $RRDFILE[$vindex_memorypeak], $DS[$vindex_memorypeak], "AVERAGE");
  $def[$gindex] .= rrd::cdef("use_mb", "bytes,1024,/,1024,/");
  $def[$gindex] .= rrd::cdef("maxuse_mb", "maxbytes,1024,/,1024,/");
  $def[$gindex] .= rrd::cdef("mfree_mb", "maxbytes,bytes,-,1024,/,1024,/");
  $def[$gindex] .= rrd::area("use_mb", "#00FFFF", "Used Memory     ");
  $def[$gindex] .= "GPRINT:use_mb:LAST:\"%6.1lfMB Last \" " ;
  $def[$gindex] .= "GPRINT:use_mb:MAX:\"%6.1lfMB Max \" " ;
  $def[$gindex] .= "GPRINT:use_mb:AVERAGE:\"%6.1lfMB Avg \\n\" " ;
  $def[$gindex] .= rrd::line1("maxuse_mb", "#0000FF", "Max Used Memory ");
  $def[$gindex] .= "GPRINT:maxuse_mb:LAST:\"%6.1lfMB Last \" " ;
  $def[$gindex] .= "GPRINT:maxuse_mb:MAX:\"%6.1lfMB Max \" " ;
  $def[$gindex] .= "GPRINT:maxuse_mb:AVERAGE:\"%6.1lfMB Avg \\n\" " ;
  if ($vindex_memoryrss!=-1) {
        $def[$gindex] .= rrd::def("memoryrss", $RRDFILE[$vindex_memoryrss], $DS[$vindex_memoryrss], "AVERAGE");
        $def[$gindex] .= rrd::cdef("memrss_mb", "memoryrss,1024,/,1024,/");
	$def[$gindex] .= rrd::cdef("fragmented_mb", "memrss_mb,use_mb,-");
        $def[$gindex] .= rrd::area("fragmented_mb", "#FFD700", "Allocated Memory", "STACK");
	if ($vindex_utilization!=-1) {
		$def[$gindex] .= rrd::def("use_perc", $RRDFILE[$vindex_utilization], $DS[$vindex_utilization], "AVERAGE");
		$def[$gindex] .= rrd::cdef("free_perc", "100,use_perc,-");
		$def[$gindex] .= rrd::cdef("total_mb", "memrss_mb,use_perc,/,100,*");
		$def[$gindex] .= rrd::cdef("free_mb", "total_mb,memrss_mb,-");
		$def[$gindex] .= "GPRINT:memrss_mb:LAST:\"%6.1lfMB \g\" " ;
		$def[$gindex] .= "GPRINT:use_perc:LAST:\" (%2.1lf%%) Last\" " ;
		$def[$gindex] .= "GPRINT:memrss_mb:MAX:\"%6.1lfMB \g\" " ;
		$def[$gindex] .= "GPRINT:use_perc:MAX:\" (%2.1lf%%) Max\" " ;
		$def[$gindex] .= "GPRINT:memrss_mb:AVERAGE:\"%6.1lfMB \g\" " ;
		$def[$gindex] .= "GPRINT:use_perc:AVERAGE:\" (%2.1lf%%) Avg\\n\" " ;
        	$def[$gindex] .= rrd::cdef("fragmentation_calc", "memrss_mb,use_mb,/");
        	$def[$gindex] .= rrd::comment("* Fragmentation Ratio (Allocated/Used) is \g");
		if ($vindex_fragmentation!=-1) {
			$def[$gindex] .= rrd::def("fragmentation_data", $RRDFILE[$vindex_fragmentation], $DS[$vindex_fragmentation], "AVERAGE");
			$def[$gindex] .= "GPRINT:fragmentation_calc:LAST:\" %2.2lf \g\" ";
        		$def[$gindex] .= "GPRINT:fragmentation_data:LAST:\" (actual %2.2lf)\\n\" ";
		}
		else {
			$def[$gindex] .= "GPRINT:fragmentation_calc:LAST:\"%2.2lf\\n\" ";
		}		
		$def[$gindex] .= rrd::area("free_mb", "#00FF00", "Free Memory ", "STACK");
		$def[$gindex] .= "GPRINT:free_mb:LAST:\"%6.1lfMB \g\" " ;
		$def[$gindex] .= "GPRINT:free_perc:LAST:\" (%2.1lf%%) Last\" " ;
		$def[$gindex] .= "GPRINT:free_mb:MAX:\"%6.1lfMB \g\" " ;
		$def[$gindex] .= "GPRINT:free_perc:MAX:\" (%2.1lf%%) Max\" " ;
		$def[$gindex] .= "GPRINT:free_mb:AVERAGE:\"%6.1lfMB \g\" " ;
		$def[$gindex] .= "GPRINT:free_perc:AVERAGE:\" (%2.1lf%%) Avg\\n\" " ;
		$def[$gindex] .= rrd::comment("= Total Memory");
		$def[$gindex] .= "GPRINT:total_mb:LAST:\"%6.1lfMB\\n\" ";
	}
	else {
	        $def[$gindex] .= "GPRINT:memrss_mb:LAST:\"%6.1lfMB Last \" " ;
		$def[$gindex] .= "GPRINT:memrss_mb:MAX:\"%6.1lfMB Max \" " ;
		$def[$gindex] .= "GPRINT:memrss_mb:AVERAGE:\"%6.1lfMB Avg \\n\" " ;
	}
  }
  $gindex++;
}

if ($VAR['used_cpu_sys'] != -1) {
  $vindex_cpumain_sys=$VAR['used_cpu_sys'];
  $vindex_cpumain_user=$VAR['used_cpu_user'];
  $vindex_cpuchild_sys=$VAR['used_cpu_sys_children'];
  $vindex_cpuchild_user=$VAR['used_cpu_user_children'];
  $ds_name[$gindex] ="CPU Use";
  $opt[$gindex]  = "--vertical-label \"cpu time in msec\" --title \"$servicedesc CPU Use on $hostname\" ";
  $def[$gindex]  = rrd::def("cpu_main_sys", $RRDFILE[$vindex_cpumain_sys], $DS[$vindex_cpumain_sys], "AVERAGE");
  $def[$gindex] .= rrd::area("cpu_main_sys", "#FF6103", "System CPU - Main Thread");
  $def[$gindex] .= rrd::gprint("cpu_main_sys", array("LAST","MAX","AVERAGE"), "%6.2lf ");
  if ($vindex_cpuchild_sys!=-1) {
    $def[$gindex] .= rrd::def("cpu_child_sys", $RRDFILE[$vindex_cpuchild_sys], $DS[$vindex_cpuchild_sys], "AVERAGE");
    $def[$gindex] .= rrd::area("cpu_child_sys", "#FFD700", "System CPU - Children   ", "STACK");
    $def[$gindex] .= rrd::gprint("cpu_child_sys", array("LAST","MAX","AVERAGE"), "%6.2lf ");
  }
  if ($vindex_cpumain_user!=-1) {
    $def[$gindex] .= rrd::def("cpu_main_user", $RRDFILE[$vindex_cpumain_user], $DS[$vindex_cpumain_user], "AVERAGE");
    $def[$gindex] .= rrd::area("cpu_main_user", "#008000", "User CPU   - Main Thread", "STACK");
    $def[$gindex] .= rrd::gprint("cpu_main_user", array("LAST","MAX","AVERAGE"), "%6.2lf ");
  }
  if ($vindex_cpuchild_user!=-1) {
    $def[$gindex] .= rrd::def("cpu_child_user", $RRDFILE[$vindex_cpuchild_user], $DS[$vindex_cpuchild_user], "AVERAGE");
    $def[$gindex] .= rrd::area("cpu_child_user", "#00FF00", "User CPU   - Children   ", "STACK");
    $def[$gindex] .= rrd::gprint("cpu_child_user", array("LAST","MAX","AVERAGE"), "%6.2lf ");
  }
  $gindex++;
}

?>
