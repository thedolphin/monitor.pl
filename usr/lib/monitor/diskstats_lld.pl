#!/usr/bin/perl

package DiskStatsLLD;

use strict;

use JSON;

sub new {

    my $class = shift;
    my $self = {
        'zabbix' => shift,
        'diskfilter' => shift,
        'name' => 'diskstats'
    };

    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    my @keynames = ( 
        "reads",
        "reads_merged",
        "sectors_read",
        "reads_time",
        "writes",
        "writes_merged",
        "sectors_written",
        "writes_time",
        "io_queue",
        "io_time",
        "weighted_io_time"
    );

    while(1) {

        my $discovery = {};

        if(open(my $dh, "</proc/diskstats")) {
            my @text = <$dh>;
            close($dh);

            foreach my $line (@text) {
                chomp $line;

                my @values = (split /\ +/, $line)[3..14];
                my $name = shift @values;

                next if $self->{'diskfilter'} && $name !~ /$self->{'diskfilter'}/o;

                push @{$discovery->{'data'}}, {'{#DEVNAME}' => $name};

                for my $i (0 .. $#keynames) {
                    $z->Add('diskstats.'. $keynames[$i] .'['. $name  .']', $values[$i]);
                }
            }

            $z->Add('diskstats.discovery', encode_json $discovery);

            $z->Send();
        }

        sleep(30);
    }
}

1;
