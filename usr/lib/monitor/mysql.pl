#!/usr/bin/perl

package Mysql;

use DBI;
use strict;

# Parameters
#  host
#  port
#  username
#  password
#  zabbix instance
#  instance name

sub new {
    my $class = shift;
    my $self = {};
    my @dsnav = ();
    if (shift) { push @dsnav, "host=$_"; }
    if (shift) { push @dsnav, "port=$_"; }
    $self->{'dsn'} = "DBI:mysql:" . join(';',@dsnav);
    $self->{'user'} = shift;
    $self->{'pass'} = shift;
    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'mysql';

    bless($self,$class);
    return $self;
}

sub status {
    my $self = shift;
    my $z = $self->{'zabbix'};
    my $dbh = $self->{'dbh'};

    my $res = $dbh->selectall_arrayref("show status");
    foreach my $k (@{$res}) {
        $z->Add($self->{'name'} .'.status.'. $k->[0], $k->[1]);
    }
}

sub slavestatus {
    my $self = shift;
    my $z = $self->{'zabbix'};
    my $dbh = $self->{'dbh'};

    my $res = $dbh->selectrow_hashref("show slave status");
    foreach my $k (keys %{$res}) {
        if ( $res->{$k} ne '' ) {
            $z->Add($self->{'name'} . '.slave.' . $k, $res->{$k});
        }
    }
}

sub processlist {
    my $self = shift;
    my $z = $self->{'zabbix'};
    my $dbh = $self->{'dbh'};

    my $res = $dbh->selectall_hashref("show processlist", "Id");
    my $total = 0; my $active = 0;
    foreach my $p (values %{$res}) {
        if ($p->{'Command'} ne 'Sleep') { $active++ }
        $total++;
    }

    $z->Add($self->{'name'} . '.proc.active', $active);
    $z->Add($self->{'name'} . '.proc.total', $total);
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    while(1) {
        $self->{'dbh'} = DBI->connect($self->{'dsn'}, $self->{'user'}, $self->{'pass'});
        if ($self->{'dbh'}) {
            $z->Add($self->{'name'} . '.ping', 1);
            $self->status;
            $self->processlist;
            $self->slavestatus;
        } else {
            $z->Add($self->{'name'} . '.ping', 0);
        }
        $z->Send();
        $self->{'dbh'}->disconnect();
        undef $self->{'dbh'};
        sleep(15);
    }
}

1;
