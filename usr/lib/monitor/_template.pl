#!/usr/bin/perl

# CHANGE NAME
package Template;

# PUT ADDITIONAL MODULES HERE

use strict;

sub new {
    my $class = shift;
    my $self = {};


    $self->{'zabbix'} = shift;

    # CHANGE VISIBLE NAME
    $self->{'name'} = shift || 'Template';

    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    while(1) {

        # DO SOMETHING HERE

        $z->Add($self->{'name'} . '.itemname', $value);
        $z->Send();

        sleep(60);
    }
}

1;
