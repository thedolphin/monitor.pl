#!/usr/bin/perl

package Haproxy;

use Socket;
use JSON;
use strict;

sub new {
    my $class = shift;
    my $self = {};

    $self->{'name'} = 'haproxy';

    $self->{'zabbix'} = shift;

    my $socket = shift || '/var/run/haproxy.stats';
    $self->{'socket'} = sockaddr_un($socket);

    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    while(1) {
        my $hpx;
        my $discovery = {};

        socket($hpx, PF_UNIX, SOCK_STREAM, 0) || die "socket: $!";
        connect($hpx, $self->{'socket'}) || die "connect: $!";
        send($hpx, "show stat\n", 0);

        my $v = <$hpx>;
        chomp $v;
        my @vars = split /\,/, $v;
        shift @vars for 1..2;

        while(<$hpx>) {
            chomp;
            next if ! $_;
            split /\,/;

            my $upstream = shift;
            my $item = shift;
            push @{$discovery->{'data'}}, {'{#GROUP}' => $upstream, '{#ITEM}' => $item};

            for my $i (0 .. $#vars) {
                $v = shift;
                $z->Add($self->{'name'} .".stats[$upstream,$item,". $vars[$i] .']', $v) if $v;
            }
        }

        $z->Add($self->{'name'}.'.discovery', encode_json $discovery);

        $z->Send();

        close($hpx);

        sleep(30);
    }
}

1;
