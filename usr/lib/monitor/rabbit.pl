#!/usr/bin/perl

package Rabbit;

use Try::Tiny;
use Socket;
use JSON;
use MIME::Base64;
use Data::Dumper;
use strict;
use POSIX;


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

    if (socket($sock, PF_INET, SOCK_STREAM, getprotobyname('tcp'))) {
        if (connect($sock, $self->{'addr'})) {
            my $q = "GET " . $req . " HTTP/1.1\r\n" .
                    "Host: localhost\r\n" .
                    "Authorization: Basic " . $self->{'auth'} . "\r\n" .
                    "Connection: close\r\n\r\n";

            send($sock, $q, 0);

            while (<$sock>) {
                s/[\r\n]//g;
                die "Bad login credentials!\n" if m|HTTP/1.1 401 Unauthorized|;
                if (! $_) { $skip = 0; next };
                next if $skip;
                $resp = $_;
                $skip = 1;
            }

            close($sock);
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
    my $nodename;
    my $unsync;

    while(1) {
        $ping = 1;
        $unsync = 0;
        my $ref = undef;

        if($resp = $self->request('/api/queues')) {
            try {$ref = decode_json($resp)};
            foreach my $i (@{$ref}) {
                my $publish = $i->{'message_stats'}->{'publish'};
                if (defined $publish) {
                    $z->Add($self->{'name'} .'.'. $i->{'name'} . '.publish', $publish);
                }
                else {
                    $z->Add($self->{'name'} .'.'. $i->{'name'} . '.publish', 0);
                } 
                my $ack = $i->{'message_stats'}->{'ack'};
                if (defined $ack) {
                    $z->Add($self->{'name'} .'.'. $i->{'name'} . '.ack', $ack);
                }
                else {
                    $z->Add($self->{'name'} .'.'. $i->{'name'} . '.ack', 0);
                } 
                my $get_no_ack =  $i->{'message_stats'}->{'get_no_ack'};
                if (defined $get_no_ack) {
                    $z->Add($self->{'name'} .'.'. $i->{'name'} . '.get_no_ack', $get_no_ack);
                }
                else {
                    $z->Add($self->{'name'} .'.'. $i->{'name'} . '.get_no_ack', 0);
                }
                my $messages =  $i->{'messages'};
                if (defined $messages) {
                    $z->Add($self->{'name'} .'.'. $i->{'name'}, $messages);
                }
                else {
                    $z->Add($self->{'name'} .'.'. $i->{'name'}, 0);
                }
                my $sync_nodes = $i->{'synchronised_slave_nodes'};
                if (defined $sync_nodes) {
                    if ( !(@{$i->{'synchronised_slave_nodes'}}) ) {
                        $unsync += 1;
                    }
                }
            }
            $z->Add($self->{'name'} .'.'. 'unsync', $unsync);
        } else { $ping = 0 }

        if($resp = $self->request('/api/overview')) {
            my $ref = decode_json($resp);
            $nodename = $ref->{'node'};
            $z->Add($self->{'name'} .'.nodename', $ref->{'node'});
        } else { $ping = 0 };

        if($resp = $self->request('/api/nodes/'.$nodename)) {
            my $ref = decode_json($resp);
            $z->Add($self->{'name'} .'.mem_used', $ref->{'mem_used'});
            $z->Add($self->{'name'} .'.mem_limit', $ref->{'mem_limit'});
            $z->Add($self->{'name'} .'.mem_left_to_watermark', $ref->{'mem_limit'} - $ref-> {'mem_used'});
            $z->Add($self->{'name'} .'.mem_left_to_watermark_percent', 100-100/($ref->{'mem_limit'} / $ref->{'mem_used'}));
            $z->Add($self->{'name'} .'.disk_free_limit', $ref->{'disk_free_limit'});
            $z->Add($self->{'name'} .'.disk_free', $ref->{'disk_free'});

            if ($ref->{'disk_free'}>0) {
              $z->Add($self->{'name'} .'.disk_usage_percent', 100/($ref->{'disk_free'}/$ref->{'disk_free_limit'}));
              $z->Add($self->{'name'} .'.disk_left_to_watermark_percent', 100-100/($ref->{'disk_free'}/$ref->{'disk_free_limit'}));
            } else {
              $z->Add($self->{'name'} .'.disk_usage_percent', 0);
              $z->Add($self->{'name'} .'.disk_left_to_watermark_percent', 0);
            }

            $z->Add($self->{'name'} .'.disk_left_to_watermark', $ref->{'disk_free'}-$ref->{'disk_free_limit'});
            $z->Add($self->{'name'} .'.uptime', $ref->{'uptime'});
            $z->Add($self->{'name'} .'.erlang_proc_used', $ref->{'proc_used'});
            $z->Add($self->{'name'} .'.erlang_proc_total', $ref->{'proc_total'});
            $z->Add($self->{'name'} .'.erlang_proc_usage_percent', 100/($ref->{'proc_total'}/$ref->{'proc_used'}));
            $z->Add($self->{'name'} .'.filedesc_used', $ref->{'fd_used'});
            $z->Add($self->{'name'} .'.filedesc_total', $ref->{'fd_total'});
            $z->Add($self->{'name'} .'.filedesc_usage_percent', 100/($ref->{'fd_total'}/$ref->{'fd_used'}));
            $z->Add($self->{'name'} .'.sockets_total', $ref->{'sockets_total'});
            $z->Add($self->{'name'} .'.sockets_usage_percent', 100/($ref->{'sockets_total'}/$ref->{'sockets_used'}));
            
            if ( (@{$ref->{'partitions'}}) ) {
                $z->Add($self->{'name'} .'.unparted', '0');
            } else {
                $z->Add($self->{'name'} .'.unparted', '1');
            }

        } else { $ping = 0 };

        if($resp = $self->request('/api/nodes')) {
            my $i;
            my $status = 1;
            my $ref = decode_json($resp);
            foreach  $i (@{$ref}) {
              if ($i->{'running'} eq 'false') {
                $status = 0;
              }
            }
            $z->Add($self->{'name'} .'.'. $i->{'name'} . 'cluster_status', $status)
        }

        if($resp = $self->request('/api/connections')) {
            my $i;
            my $blocked = 0;
            my $ref = decode_json($resp);
            foreach  $i (@{$ref}) {
                if ($i->{'state'} eq 'blocked') {
                    $blocked += 1;
                }
            }
            $z->Add($self->{'name'} .'.'. $i->{'name'} . 'blocked', $blocked)
        }

        $z->Add($self->{'name'} . '.ping', $ping);
        $z->Send();
        sleep(15);
    }
}
1;