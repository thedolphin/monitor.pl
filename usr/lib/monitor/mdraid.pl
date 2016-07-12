#!/usr/bin/perl

package MDRaid;
use JSON;
use strict;

sub new {
    my $class = shift;
    my $self = {};

    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'mdraid';

    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};
    my @mdstat;

    while(1) {
        open(my $fh, '<', '/proc/mdstat') || die $!;
        chomp(@mdstat = <$fh>);
        close ($fh);

        my $discovery = {'data' => []};

        while (defined($_ = shift @mdstat)) {
            next if not /^(md\d+) :/;

            my $devname = $1;
            my $status = '';
            my $recovery = '';

            push @{$discovery->{'data'}}, {'{#MDNAME}' => "$devname"};
            $_ = shift @mdstat;
            (my $status) = /\[(U+)\]$/;
            $_ = shift @mdstat;
            (my $recovery) = /recovery = ([\d\.]+)%/;

            if ($status) {
                $z->Add($self->{'name'} . ".state[$devname]", 2);
            } elsif ($recovery) {
                $z->Add($self->{'name'} . ".state[$devname]", 1);
            } else {
                $z->Add($self->{'name'} . ".state[$devname]", 0);
            }

        };

        $z->Add($self->{'name'} . '.discovery', encode_json($discovery));
        $z->Send();

        sleep(60);
    }
}

1;
