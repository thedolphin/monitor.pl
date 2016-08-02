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

    my $packedip = gethostbyname($host) || die "Cannot resolve '$host'";
    $self->{'addr'} = sockaddr_in($port, $packedip) || die "sockaddr_in: $!\n";
    $self->{'auth'} = encode_base64("$user:$pass");
    chomp $self->{'auth'};

    bless ($self, $class);
    return $self;
}

sub request {
    my $self =  shift;
    my $req = shift;
    my $sock;
    my $resp;
    my $skip = 1;

    print "Request: $req\n";

    if (socket($sock, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
        if (connect($sock, $self->{'addr'})) {
            print "Connected\n";
            my $q = "GET " . $req . " HTTP/1.1\r\n" .
                    "Host: localhost\r\n" .
                    "Authorization: Basic " . $self->{'auth'} . "\r\n" .
                    "Connection: close\r\n\r\n";

            send($sock, $q, 0);

            while (<$sock>) {
                s/[\r\n]//g;
                print "Got:$_\n";
                die "Bad login credentials!\n" if m|HTTP/1.1 401 Unauthorized|;
                if (! $_) { $skip = 0; next };
                next if $skip;
                $resp = $_;
                $skip = 1;
            }

            close($sock);
            print "Response: $resp\n";
            return $resp;
        }
    }
    return undef;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};
    my $ping;
    my $resp;

    while(1) {
        $ping = 1;

        if($resp = $self->request('/api/queues')) {
            my $ref = decode_json($resp);
            foreach my $i (@{$ref}) {
                $z->Add($self->{'name'} .'.'. $i->{'name'}, $i->{'messages'});
            }
        } else { $ping = 0 };

        if($resp = $self->request('/api/nodes')) {
            my $ref = decode_json($resp);
            foreach my $i (@{$ref}) {
                $i->{'name'} =~ s|@|-|g;
                $z->Add($self->{'name'} .'.'. $i->{'name'} . '.mem_used', $i->{'mem_used'});
            }
        } else { $ping = 0 };

        $z->Add($self->{'name'} . '.ping', $ping);
        $z->Send();
        sleep(15);
    }
}

1;