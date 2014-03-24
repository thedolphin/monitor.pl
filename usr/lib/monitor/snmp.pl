#!/usr/bin/perl

package Snmp;

use Net::SNMP;
use strict;

# Predefined MIBs

our $a = 1;

our $cisco_system = {
    cpmCPUTotal5secRev                  => '1.3.6.1.4.1.9.9.109.1.1.1.1.6',
    cpmCPUInterruptMonIntervalValue     => '1.3.6.1.4.1.9.9.109.1.1.1.1.11',
    ciscoMemoryPoolUsed                 => '1.3.6.1.4.1.9.9.48.1.1.1.5',
    ciscoMemoryPoolFree                 => '1.3.6.1.4.1.9.9.48.1.1.1.6',
    ciscoEnvMonTemperatureStatusValue   => '1.3.6.1.4.1.9.9.13.1.3.1.3'
#    ciscoMemoryPoolName                 => '1.3.6.1.4.1.9.9.48.1.1.1.2'
};

our $cisco_if = {
    ifAdminStatus                       => '1.3.6.1.2.1.2.2.1.7',
    ifOperStatus                        => '1.3.6.1.2.1.2.2.1.8',
    ifInOctets                          => '1.3.6.1.2.1.2.2.1.10',
    ifInErrors                          => '1.3.6.1.2.1.2.2.1.14',
    ifOutOctets                         => '1.3.6.1.2.1.2.2.1.16',
    ifOutErrors                         => '1.3.6.1.2.1.2.2.1.20',
    ifInUcastPkts                       => '1.3.6.1.2.1.2.2.1.11',
    ifOutUcastPkts                      => '1.3.6.1.2.1.2.2.1.17'
};

our $cisco_ipsec = {
    cipSecGlobalActiveTunnels           => '1.3.6.1.4.1.9.9.171.1.3.1.1',
    cipSecGlobalInOctets                => '1.3.6.1.4.1.9.9.171.1.3.1.3',
    cipSecGlobalOutOctets               => '1.3.6.1.4.1.9.9.171.1.3.1.16'
};

our $cisco_bgp = {
    bgpPeerFsmEstablishedTransitions    => '1.3.6.1.2.1.15.3.1.15',
    bgpPeerFsmEstablishedTime           => '1.3.6.1.2.1.15.3.1.16',
    bgpPeerState                        => '1.3.6.1.2.1.15.3.1.2',
    bgpPeerAdminStatus                  => '1.3.6.1.2.1.15.3.1.3'
};

our $cisco_stackwise = {
    cswSwitchState                      => '1.3.6.1.4.1.9.9.500.1.2.1.1.6'
};

# Parameters
#   host
#   community
#   zabbix instance
#   instance name
#   hashref { name => 'oid',... }
#   ...

sub new {
    my $class = shift;
    my $self = {};

    $self->{'hostname'} = shift;
    $self->{'community'} = shift;

    $self->{'zabbix'} = shift;
    $self->{'name'} = shift;

    @{$self->{'mibs'}} = ();
    while (my $mib = shift) {
        push @{$self->{'mibs'}}, $mib;
    }

    bless ($self, $class);
    return ($self);
}

sub patch {
    my $self = shift;
    my $oid = shift;
    my $val = shift;

    if (index($oid, $cisco_if->{'ifOutOctets'}) == 0) {
        $val = -$val;
    }

    if (index($oid, $cisco_if->{'ifOutUcastPkts'}) == 0) {
        $val = -$val;
    }

    if (index($oid, $cisco_if->{'ifOutErrors'}) == 0) {
        $val = -$val;
    }

    return $val;
}

sub run {
    my $self = shift;
    while (1) {

        ($self->{'session'}, my $error) = Net::SNMP->session(-hostname => $self->{'hostname'}, -version => 2, -community => $self->{'community'});

        foreach my $mib (@{$self->{'mibs'}}) {
            foreach my $name (keys %{$mib}) {
                my $result = $self->{'session'}->get_table(-baseoid => $mib->{$name});
                foreach my $oid (keys %{$result}) {
                    my $value = $result->{$oid};
                    $oid =~ s/^$mib->{$name}/$name/;
                    $self->{'zabbix'}->Add($self->{'name'} .'.'. $oid, $value);
                }
            }
        }
        $self->{'zabbix'}->Send();

        undef $self->{'session'};

        sleep(30);
    }
}

1;
