#!/usr/bin/perl

package Sphinx;

use DBI;
use strict;

# Parameters
#  host
#  port
#  zabbix instance
#  instance name

sub new {
    my $class = shift;
    my $self = {};

    my $host = shift;
    my $port = shift;
    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'sphinx';
    $self->{'dsn'} = "DBI:mysql:host=$host;port=$port";

    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    while(1) {
        my $dbh = DBI->connect($self->{'dsn'});
        if ($dbh) {
            $z->Add($self->{'name'} . '.ping', 1);
            my $res = $dbh->selectall_arrayref("show status");
            foreach my $k (@{$res}) {
                $z->Add($self->{'name'} .'.'. $k->[0], $k->[1]);
            }
        } else {
            $z->Add($self->{'name'} . '.ping', 0);
        }
        $z->Send();
        $dbh->disconnect();
        undef $dbh;
        sleep(15);
    }
}

1;
