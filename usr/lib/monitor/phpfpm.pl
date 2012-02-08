#!/usr/bin/perl

package PhpFpm;

use FCGI::Client;
use IO::Socket;
use JSON;
use strict;

sub new {
    my $class = shift;
    my $self = {};

    $self->{'addr'} = shift;
    $self->{'path'} = shift;
    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'phpfpm';

    bless ($self, $class);
    return $self;
}

sub run {
    my $self = shift;
    my $sock;

    while(1) {
        if ($self->{'addr'} =~ m|^/|) {
            $sock = IO::Socket::UNIX->new(Peer => $self->{'addr'});
        } else {
            (my $srv, my $port) = split /:/, $self->{'addr'};
            if (!$port) { $port = '9000' };
            $sock = IO::Socket::INET->new(PeerAddr => $srv, PeerPort => $port);
        }

        if ($sock) {
            $self->{'zabbix'}->Add($self->{'name'} . '.ping', 1);

            my $client = FCGI::Client::Connection->new(sock => $sock);
            ($_, my $stderr) = $client->request({
                                    SCRIPT_FILENAME => '',
                                    SCRIPT_NAME => $self->{'path'},
                                    QUERY_STRING => 'json',
                                    REQUEST_METHOD => 'GET'
                                }, '');

            my ($header, $body) = split /\r\n\r\n/;
            my $response = decode_json($body);

            $self->{'zabbix'}->Add($self->{'name'} . '.accepted', $response->{'accepted conn'});
            $self->{'zabbix'}->Add($self->{'name'} . '.idle',     $response->{'idle processes'});
            $self->{'zabbix'}->Add($self->{'name'} . '.active',   $response->{'active processes'});
            $self->{'zabbix'}->Add($self->{'name'} . '.total',    $response->{'total processes'});

            undef $client;
            undef $sock;
        } else {
             $self->{'zabbix'}->Add($self->{'name'} . '.ping', 0);
        }

        $self->{'zabbix'}->Send();
        sleep(15);
    }
}

1;
