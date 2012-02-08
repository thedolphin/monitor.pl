#!/usr/bin/perl

package Monitor;

use POSIX qw(setsid);
use strict;

sub new {
    my $class = shift;
    my $self = {};

    my $methods = shift;

    foreach my $method (@{$methods}) {
        my %child;
        $child{'name'} = $method->{'name'} .'@'. $method->{'zabbix'}->{'hostname'};
        $child{'ref'}  = $method;
        $child{'pid'} = 0;
        push @{$self->{'children'}}, { %child };
    }

    bless ($self, $class);
    return $self;
}

sub run {
    my $self = shift;

    $0 = "monitor [master]";

    while (1) {
        foreach my $child (@{$self->{'children'}}) {
            if ($child->{'pid'} == 0) {
                my $childname = $child->{'name'};
                print "waiting...\n";
                sleep(1);
                my $monpid = fork();
                if ($monpid) {
                    print "Started child $childname ($monpid)\n";
                    $child->{'pid'} = $monpid;
                } else {
                    $0 = "monitor: $childname";
                    my $ref = $child->{'ref'};
                    $ref->run();
                    sleep(15);
                    exit 1;
                }
            }
        }
        my $died = wait;
        foreach my $child (@{$self->{'children'}}) {
            if ($child->{'pid'} == $died) {
                my $childname = $child->{'name'};
                $child->{'pid'} = 0;
                print "Child $childname($died) died\n";
            }
        }
    }
}

sub burychildren {
        my $self = shift;

        print "Killing child processes\n";
        foreach my $child (@{$self->{'children'}}) {
            if ($child->{'pid'} != 0) {
                kill 15, $child->{'pid'};
            }
        }
}

sub daemonize {
    my $self = shift;

    my $pidfile = shift || "/var/run/$0.pid";
    my $logfile = shift || "/var/log/$0.log";

    if ( -s $pidfile ) {
        print "Already running? Check $pidfile\n";
        exit;
    }

    chdir '/'                 or die "Can't chdir to /: $!";

    open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
    open STDOUT, ">$logfile"  or die "Can't write to $logfile: $!";
    open STDERR, '>&STDOUT'   or die "Can't write to $logfile: $!";

    defined(my $pid = fork())   or die "Can't fork: $!";
    if ($pid) {
        print "Daemon started, pid $pid\n";
        exit;
    }

    setsid()                  or die "Can't start a new session: $!";

    open (my $pf, ">$pidfile") or die "Can't write to $pidfile: $!";
    print $pf $$;
    close ($pf);

    $SIG{TERM} = sub {
        $self->burychildren();
        unlink $pidfile;
        print "Terminated\n";
        exit;
    };

}

1;
