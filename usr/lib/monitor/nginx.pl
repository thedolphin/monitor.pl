#!/usr/bin/perl

package Nginx;

use Socket;
use strict;

sub new {
    my $class = shift;
    my $self = {};

    my $host = shift;
    my $port = shift;
    $self->{'http_host'} = shift;
    $self->{'url'}       = shift;
    $self->{'zabbix'}    = shift;
    $self->{'name'}      = shift || 'nginx';

    $self->{'addr'} = sockaddr_in($port, inet_aton($host)) || die "sockaddr_in: $!\n";

    bless ($self, $class);
    return $self;
}

sub run {
    my $self = shift;
    my $zabbix = $self->{'zabbix'};
    my $sock;

    while (1) {
        if (socket($sock, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
            if (connect($sock, $self->{'addr'})) {
                $zabbix->Add($self->{'name'} . '.ping', '1');

                send($sock, "GET " . $self->{'url'} . " HTTP/1.1\r\n", 0);
                send($sock, "Host: " . $self->{'http_host'} . "\r\n", 0);
                send($sock, "Connection: close\r\n\r\n", 0);

                while (<$sock>) {
                    s/\r//g;
                    chomp;
                    if(/Active connections: (\d+)/) {
                        $zabbix->Add($self->{'name'} . '.active', $1);
                    }

                    if(/ (\d+) (\d+) (\d+)/) {
                        $zabbix->Add($self->{'name'} . '.accepted', $1);
                        $zabbix->Add($self->{'name'} . '.handled',  $2);
                        $zabbix->Add($self->{'name'} . '.requests', $3);
                    }

                    if(/Reading: (\d+) Writing: (\d+) Waiting: (\d+)/) {
                        $zabbix->Add($self->{'name'} . '.reading', $1);
                        $zabbix->Add($self->{'name'} . '.writing', $2);
                        $zabbix->Add($self->{'name'} . '.waiting', $3);
                    }
                }
                close($sock);
            } else {
                $zabbix->Add($self->{'name'} . '.ping', '0');
                print "connect: $!\n";
            }
            send($sock, "quit\n", 0);
            close ($sock);
        } else {
            print "socket: $!\n";
        }

        $zabbix->Send();
        sleep(15);
    }
}

1;
