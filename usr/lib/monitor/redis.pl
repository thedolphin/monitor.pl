#!/usr/bin/perl

package Redis;

use Socket;
use strict;

sub new {
    my $class = shift;
    my $self = {};

    my $host = shift;
    my $port = shift;

    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'redis';

    $self->{'addr'} = sockaddr_in($port, inet_aton($host)) || die "sockaddr_in: $!\n";

    bless ($self, $class);
    return $self;
}

sub run {
    my $self = shift;
    my $sock;
    my $rsz; my $resp;
    my $info = {};

    while (1) {
        if (socket($sock, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
            if (connect($sock, $self->{'addr'})) {

                $self->{'zabbix'}->Add($self->{'name'} . '.ping', '1');

                syswrite($sock, "*1\r\n\$4\r\ninfo\r\n");
                $rsz = sysread($sock, $resp, 2048);

                if ($rsz == 2048) {
                    print "Have read full buffer, more data may be available\n";
                    die;
                }

                while ($resp =~ /([^\r]*)(\r\n)?/g) {
                    $_ = $1;
                    next if /^$/;
                    next if /^[\$#]/;

                    if (/(db\d+):keys=(\d+),expires=(\d+)/) {
                        $self->{'zabbix'}->Add($self->{'name'} .'.'. $1 .'_keys', $2);
                        $self->{'zabbix'}->Add($self->{'name'} .'.'. $1 .'_expires', $3);
                    } else {
                        my ($key, my $val) = split /:/;
                        $self->{'zabbix'}->Add($self->{'name'} .'.'. $key, $val);
                        $info->{$key} = $val;
                    }
                }

                if ($info->{'keyspace_hits'} + $info->{'keyspace_misses'} > 0) {
                    $self->{'zabbix'}->Add($self->{'name'} . '.hitrate', int($info->{'keyspace_hits'} * 100 / ($info->{'keyspace_hits'} + $info->{'keyspace_misses'})));
                }

            } else {
                print "connect: $!\n";
                $self->{'zabbix'}->Add($self->{'name'} . '.ping', '0');
            }
            send($sock, "quit\n", 0);
            close ($sock);
        } else {
            print "socket: $!\n";
        }

        $self->{'zabbix'}->Send();
        sleep(30);
    }
}

1;
