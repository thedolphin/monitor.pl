#!/usr/bin/perl

package DiskUsage;

use strict;

sub new {
    my $class = shift;
    my $self = {};

    $self->{'zabbix'} = shift;
    $self->{'name'} = shift;

    $self->{'paths'} = \@_;

    bless($self,$class);
    return $self;
}

sub du {
    my $self = shift;
    my $dir = shift;
    my $du = shift || 0;

    opendir(my $dh, $dir);
    my @files = readdir($dh);
    closedir($dh);

    foreach my $file (sort @files) {
        next if $file =~ /^\.\.?$/;
        my $path = $dir .'/'. $file;
        my $sz = (stat($path))[7];
        if ( -d _ ) {
            $du = $self->du($path, $du);
        } else {
            $du += $sz;
        }
    }

    return $du;
}


sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    while(1) {

        my $du = 0;
        foreach my $file (@{$self->{'paths'}}) {
            my $sz = (stat($file))[7];
            if ( -d _ ) {
                $du = $self->du($file, $du);
            } else {
                $du += $sz;
            }
        }

        $z->Add('diskusage.'. $self->{'name'}, $du);
        $z->Send();

        sleep(60);
    }
}

1;
