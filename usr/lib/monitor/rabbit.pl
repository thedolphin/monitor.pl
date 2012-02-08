#!/usr/bin/perl

package Rabbit;

use Socket;
use JSON;
use MIME::Base64;
use strict;

# Parameters:
#   host
#   port
#   user
#   pass
#   zabbix instance
#   instance name

sub new {
    my $class = shift;
    my $self = {};

    my $host = shift;
    my $port = shift;
    my $user = shift;
    my $pass = shift;
    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'rabbit';
    $self->{'addr'} = sockaddr_in($port, inet_aton($host)) || die "sockaddr_in: $!\n";
    $self->{'auth'} = encode_base64("$user:$pass");
    chomp $self->{'auth'};

    bless ($self, $class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};
    my $sock;
    my $skip = 1;
    my $resp;

    while(1) {
        if (socket($sock, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
            if (connect($sock, $self->{'addr'})) {
                $z->Add($self->{'name'} .'.ping', 1);

                my $q = "GET /api/queues HTTP/1.1\r\n" .
                        "Host: localhost\r\n" .
                        "Authorization: Basic " . $self->{'auth'} . "\r\n" .
                        "Connection: close\r\n\r\n";
                send($sock, $q, 0);

                while (<$sock>) {
                    s/[\r\n]//g;
                    if (! $_) { $skip = 0; next };
                    next if $skip;
                    $resp = $_;
                    $skip = 1;
                }

                close($sock);
                my $ref = decode_json($resp);
                foreach my $i (@{$ref}) {
                    $z->Add($self->{'name'} .'.'. $i->{'name'}, $i->{'messages'});
                }
            } else {
                $z->Add($self->{'name'} .'.ping', 0);
            }
        }

        $z->Send();
        sleep(15);
    }
}

1;
