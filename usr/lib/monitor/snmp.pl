#!/usr/bin/perl

package Snmp;

use Net::SNMP;
use strict;

# Predefined MIBs

our $a = 1;

our $cisco_system = {
    cpmCPUTotal5sec                     => '1.3.6.1.4.1.9.9.109.1.1.1.1.3',
    cpmCPUInterruptMonIntervalValue     => '1.3.6.1.4.1.9.9.109.1.1.1.1.11',
    ciscoMemoryPoolUsed                 => '1.3.6.1.4.1.9.9.48.1.1.1.5',
    ciscoMemoryPoolFree                 => '1.3.6.1.4.1.9.9.48.1.1.1.6',
    ciscoEnvMonTemperatureStatusValue   => '1.3.6.1.4.1.9.9.13.1.3.1.3'
};

our $cisco_if = {
    ifAdminSatatus                      => '1.3.6.1.2.1.2.2.1.7',
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

    ($self->{'session'}, my $error) = Net::SNMP->session(-hostname => shift, -version => 2, -community => shift);

    $self->{'zabbix'} = shift;
    $self->{'name'} = shift;

    @{$self->{'mibs'}} = ();
    while (my $mib = shift) {
        push @{$self->{'mibs'}}, $mib;
    }

    bless ($self, $class);
    return ($self);
}

sub run {
    my $self = shift;
    while (1) {
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
        sleep(15);
    }
}

1;
