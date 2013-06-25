<?php
#
# Copyright (c) 2011-2013 William Leibzon (http://william.leibzon.org/nagios/)
#
# This is PNP4Nagios template for check_linux_procstat.pl nagios plugin
# The plugin reads /proc/stat and gives out its content as performance data:
#
# CPU data is cpu_???? for all cpu together and cpu?_???? for specific core
# csum_???? is sum from all cpu?_ cores which replaces cpu_?? if its different
# 
# Some additional data are memory and swap operations (not in for later 2.6 kernel),
# interrupts and context switches, processes forking and blocked processes stats
# 
# Version History:
#  0.1 (2011) - Original Template for CPUs Utilization Stats
#  0.2 (Jan 2012) - Added interrupts/context-switches & blocked processes graphs
#  0.3 (Jun 2013) - Patch by Franky Van Liedekerke sent through github that makes
#                   this template work properly with RRD_STORAGE_TYPE = MULTIPLE
#                   See https://github.com/willixix/WL-NagiosPlugins/issues/30

$CORE = array();
foreach ($this->DS as $KEY=>$VAL) {
    $cpunum=-1;
    if (preg_match('/cpu_(.*)/', $VAL['LABEL'], $matches)) {
        $cpunum=0;
        $cpuparam=$matches[1];
    }
    else if (preg_match('/cpu(\d*)_(.*)/', $VAL['LABEL'], $matches)) {
        $cpunum=$matches[1]+1;
        $cpuparam=$matches[2];
    }
    if ($cpunum != -1) {
        if (!isset($CORE[$cpunum])) $CORE[$cpunum]=array();
        $CORE[$cpunum][$cpuparam]= $VAL;
    }
    if ($VAL['LABEL'] == 'num_intr') {
        $num_intr = $VAL;
    }
    if ($VAL['LABEL'] == 'ctxt') {
        $ctxt = $VAL;
    }
    if ($VAL['LABEL'] == 'processes') {
        $processes = $VAL;
    }
    if ($VAL['LABEL'] == 'procs_blocked') {
        $procs_blocked = $VAL;
    }
    if ($VAL['LABEL'] == 'procs_running') {
        $procs_running = $VAL;
    }
    if ($VAL['LABEL'] == 'swap_paged_in') {
        $swap_paged_in = $VAL;
    }
    if ($VAL['LABEL'] == 'swap_paged_out') {
        $swap_paged_out = $VAL;
    }
    if ($VAL['LABEL'] == 'data_paged_in') {
        $data_paged_in = $VAL;
    }
    if ($VAL['LABEL'] == 'data_paged_out') {
        $data_paged_out = $VAL;
    }
}

# Go through all CPUs and prepare graphs
for ($i=0; $i<count($CORE); $i++) {
    $gkey = $i;
    $pre = '';
    $unm = '';
    if ($i==0) {
        $opt[$gkey] = '--vertical-label Percent --title "Total for all CPUs on ' . $this->MACRO['DISP_HOSTNAME']. '"  --upper=101 --lower=0';
        $ds_name[$gkey] = "Total for All CPUs"; 
        $pre = 'percent_';
        $unm = '%2.1lf%% ';
    }
    else {  
        $opt[$gkey] = '--vertical-label "jiffs/sec" --title "CPU Core '. ($i-1) . ' on '. $this->MACRO['DISP_HOSTNAME'].'" --lower=0';
        $ds_name[$gkey] = 'CPU Core '.($i-1);
        $unm = '%6.2lf ';
    }

    $def[$gkey] = '';

    foreach ($CORE[$i] as $K=>$V) {
        $def[$gkey] .= rrd::def($K, $V['RRDFILE'], $V['DS'], "AVERAGE");
    }

    $def[$gkey] .= rrd::cdef("total", "idle,nice,+,user,+,system,+,iowait,+,irq,+,softirq,+");
    $def[$gkey] .= rrd::cdef("percent_used", "total,idle,-,total,/,100,*");
    $def[$gkey] .= rrd::cdef("percent_idle", "idle,total,/,100,*");
    $def[$gkey] .= rrd::cdef("percent_nice", "nice,total,/,100,*");
    $def[$gkey] .= rrd::cdef("percent_user", "user,total,/,100,*");
    $def[$gkey] .= rrd::cdef("percent_system", "system,total,/,100,*");
    $def[$gkey] .= rrd::cdef("percent_iowait", "iowait,total,/,100,*");
    $def[$gkey] .= rrd::cdef("percent_irq", "irq,total,/,100,*");
    $def[$gkey] .= rrd::cdef("percent_softirq", "softirq,total,/,100,*");

    $def[$gkey] .= rrd::cdef("user_area", $pre."used");
    $def[$gkey] .= rrd::cdef("nice_area_temp", "user_area,".$pre."user,-");
    $def[$gkey] .= rrd::cdef("nice_area","nice_area_temp,0,LT,0,nice_area_temp,IF");
    $def[$gkey] .= rrd::cdef("system_area_temp", "nice_area,".$pre."nice,-");
    $def[$gkey] .= rrd::cdef("system_area","system_area_temp,0,LT,0,system_area_temp,IF");
    $def[$gkey] .= rrd::cdef("irq_area_temp", "system_area,".$pre."system,-");
    $def[$gkey] .= rrd::cdef("irq_area","irq_area_temp,0,LT,0,irq_area_temp,IF");
    $def[$gkey] .= rrd::cdef("softirq_area_temp", "irq_area,".$pre."irq,-");
    $def[$gkey] .= rrd::cdef("softirq_area","softirq_area_temp,0,LT,0,softirq_area_temp,IF");
    $def[$gkey] .= rrd::cdef("iowait_area", $pre."iowait");

    $def[$gkey] .= rrd::comment("* Total Idle\\t");
    $def[$gkey] .= rrd::gprint($pre."idle", array("LAST", "MAX", "AVERAGE"), $unm);
    $def[$gkey] .= rrd::comment("* Total Used\\t");
    $def[$gkey] .= rrd::gprint($pre."used", array("LAST", "MAX", "AVERAGE"), $unm);
    $def[$gkey] .= rrd::comment("\\r");

    $def[$gkey] .= rrd::area("user_area", "#40E0D0", "user\\t");
    $def[$gkey] .= rrd::gprint($pre."user", array("LAST", "AVERAGE", "MAX"), $unm);
    $def[$gkey] .= rrd::area("nice_area", "#87CEEB", "nice\\t");
    $def[$gkey] .= rrd::gprint($pre."nice", array("LAST", "AVERAGE", "MAX"), $unm);
    $def[$gkey] .= rrd::area("system_area", "#8B4513", "system\\t");
    $def[$gkey] .= rrd::gprint($pre."system", array("LAST", "AVERAGE", "MAX"), $unm);
    $def[$gkey] .= rrd::area("irq_area", "#FF0000", "irq   \\t");
    $def[$gkey] .= rrd::gprint($pre."irq", array("LAST", "AVERAGE", "MAX"), $unm);
    $def[$gkey] .= rrd::area("softirq_area", "#FFFF00", "softirq\\t");
    $def[$gkey] .= rrd::gprint($pre."softirq", array("LAST", "AVERAGE", "MAX"), $unm);
    $def[$gkey] .= rrd::area("iowait_area", "#FFA500", "iowait\\t");
    $def[$gkey] .= rrd::gprint($pre."iowait", array("LAST", "AVERAGE", "MAX"), $unm);
}

if (isset($swap_paged_in) && isset($swap_paged_out) && isset($data_paged_in) && isset($data_paged_out)) {
    $gkey++;
    $opt[$gkey] = '--vertical-label # --title "Memory and Swap Operations on ' . $this->MACRO['DISP_HOSTNAME']. '"';
    $ds_name[$gkey] = "Memory and Swap Operations";
    $def[$gkey] = rrd::def("data_paged_in", $data_paged_in['RRDFILE'], $data_paged_in['DS'], "AVERAGE");
    $def[$gkey] .= rrd::def("data_paged_out", $data_paged_out['RRDFILE'], $data_paged_out['DS'], "AVERAGE");
    $def[$gkey] .= rrd::def("swap_paged_in", $swap_paged_in['RRDFILE'], $swap_paged_in['DS'], "AVERAGE");
    $def[$gkey] .= rrd::def("swap_paged_out", $swap_paged_out['RRDFILE'], $swap_paged_out['DS'], "AVERAGE");

    $def[$gkey] .= "AREA:data_paged_in#00CF00:\"Data Paged In \: \t\g\" ";
    $def[$gkey] .= rrd::gprint("data_paged_in", array("LAST", "AVERAGE", "MAX"), '%6.2lf ');
    $def[$gkey] .= "AREA:data_paged_out#FF8C0:\"Data Paged Out\: \t\g\":STACK ";
    $def[$gkey] .= rrd::gprint("data_paged_out", array("LAST", "AVERAGE", "MAX"), '%6.2lf ');
    $def[$gkey] .= "LINE2:swap_paged_in#FF0000:\"Swap Paged In \: \t\g\" ";
    $def[$gkey] .= rrd::gprint("swap_paged_in", array("LAST", "AVERAGE", "MAX"), '%6.2lf ');
    $def[$gkey] .= rrd::cdef("swap_paged_out_line", "swap_paged_out,data_paged_in,+");
    $def[$gkey] .= "LINE2:swap_paged_out_line#0000FF:\"Swap Paged Out\: \t\g\" ";
    $def[$gkey] .= rrd::gprint("swap_paged_out", array("LAST", "AVERAGE", "MAX"), '%6.2lf ');
}

if (isset($num_intr) && isset($ctxt)) {
    $gkey++;
    $opt[$gkey] = '--vertical-label "events per sec" --title "Interrupts and Context Switches on ' . $this->MACRO['DISP_HOSTNAME']. '"';
    $ds_name[$gkey] = "Interrupts and Context Switches";
    $def[$gkey] = rrd::def("ctxt", $ctxt['RRDFILE'], $ctxt['DS'], "AVERAGE");
    $def[$gkey] .= rrd::def("num_intr", $num_intr['RRDFILE'], $num_intr['DS'], "AVERAGE");
    $def[$gkey] .= "AREA:ctxt#00CF00:\"Context Switches (per second)\: \t\g\" ";
    $def[$gkey] .= rrd::gprint("ctxt", array("LAST", "AVERAGE", "MAX"), '%6.2lf ');
    $def[$gkey] .= "LINE1:num_intr#FF0000:\"Interrupts (per second)      \: \t\g\" ";
    $def[$gkey] .= rrd::gprint("num_intr", array("LAST", "AVERAGE", "MAX"), '%6.2lf ');
}

if (isset($processes) && isset($procs_running) && isset($procs_blocked)) {
    $gkey++;
    $opt[$gkey] = '--vertical-label "processes" --title "Process Scheduling on ' . $this->MACRO['DISP_HOSTNAME']. '"';
    $ds_name[$gkey] = "Process Scheduling";
    $def[$gkey] = rrd::def("processes", $processes['RRDFILE'], $processes['DS'], "AVERAGE");
    $def[$gkey] .= rrd::def("procs_running", $procs_running['RRDFILE'], $procs_running['DS'], "AVERAGE");
    $def[$gkey] .= rrd::def("procs_blocked", $procs_blocked['RRDFILE'], $procs_blocked['DS'], "AVERAGE");
    $def[$gkey] .= "AREA:processes#00CF00:\"Processes Forked Per Second\: \t\g\" ";
    $def[$gkey] .= rrd::gprint("processes", array("LAST", "AVERAGE", "MAX"), '%6.2lf ');
    $def[$gkey] .= "LINE1:procs_running#0000FF:\"Processes In Running State \: \t\g\" ";  
    $def[$gkey] .= rrd::gprint("procs_running", array("LAST", "AVERAGE", "MAX"), '%6.2lf ');
    $def[$gkey] .= "LINE1:procs_blocked#FF0000:\"Processes Currently Blocked\: \t\g\" ";
    $def[$gkey] .= rrd::gprint("procs_blocked", array("LAST", "AVERAGE", "MAX"), '%6.2lf ');
}

?>
