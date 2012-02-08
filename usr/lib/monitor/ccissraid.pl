#!/usr/bin/perl

package ccissraid;

use strict;

sub new {
    if (! -x '/usr/bin/cciss_vol_status') {die 'Please install cciss_vol_status'}
    my $class = shift;
    my $self = {};
    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'ccissraid';
    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};
    while(1) {
        my $status = 1;
        my @text = shift;
        opendir(my $dh, '/dev/cciss') || die $!;
        my @names = map {"/dev/cciss/$_"} grep {/c\d+d\d+$/} readdir($dh);
        closedir $dh;
        my $param = join(' ', @names);
        @text = `/usr/bin/cciss_vol_status $param`;
        if (scalar(@text) == 0) {
            $status = 0;
        }
        else
        {
            foreach my $line (@text) {
                chomp $line;
                if (!( $line =~ /OK\. $/)) {
                    $status = 0;
                    last;
                }
            }
        }
        $z->Add($self->{'name'} . '.status', $status);
        $z->Send();
        sleep(15);
    }
}

1;
