#!/usr/bin/perl

package Memcache;

use Socket;
use strict;

sub new {
    my $class = shift;
    my $self = {};

    my $host = shift;
    my $port = shift;

    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'memcache';

    $self->{'addr'} = sockaddr_in($port, inet_aton($host)) || die "sockaddr_in: $!\n";

    bless ($self, $class);
    return $self;
}

sub run {
    my $self = shift;
    my $zabbix = $self->{'zabbix'};
    my $sock;

    my %mcstat;

    while (1) {
        if (socket($sock, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
            if (connect($sock, $self->{'addr'})) {
                $zabbix->Add($self->{'name'} . '.ping', '1');
                send($sock, "stats\n", 0);

                while (($_ = <$sock>) && ($_ !~ /^END/)) {
                    (my $stat, my $key, my $val) = split;
		    $mcstat{$key} = $val;
                }
            } else {
                print "connect: $!\n";
                $zabbix->Add($self->{'name'} . '.ping', '0');
            }
            send($sock, "quit\n", 0);
            close ($sock);

	    foreach my $key (keys %mcstat) {
		$zabbix->Add($self->{'name'} .'.'. $key, $mcstat{$key});
	    }

            my $hit_rate = int($mcstat{'get_hits'} * 100 / $mcstat{'cmd_get'});
            my $free_mem = $mcstat{'limit_maxbytes'} - $mcstat{'bytes'};
            my $free_mem_p = int($free_mem * 100 / $mcstat{'limit_maxbytes'});
            my $bytes_p = int($mcstat{'bytes'} * 100 / $mcstat{'limit_maxbytes'});

            $zabbix->Add($self->{'name'} . '.hit_rate', $hit_rate);
            $zabbix->Add($self->{'name'} . '.free_mem', $free_mem);
            $zabbix->Add($self->{'name'} . '.free_mem_p', $free_mem_p);
            $zabbix->Add($self->{'name'} . '.bytes_p', $bytes_p);

        } else {
            print "socket: $!\n";
        }

        $zabbix->Send();
        sleep(15);
    }
}

1;
