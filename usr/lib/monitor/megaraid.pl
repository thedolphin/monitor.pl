#!/usr/bin/perl

package MegaRaid;
use strict;

# /opt/MegaRAID/MegaCli/MegaCli64 -LDInfo -LALL -aAll | grep ^State
# State               : Optimal

sub new {
    my $class = shift;
    my $self = {};

    if (! -x '/opt/MegaRAID/MegaCli/MegaCli64') {
        die 'Please install MegaCLI x64'
    }

    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'megaraid';

    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    while(1) {
        my $alert = 0;
        my @megaout = `/opt/MegaRAID/MegaCli/MegaCli64 -LDInfo -LALL -aAll -NoLog`;
        my $failed = grep(/^State\s+: (?!Optimal)/, @megaout);

        if (@megaout == 0) {
            $alert = 1;
        } elsif ($failed > 0) {
            $alert = 2;
        }

        $z->Add($self->{'name'} . '.status', $alert);
        $z->Send();
        sleep(60);
    }
}

1;
