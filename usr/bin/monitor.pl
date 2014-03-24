#!/usr/bin/perl

use strict;

use lib "/usr/lib/monitor";

require "zabbix.pl";
require "monitor.pl";

require "memcache.pl";
require "diskstats.pl";
require "mysql.pl";
require "nginx.pl";
require "nginxlog.pl";
require "rabbit.pl";
require "sphinx.pl";
require "snmp.pl";
require "phpfpm.pl";
require "redis.pl";
require "ccissraid.pl";
require "megaraid.pl";
require "postfixlog.pl";

use Data::Dumper();

die "Configure me first!"; # And drop this line after configuring

my $z = new Zabbix('host name', 'server address');

# Dump zabbix exchange on console
# $z->debug();

my @methods;
push @methods, new Memcache('host', 'port', $z);
push @methods, new DiskStats($z, {'disk0' => 'cciss/c0d0', 'disk1' => 'dm-0', 'disk2' => 'dm-1'});
push @methods, new Mysql('host','port','username','password',$z);
push @methods, new Nginx('host', 'port', 'http host', 'stub_status path', $z);
push @methods, new NginxLog('log file', 'pid file', $z);
push @methods, new Rabbit('host', 'port', 'user', 'password', $z);
push @methods, new Sphinx('host', 9406, $z);
push @methods, new Snmp('host', 'community', $z, 'name', $Snmp::cisco_system, $Snmp::cisco_bgp, $Snmp::cisco_stackwise, $Snmp::cisco_if);
push @methods, new PhpFpm('host:port or /path/to/socket', '/handler', $z);
push @methods, new Redis('host', 'port', $z);
push @methods, new ccissraid($z);
push @methods, new MegaRaid($z);
push @methods, new PostfixLog('log file','last rotated log file','pid (probably /var/spool/postfix/pid/master.pid)',$z);

my $m = new Monitor(\@methods);

# Comment out when debugging
$m->daemonize('/var/run/monitor.pid', '/var/log/monitor.log');

$m->run();
