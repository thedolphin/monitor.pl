#!/usr/bin/perl

use XML::Simple;
use Net::SNMP;
use Data::Dumper;
use strict;

my $templateName = 'T_Cisco3750_If';
my $prefix = 'c3750';
my $hostname = '10.0.0.1';
my $community = 'public';

my $ifIndexOid = '1.3.6.1.2.1.2.2.1.1';
my $ifName     = '1.3.6.1.2.1.31.1.1.1.1';
my $ifAlias    = '1.3.6.1.2.1.31.1.1.1.18';
my $ifOperStatus  = '1.3.6.1.2.1.2.2.1.8'; #1: up, 2: down, 3: testing, 4: unknown, 5: dormant, 6: notPresent, 7: lowerLayerDown
my $ifAdminStatus = '1.3.6.1.2.1.2.2.1.7'; #1: up, 2: down, 3: testing
my %ifTable = (
    ifOperStatus    => {'valuemap' => {'name' => 'Cisco_ifOperStatus'}},
    ifAdminStatus   => {'valuemap' => {'name' => 'Cisco_ifAdminStatus'}},
    ifInOctets      => {'delta' => 1, 'units' => 'bit', 'formula' => 8, 'multiplier' => 1},
    ifInErrors      => {'delta' => 1},
    ifOutOctets     => {'delta' => 1, 'units' => 'bit', 'formula' => 8, 'multiplier' => 1},
    ifOutErrors     => {'delta' => 1},
    ifInUcastPkts   => {'delta' => 1, 'units' => 'pkt'},
    ifOutUcastPkts  => {'delta' => 1, 'units' => 'pkt'});


(my $session, my $error) = Net::SNMP->session( -hostname => $hostname, -version => 2, -community => $community);
my $res;

# Get all interfaces indicies
$res = $session->get_table(-baseoid => $ifIndexOid);
my @int_idx = sort { $a <=> $b } values %{$res};

# Get all interfaces names
$res = $session->get_table(-baseoid => $ifName);

my $int_name;
foreach my $idx (@int_idx) {
    $int_name->{$idx} = $res->{"$ifName.$idx"};
}

# Get all interfaces descriptions
$res = $session->get_table(-baseoid => $ifAlias);

my $int_descr;
foreach my $idx (@int_idx) {
    $int_descr->{$idx} = $res->{"$ifAlias.$idx"};
}

# Get all interfaces oper status
$res = $session->get_table(-baseoid => $ifOperStatus);

my $int_status;
foreach my $idx (@int_idx) {
    $int_status->{$idx} = $res->{"$ifOperStatus.$idx"};
}

my @int_types = ('Gi0', 'Gi1', 'Gi2', 'Nu', 'Po', 'Vl');
my $int_by_type;
foreach my $int_type (@int_types) {
    foreach my $idx (@int_idx) {
        if (index($int_name->{$idx}, $int_type) == 0) {
            push @{$int_by_type->{$int_type}}, $idx;
        }
    }
}

# Fill the export hash
my $zbxhash = {
    'date' => '2012-09-05T08:49:46Z',
    'version' => '2.0',
    'groups' => {
        'group' => [{
            'name' => ['Templates_WM']
        }]
    },
    'graphs' => {
        'graph' => []
    },
    'triggers' => {
        'trigger' => []
    },
    'templates' => {
        'template' => [{
            'macros' => {},
            'screens' => {},
            'templates' => {},
            'template' => $templateName,
            'applications' => {
                'application' => []
            },
            'name' => $templateName,
            'items' => [{
                'item' => []
            }],
            'discovery_rules' => {},
            'groups' => {
                'group' => [{
                    'name' => 'Templates_WM'
                }]
            }
        }]
    },
};

foreach my $val (keys %ifTable) {
    push @{$zbxhash->{'templates'}->{'template'}[0]->{'applications'}->{'application'}}, { 'name' => "$prefix-$val" };
}

my %zbxitem = (
    'snmp_oid' => '',
    'ipmi_sensor' => '',
    'key' => '',
    'password' => '',
    'data_type' => '0',
    'formula' => '0',
    'privatekey' => '',
    'authtype' => '0',
    'snmpv3_privpassphrase' => '',
    'history' => '15',
    'inventory_link' => '0',
    'applications' => {'application' => [{ 'name' => '' }]},
    'description' => '',
    'port' => '',
    'snmp_community' => '',
    'snmpv3_securityname' => '',
    'username' => '',
    'value_type' => '3',
    'params' => '',
    'allowed_hosts' => '',
    'delta' => '0',
    'type' => '2',
    'snmpv3_authpassphrase' => '',
    'status' => '0',
    'delay' => '60',
    'trends' => '60',
    'snmpv3_securitylevel' => '0',
    'publickey' => '',
    'valuemap' => '',
    'delay_flex' => '',
    'units' => '',
    'multiplier' => '0'
);

my %zbxtrigger = (
    'priority' => '4',
    'status' => '1',
    'expression' => '',
    'url' => '',
    'type' => '0',
    'comments' => '',
    'description' => '',
    'dependencies' => ''
);

my %zbxgraph = (
    'ymin_item_1' => '0',
    'width' => '900',
    'percent_right' => '0.0000',
    'ymax_item_1' => '0',
    'percent_left' => '95.0000',
    'yaxismin' => '0.0000',
    'ymax_type_1' => '0',
    'yaxismax' => '100.0000',
    'show_work_period' => '1',
    'name' => '',
    'ymin_type_1' => '1',
    'height' => '200',
    'show_3d' => '0',
    'show_legend' => '1',
    'show_triggers' => '1',
    'type' => '0',
    'graph_items' => (
    )
);

my $items    = \@{$zbxhash->{'templates'}->{'template'}[0]->{'items'}[0]->{'item'}};
my $triggers = \@{$zbxhash->{'triggers'}->{'trigger'}};
my $graphs   = \@{$zbxhash->{'graphs'}->{'graph'}};

foreach my $idx (@int_idx) {
    my $trigger = {%zbxtrigger};
    my $descr = $int_descr->{$idx} ? " (". $int_descr->{$idx} .")" : '';
    $trigger->{'name'} = $int_name->{$idx} . $descr . " Down";
    $trigger->{'expression'} = "{$templateName:$prefix.ifOperStatus.$idx.last(0)}#1";
    if ($int_status->{$idx} != 1) { $trigger->{'status'} = '0' };
    push @{$triggers}, $trigger;
}

foreach my $idx (@int_idx) {
    foreach my $val (keys %ifTable) {
        my $item = {%zbxitem};
        @{$item}{ keys %{%ifTable->{$val}}} = values %{%ifTable->{$val}};
        my $descr = $int_descr->{$idx} ? " (". $int_descr->{$idx} .")" : '';
        $item->{'name'} = $int_name->{$idx} . $descr . ' ' . $val;
        $item->{'key'} = "$prefix.$val.$idx";
        $item->{'applications'} = {'application' => [{'name' => "$prefix-$val"}]};
        push @{$items}, $item;
    }
}

foreach my $src ('Octets', 'Errors', 'UcastPkts') {
foreach my $idx (@int_idx) {
    my $graph = {%zbxgraph};
    my $descr = $int_descr->{$idx} ? " (". $int_descr->{$idx} .")" : '';
    $graph->{'name'} = $int_name->{$idx} . "$descr $src";
    $graph->{'graph_items'} = [{
        'graph_item' => [{
            'yaxisside' => '0',
            'color' => 'C80000',
            'item' => {
                'key' => "$prefix.ifIn$src.$idx",
                'host' => $templateName
            },
            'type' => '0',
            'calc_fnc' => '2',
            'drawtype' => '2',
            'sortorder' => '0'
        },
        {
            'yaxisside' => '0',
            'color' => '00C800',
            'item' => {
                'key' => "$prefix.ifOut$src.$idx",
                'host' => $templateName
            },
            'type' => '0',
            'calc_fnc' => '2',
            'drawtype' => '2',
            'sortorder' => '1'
        }]
    }];

    push @{$graphs}, $graph;
}


foreach my $int_type (keys %{$int_by_type}) {
    my $graph = {%zbxgraph};
    my $so = 0;
    $graph->{'name'} = $int_type . " $src complex";
    $graph->{'graph_items'} = {'graph_item' => []};
    $graph->{'percent_left'} = '0';
    foreach my $idx (@{$int_by_type->{$int_type}}) {
        push @{$graph->{'graph_items'}->{'graph_item'}}, {
            'yaxisside' => '0',
            'color' => 'C80000',
            'item' => {
                'key' => "$prefix.ifIn$src.$idx",
                'host' => $templateName
            },
            'type' => '0',
            'calc_fnc' => '2',
            'drawtype' => '2',
            'sortorder' => $so++
        };
        push @{$graph->{'graph_items'}->{'graph_item'}}, {
            'yaxisside' => '0',
            'color' => '00C800',
            'item' => {
                'key' => "$prefix.ifOut$src.$idx",
                'host' => $templateName
            },
            'type' => '0',
            'calc_fnc' => '2',
            'drawtype' => '2',
            'sortorder' => $so++
        };
    }
    push @{$graphs}, $graph;
}}

print XMLout($zbxhash, NoAttr => 1, RootName => 'zabbix_export', NoSort => 1, XMLDecl => '<?xml version="1.0" encoding="UTF-8"?>');
