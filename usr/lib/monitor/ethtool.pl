#!/usr/bin/perl

package Ethtool;

use Linux::Ethtool qw(:all);
use Linux::Ethtool::Settings;
use JSON;
use strict;

sub new {
    my $class = shift;
    my $self = {};

    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'ethtool';
    $self->{'interfaces'} = [];
    my $discovery = { 'data' => [] };

    my $fh;
    open($fh, '<', '/proc/net/dev') || die $!;
    while(<$fh>) {
        if  (/^\s*(\w+\d+):/) {
            push @{$discovery->{'data'}}, {'{#ETHNAME}' => $1};
            push @{$self->{'interfaces'}}, $1;
        }
    }
    close $fh;

    $self->{'discovery'} = encode_json($discovery);

    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    while(1) {

        foreach my $interface (@{$self->{'interfaces'}}) {
            my $link = get_link($interface);
            my $settings = Linux::Ethtool::Settings->new($interface) or die($!);

            $z->Add($self->{'name'} . ".link[$interface]", $link);
            $z->Add($self->{'name'} . ".speed[$interface]", $link ? $settings->speed() : 0);
            $z->Add($self->{'name'} . ".duplex[$interface]", $link ? $settings->duplex() : 0);

            undef $settings;
        }

        $z->Add($self->{'name'} . '.discovery', $self->{'discovery'});
        $z->Send();

        sleep(60);
    }
}

1;
