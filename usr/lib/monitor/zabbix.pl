#!/usr/bin/perl

package Zabbix;

use JSON;
use Socket;
use Data::Dumper;
use strict;

#
# Parameters:
#   local hostname
#   zabbix server ip address
#   zabbix server port (optional)
#

sub new {
    my $class = shift;
    my $self  = {};

    $self->{'hostname'} = shift;

    my $server = shift;
    my $port = shift || 10051;

    $self->{'zabbix_data'} = {};
    $self->{'addr'} = sockaddr_in($port, inet_aton($server));

    bless ($self, $class);
    return $self;
}

sub debug {
    my $self = shift;
    $self->{'debug'} = 1;
}

#
# Parameters
#   key
#   value

sub Add {
    my $self = shift;

    my %v;
    $v{'host'} = $self->{'hostname'};
    $v{'clock'} = time;
    $v{'key'} = shift;
    $v{'value'} = shift;
    push @{$self->{'zabbix_data'}{'data'}}, { %v };
}

sub DumpSelf {
    my $self = shift;

    print Dumper(\$self);
}

sub Send {
    my $self = shift;

    $self->{'zabbix_data'}{'request'}="agent data";
    $self->{'zabbix_data'}{'clock'} = time;
    my $text = encode_json $self->{'zabbix_data'};
    my $len = length ($text);
    my $sock;
    my $resp;

    if (socket($sock, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
        if (connect($sock, $self->{'addr'})) {
            send($sock, "ZBXD\x01", 0);
            send($sock, pack('q', $len), 0);
            send($sock, $text, 0);
            recv($sock, $resp, 5, 0); # 'ZBXDW'
            recv($sock, $resp, 8, 0);
            $len = unpack('q', $resp);
            recv($sock, $resp, $len, 0);
            $self->{'zabbix_response'} = decode_json( $resp );
        } else {
            print STDERR "Cannot connect to Zabbix server: $!\n";
            close ($sock);
            return 0;
        }
    } else {
        print STDERR "Cannot create socket: $!\n";
        return 0;
    }

    print Dumper(\$self) if $self->{'debug'};

    $self->{'zabbix_data'} = {};
    return 1;
}

1;
