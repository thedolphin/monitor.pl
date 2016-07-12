#!/usr/bin/perl

use strict;

use lib "/usr/lib/monitor";

require "zabbix.pl";
require "monitor.pl";

require "memcache.pl";
require "diskstats.pl";
require "diskstats_lld.pl";
require "diskusage.pl";
require "mysql.pl";
require "pgsql.pl";
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
require "haproxy.pl";
require "ethtool.pl";
require "mdraid.pl";

use Data::Dumper();

die "Configure me first!"; # And drop this line after configuring

my $z = new Zabbix('', 'server address');

$z->debug() if $ARGV[0] eq 'debug';

my @methods;
push @methods, new Memcache('host', 'port', $z);
push @methods, new DiskStats($z, {'disk0' => 'cciss/c0d0', 'disk1' => 'dm-0', 'disk2' => 'dm-1'});
push @methods, new DiskStatsLLD($z, '^(md\d+|[vs]d[a-z]|cciss/c\d+d\d+)$');
push @methods, new DiskUsage($z, 'name', 'path to file or dir', 'path to file or dir', ...);
push @methods, new Mysql('host','port','username','password',$z);
push @methods, new PgSQL('host (or empty)', 'port (or empty)', 'database name (recommended)', 'login', 'password', $z);
push @methods, new Nginx('host', 'port', 'http host', 'stub_status path', $z);
push @methods, new NginxLog('log file', 'pid file', $z);
push @methods, new Rabbit('host', 'port', 'user', 'password', $z);
push @methods, new Sphinx('host', 9406, $z);
push @methods, new Snmp('host', 'community', $z, 'name', $Snmp::cisco_system, $Snmp::cisco_bgp, $Snmp::cisco_stackwise, $Snmp::cisco_if);
push @methods, new PhpFpm('host:port or /path/to/socket', '/handler', $z);
push @methods, new Redis('host:port or /path/to/socket', $z);
push @methods, new ccissraid($z);
push @methods, new MegaRaid($z);
push @methods, new PostfixLog('log file','last rotated log file','pid (probably /var/spool/postfix/pid/master.pid)',$z);
push @methods, new Haproxy($z, '/path/to/stats/socket');
push @methods, new Ethtool($z);
push @methods, new MDRaid($z);

my $m = new Monitor(\@methods);
# $m->daemonize('/var/run/monitor.pid', '/var/log/monitor.log');
$m->run();
