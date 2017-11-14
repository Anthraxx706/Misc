#! /usr/bin/perl
use strict;
use warnings;

#Fake Threshold
my $mem_warning = 70;
my $mem_critical = 90;
my $swap_warning = 70;
my $swap_critical = 90;



sub sys_stats {
	my $mem_total = `grep MemTotal /proc/meminfo | sed s/[^0-9]*//g` * 1024;
	my $mem_avail = `grep MemAvailable /proc/meminfo | sed s/[^0-9]*//g` * 1024;
	my $mem_used = $mem_total - $mem_avail;
	my $swap_total = `grep SwapTotal /proc/meminfo | sed s/[^0-9]*//g` * 1024;
	my $swap_free = `grep SwapFree /proc/meminfo | sed s/[^0-9]*//g` * 1024;
	my $swap_used = $swap_total - $swap_free;
	my $mem_percent = ($mem_used / $mem_total) * 100;
	my $swap_percent;
	if ( $swap_total == 0 ) {
		$swap_percent = 0;
	} else {
	$swap_percent = ($swap_used / $swap_total) * 100;
	};
	return (sprintf("%.0f",$mem_percent),$mem_total,$mem_used, sprintf("%.0f",$swap_percent),$swap_total,$swap_used);
}

my $mem_threshold_output = " (";
my $swap_threshold_output = " (";

my ($mem_percent, $mem_total, $mem_used, $swap_percent, $swap_total, $swap_used) = &sys_stats();
my $free_mem = $mem_total - $mem_used;
my $free_swap = $swap_total - $swap_used;
# set output message
my $output = "Memory Usage: ". $mem_percent.'% (W:'.$mem_warning.', C:'.$mem_critical.')';
$output .= " -- Swap Usage: ". $swap_percent.'% (W:'.$swap_warning.', C:'.$swap_critical.')';

# set verbose output message
my $verbose_output = "Memory Usage:".$mem_threshold_output.": ". $mem_percent.'% '."- Total: $mem_total MB, used: $mem_used MB, free: $free_mem MB<br>";
$verbose_output .= "Swap Usage:".$swap_threshold_output.": ". $swap_percent.'% '."- Total: $swap_total MB, used: $swap_used MB, free: $free_swap MB<br>";

# set perfdata message
my $perfdata_output = "MemUsed=$mem_percent\%;$mem_warning;$mem_critical";
$perfdata_output .= " SwapUsed=$swap_percent\%;$swap_warning;$swap_critical";


## Check 

if ($mem_percent>$mem_critical || $swap_percent>$swap_critical) {
    print $output."|".$perfdata_output."\n";
} elsif ($mem_percent>$mem_warning || $swap_percent>$swap_warning) {
    print $output."|".$perfdata_output."\n";
} else {
    print $output."|".$perfdata_output."\n";
}

