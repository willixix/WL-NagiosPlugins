<?php
# ================================ SUMMARY ====================================
#
# File    : check_mysqld.php
# Version : 0.3
# Date    : Mar 10, 2012
# Author  : William Leibzon - william@leibzon.org
# Summary : PNP4Nagios template for mysql database check done with check_mysqld.pl
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
#
# This is considered a supplemental file to check_mysqld.pl plugin and though
# not distributed in unified package it is distributed under the same licencing
# terms (GNU 2.0 license). Any redisribution of this file in modified form must
# reproduce this summary (modified if appropriate) and must either include
# entire GNU license in a package or list URL where it can be found if
# distributed as a single file.
#
# ===================== INFORMATION ABOUT THIS TEMPLATE =======================
#
# This is a pnp4nagios template for mysql database check done with check_mysqld.pl
#
# The template tries to graph number of MYSQL variables returned with "SHOW STATUS"
# (for mysql 5.x - "SHOW GLOBAL STATUS") which are described at:
# http://dev.mysql.com/doc/refman/4.1/en/server-status-variables.html
#
# The template was originally created for ngrapher and is in process being ported
# to pnp4nagios. Below metrics are available with check_mysqld.ncfg template,
# while not all may not be available with this version, these would eventually
# all be available with PNP4Nagios too:
#
# 1. Queries (rate of queries being processed)
#  This is shows how many DELETE, INSERT, UPDATE and SELECT queries are processed.
#  For select it also tries to show how many queries are being answered with data
#  from cache and for those that are causing db read it shows if query causes
#  cache to be updated or not. This mysql documentation page explains a little
#  about qcache variables and totals for SELECT queries:
#    http://dev.mysql.com/doc/refman/4.1/en/query-cache-status-and-maintenance.html
# 2. Data Traffic (in MB/sec)
#  No explantion needed - just your typical network traffic graph.
# 3. Connections and Threads
#  Current number of connections to the server, maximum number of connections
#  and number threads in use.
# 4. Tables and Files
#  Number of open files, open tables. Number of temp files & tables created.
#  Also Number of table locks per second.
# 5. Errors and Issues
#  Various parameters (far from all possible to be retrieved) that indicate a problem -
#  all should be 0 or close to it. Rate of slow queries are one of the probably most
#  well known and tracked of the variables graphed.
# 6. Key Cache Efficiency
#  This is based on key_ variables and supposed to indicate percent of key requests
#  queries that are answered from memory. For more info see comment under 'key_reads'
#  variable from mysql documentation page on how to calculate "cache miss rate".
#  Efficiency percent I show is just 100%-cache_miss%.
# 7. Key Cache Data
#  Raw data used in calculating efficiency. This is graphed separately to track total
#  number of requests.
# 8. Handler Row Requests
#  This tracks requests for next row, previous row and associated update/delete/insert
#  row requests that you do when keeping open handle. This is probably very interesting data,
#  but I do not entirely understand it and I also have a feeling numbers shown are too high
# 9. Query Cache Memory
#  This will show used and free blocks and total number of queries in cache.
# 10. Query Cache Hits
#  Number of hits and update of query cache. Most of these numbers are already shown as part
# 11. Binlog Cache Transactions
#  Graphed are binlog_cache_use and binlog_cache_disk_use variables.
#
# ============================= SETUP NOTES ====================================
#
# 1. Copy this template pnp4nagios's templates directory
# 2. Make sure you specify all attributes as below listed under
#    '$USER21$' as a '-A' parameter to check_mysqld.pl plugin
# 3. Make sure you have copy of nagios that accepts without being
#    cut performance data of up to 1500 bytes (best 2k) in size
#    ('threads_running=??' should be the last performance variable seen
#    under 'Performance Data:" in nagios 'Service State Information')
#
# For reference the following is how I defined mysql check in nagios commands config:
#   define command{
#        command_name    check_mysql
#        command_line    $USER1$/check_mysqld.pl -H $HOSTADDRESS$ -u nagios -p $USER7$ -a uptime,threads_connected,questions,slow_queries,open_tables -w ',,,,' -c ',,,,' -A $USER21$
#        }
# This service definition is just:
#   define  service{
#        use                             db-service
#        servicegroups                   dbservices
#        hostgroup_name                  mysql
#        service_description             MySQL
#        check_command                   check_mysql
#        }
# And most important (for the graphing) my resource.cfg has the following:
#   # Mysql 'nagios' user password
#   $USER7$=public_example
#
#   # List of variables to be retrieved for mysqld (here mostly for convinience so as not to put in commmands.cfg)
#   $USER21$='com_commit,com_rollback,com_delete,com_update,com_insert,com_insert_select,com_select,qcache_hits,qcache_inserts,qcache_not_cached,questions,bytes_sent,bytes_received,aborted_clients,aborted_connects,binlog_cache_disk_use,binlog_cache_use,connections,created_tmp_disk_tables,created_tmp_files,created_tmp_tables,delayed_errors,delayed_insert_threads,delayed_writes,handler_update,handler_write,handler_delete,handler_read_first,handler_read_key,handler_read_next,handler_read_prev,handler_read_rnd,handler_read_rnd_next,key_blocks_not_flushed,key_blocks_unused,key_blocks_used,key_read_requests,key_reads,key_write_requests,key_writes,max_used_connections,not_flushed_delayed_rows,open_files,open_streams,open_tables,opened_tables,prepared_stmt_count,qcache_free_blocks,qcache_free_memory,qcache_lowmem_prunes,qcache_queries_in_cache,qcache_total_blocks,select_full_join,select_rangle_check,slow_launch_threads,slow_queries,table_locks_immediate,table_locks_waited,threads_cached,threads_connected,threads_created,threads_running'
#
# -----------------------------------------------------------------------------
#
# You will need nagios with larger buffers (as compared to usual 2.x distrubutions)
# for storing performance variables in order to fully utilize this template.
# Doing so requires recompile after modifying MAX_INPUT_BUFFER, MAX_COMMAND_BUFFER,
# MAX_PLUGINOUTPUT_LENGTH which are defined in objects.h and common.h.
# Patches for some versions of nagios is available at
#   http://william.leibzon.org/nagios/
#
# ========================= VERSION HISTORY and TODO ==========================
#
# v0.2  - 01/02/2008 : This is initial public release of nagiosgrapher template
# v0.21 - 01/03/2008 : Fixed bug in calculation of total number of queries
# v0.22 - 12/19/2011 : Changed so that first STACK is an AREA.
# v0.3  - 03/10/2012 : The first version of template for PNP4Nagios
# v0.31 - 03/20/2012 : Updated network traffic to be Mb/sec
#
# TODO: a. Testing under newest 5.x and 6.0 alpha versions of mysql
#       b. Better documentation of what graphed data means.
#       c. Information from mysql developers about 'handler' data
#          and confirmation that it is being displayed properly
#
# =============================== END OF HEADER ===============================

$ds_name[1] = "SQL Queries";
$opt[1]  = "--height=250 --vertical-label \"commands/sec\" -b 1000 --title \"SQL Queries on $hostname\" ";

$def[1]  = "DEF:com_commit=$RRDFILE[1]:$DS[1]:AVERAGE " ;
$def[1] .= "DEF:com_rollback=$RRDFILE[2]:$DS[2]:AVERAGE " ;
$def[1] .= "DEF:com_delete=$RRDFILE[3]:$DS[3]:AVERAGE ";
$def[1] .= "DEF:com_update=$RRDFILE[4]:$DS[4]:AVERAGE ";
$def[1] .= "DEF:com_insert=$RRDFILE[5]:$DS[5]:AVERAGE ";
$def[1] .= "DEF:com_insert_select=$RRDFILE[6]:$DS[6]:AVERAGE ";
$def[1] .= "DEF:com_select=$RRDFILE[7]:$DS[7]:AVERAGE ";
$def[1] .= "DEF:qc_hits=$RRDFILE[8]:$DS[8]:AVERAGE ";		# qcache_hits
$def[1] .= "DEF:qc_inserts=$RRDFILE[9]:$DS[9]:AVERAGE ";	# qcache_inserts
$def[1] .= "DEF:qc_not_cached=$RRDFILE[10]:$DS[10]:AVERAGE ";	# qcache_not_cached
$def[1] .= "DEF:questions=$RRDFILE[11]:$DS[11]:AVERAGE ";

$def[1] .= "AREA:com_commit#DDA0DD:\"Commit Commands\: \t\t\g\" " ;
$def[1] .= "GPRINT:com_commit:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:com_commit:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:com_commit:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "AREA:com_rollback#FF8C00:\"Rollback Commands\: \t\t\g\":STACK " ;
$def[1] .= "GPRINT:com_rollback:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:com_rollback:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:com_rollback:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "AREA:com_delete#8B4513:\"Delete Commands\: \t\t\g\":STACK " ;
$def[1] .= "GPRINT:com_delete:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:com_delete:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:com_delete:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "AREA:com_update#FF1493:\"Update Commands\: \t\t\g\":STACK " ;
$def[1] .= "GPRINT:com_update:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:com_update:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:com_update:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "AREA:com_insert#1E90FF:\"Insert Commands\: \t\t\g\":STACK " ;
$def[1] .= "GPRINT:com_insert:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:com_insert:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:com_insert:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "AREA:com_insert_select#00FFFF:\"Insert_Select Commands\: \t\g\":STACK " ;
$def[1] .= "GPRINT:com_insert_select:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:com_insert_select:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:com_insert_select:MAX:\"%6.1lf max\\n\" " ;
$def[1] .= "COMMENT:\"\s\" ";

$def[1] .= "CDEF:select_graph=com_select,qc_inserts,-,qc_not_cached,- ";
$def[1] .= "AREA:select_graph#7FFF00:\"Select - from DB\: \t\t\g\":STACK " ;
$def[1] .= "GPRINT:com_select:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:com_select:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:com_select:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "AREA:qc_not_cached#32CD32:\"- of that not cached\: \t\g\":STACK " ;
$def[1] .= "GPRINT:qc_not_cached:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:qc_not_cached:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:qc_not_cached:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "AREA:qc_inserts#98FB98:\"- of that added to cache\: \t\g\":STACK " ;
$def[1] .= "GPRINT:qc_inserts:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:qc_inserts:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:qc_inserts:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "AREA:qc_hits#F0E68C:\"Select - from Cache\: \t\g\":STACK " ;
$def[1] .= "GPRINT:qc_hits:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:qc_hits:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:qc_hits:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "CDEF:com_select_total=com_select,qc_hits,+ ";
$def[1] .= "GPRINT:com_select_total:LAST:\"= Total Select Queries\: \t%6.1lf last\" " ;
$def[1] .= "GPRINT:com_select_total:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:com_select_total:MAX:\"%6.1lf max\\n\" " ;
$def[1] .= "COMMENT:\"\s\" ";

$def[1] .= "CDEF:queries_nocache=questions,qc_hits,- ";
$def[1] .= "LINE1:queries_nocache#696969:\"All DB Queries (except cache hits)\: \t\g\" " ;
$def[1] .= "GPRINT:queries_nocache:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:queries_nocache:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:queries_nocache:MAX:\"%6.1lf max\\n\" " ;

$def[1] .= "LINE1:questions#000000:\"All Questions (counting cache hits)\: \t\g\" " ;
$def[1] .= "GPRINT:questions:LAST:\"%6.1lf last\" " ;
$def[1] .= "GPRINT:questions:AVERAGE:\"%6.1lf avg\" " ;
$def[1] .= "GPRINT:questions:MAX:\"%6.1lf max\\n\" " ;

$ds_name[2] = "Data Traffic";
$opt[2]  = " --vertical-label \"bits/sec\" -b 1000 --title \"DB Net Traffic on $hostname\" ";

$def[2]  = "DEF:bytes_sent=$RRDFILE[12]:$DS[12]:AVERAGE ";
$def[2] .= "DEF:bytes_received=$RRDFILE[13]:$DS[13]:AVERAGE ";

$def[2] .= "CDEF:out_bits=bytes_sent,8,* ";
$def[2] .= "AREA:out_bits#00ff00:\"out \" " ;
$def[2] .= "GPRINT:out_bits:LAST:\"%7.2lf %Sbit/s last\" " ;
$def[2] .= "GPRINT:out_bits:AVERAGE:\"%7.2lf %Sbit/s avg\" " ;
$def[2] .= "GPRINT:out_bits:MAX:\"%7.2lf %Sbit/s max\\n\" ";

$def[2] .= "CDEF:in_bits=bytes_received,8,* ";
$def[2] .= "LINE1:in_bits#0000ff:\"in  \" " ;
$def[2] .= "GPRINT:in_bits:LAST:\"%7.2lf %Sbit/s last\" " ;
$def[2] .= "GPRINT:in_bits:AVERAGE:\"%7.2lf %Sbit/s avg\" " ;
$def[2] .= "GPRINT:in_bits:MAX:\"%7.2lf %Sbit/s max\\n\" " ;

?>
