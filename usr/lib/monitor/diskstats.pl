#!/usr/bin/perl

package DiskStats;

use strict;

sub new {
    my $class = shift;
    my $self = {};
    $self->{'zabbix'} = shift;
    $self->{'diskmap'} = shift || { 'disk0' => 'cciss/c0d0' };
    $self->{'name'} = shift || 'diskstats';
    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    my @keynames = ( "reads",
                "reads_merged",
                "sectors_read",
                "reads_time",
                "writes",
                "writes_merged",
                "sectors_written",
                "writes_time",
                "io_queue",
                "io_time",
                "weighted_io_time" );
    my $stats = {};

    while(1) {
        if(open(my $dh, "</proc/diskstats")) {
            my @text = <$dh>;
            close($dh);

            foreach my $line (@text) {
                chomp $line;
                my @values = (split /\ +/, $line)[3..14];
                my $name = shift @values;
                $stats->{$name} = {};
                my $keyindex = 0;
                foreach my $value (@values) {
                    $stats->{$name}->{$keynames[$keyindex++]} = $value;
                }
            }

            foreach my $alias (keys %{$self->{'diskmap'}}) {
                my $disk = $self->{'diskmap'}->{$alias};
                foreach my $item (keys %{$stats->{$disk}}) {
                    $z->Add($self->{'name'} .'.'. $alias .'.'. $item, $stats->{$disk}->{$item});
                }
            }
            $z->Send();
            sleep(15);
        }
    }
}

1;
