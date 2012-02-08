#!/usr/bin/perl

package Process;

use strict;

# Parameters:
#   invocation command
#   zabbix item class name
#   zabbix instance
#   pidfile (optional, assuming not a daemon if empty)
#   startup delay, time between invocation and monitoring start, 1 sec by default
#

sub new {
    my $class = shift;
    my $self = {};

    $self->{'exec'}   = shift;
    $self->{'name'}   = shift;
    $self->{'zabbix'} = shift;
    $self->{'pifd'}   = shift;
    $self->{'delay'}  = shift || 1;

    bless ($self, $class);
    return $self;
}

sub getpid {
    my $self = shift;

    my $pidf = $self->{'pidf'};
    my $pidfh;

    if(open($pidfh, "<$pidf")) {
        my $pid = <$pidfh>;
        chomp $pid;
        close($pidf);
        if ($pid =~ /^\d+$/ && kill (0, $pid)) {
            return $pid;
        }
    }
}

sub run {
    my $self = shift;
    my $zabbix = $self->{'zabbix'};
    my $pid;

    if ($self->{'pidf'}) {
        if($pid = $self->getpid()) {
            waitpid ($pid, 0);
        }

        $zabbix->Add($self->{'name'} . '.started', time);
        $zabbix->Send();
        system ($self->{'exec'});
        sleep($self->{'delay'});
    }
}

1;
