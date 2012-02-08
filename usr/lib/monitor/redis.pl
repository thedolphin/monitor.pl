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
    my $info = {};

    while (1) {
        if (socket($sock, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
            if (connect($sock, $self->{'addr'})) {

                $self->{'zabbix'}->Add($self->{'name'} . '.ping', '1');
                send($sock, "info\r\n", 0);

                while (($_ = <$sock>) && ($_ !~ /^.$/)) {
                    next if /^\$/;
                    s/[\r\n]//g;
                    if (/(db\d+):keys=(\d+),expires=(\d+)/) {
                        $self->{'zabbix'}->Add($self->{'name'} .'.'. $1 .'_keys', $2);
                        $self->{'zabbix'}->Add($self->{'name'} .'.'. $1 .'_expires', $3);
                    } else {
                        my ($key, my $val) = split /:/;
                        $self->{'zabbix'}->Add($self->{'name'} .'.'. $key, $val);
                        $info->{$key} = $val;
                    }
                }
                $self->{'zabbix'}->Add($self->{'name'} . '.hitrate', int($info->{'keyspace_hits'} * 100 / ($info->{'keyspace_hits'} + $info->{'keyspace_misses'})));

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
        sleep(15);
    }
}

1;
