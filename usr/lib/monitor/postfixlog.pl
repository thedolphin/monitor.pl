#!/usr/bin/perl
package PostfixLog;

use strict;
use File::stat;
use Time::HiRes;
my %stat = ( delivered => 0, 
             received  => 0, 
             bounced   => 0, 
             rejected  => 0, 
             deferred  => 0, 
             deferrals => 0
           );

sub new {
    my $class = shift;
    my $self = {};
    $self->{'logfile'} = shift;
    $self->{'rotatedlog'} = shift;
    $self->{'pidf'} = shift;
    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'postfixlog';
    bless ($self, $class);
    return $self;
}

sub parse {
    my $fh;
    my @list;
    my @ids;
    my %hash;
    my $current_offset;
    my $stored_offset;
    my $stored_string;
    my $current_string;
    my $strexistflag;
    my $file = shift;
    my $offset = shift;
    my $modeflag = shift;

    if ($modeflag != 1 ) { 
        open ($fh, "<$offset") || die "$!";
        ($stored_offset, $stored_string) = split(/\|/, <$fh>);
        close($fh);
    }

    open ($fh, "<$file") || die "$!";

    while (<$fh>) {
        if (($strexistflag == 1) or ($modeflag == 1)) {
            if ($_ =~ /status=sent/) { $stat{'delivered'}++ }
            if ($_ =~ /postfix\/pickup/) { $stat{'received'}++ }
            if ($_ =~ /: client=/) { $stat{'received'}++ }
            if ($_ =~ /status=bounced/) { $stat{'bounced'}++ }
            if ($_ =~ /: reject:/) { $stat{'rejected'}++ }
            if ($_ =~ /status=deferred/){
                $stat{'deferrals'}++;
                @list = split;
                $hash{$list[5]}++;
            }
        } else {
            if (($. == $stored_offset) && ($_ eq $stored_string)) {
                $strexistflag = 1
            }
        }
        $current_string = $_;
        $current_offset = $.;
    }

    close $fh;
    open ($fh, ">$offset") || die "$!";
    print $fh $current_offset . '|' . $current_string;
    close $fh;
    @ids = keys %hash;
    $stat{'deferred'} += $#ids + 1;
    if (($strexistflag == 0) and ($modeflag == 0)) {parse($file,$offset,1)} ;
}

sub run {
    my $self = shift;
    my $zabbix = $self->{'zabbix'};
    my $logfile = $self->{'logfile'};
    my $offsetfile = $self->{'logfile'} . '.offset';
    my $rotatedlog = $self->{'rotatedlog'};
    my $ino = stat($logfile) -> ino;

    while(1) {
        my $fhpid;
        my $pid;
        my $ino_last;
        my $running = 0;
        my $sendflag = 1;
        if (open ($fhpid, "<" . $self->{'pidf'})) {
            $pid = <$fhpid>;
            $pid =~ s/ //g;
            close ($fhpid);
            chomp $pid;
            if ($pid =~ /\d+$/) {
                my @resp = `ps -o comm $pid`;
                chomp $resp[0];
                if ($resp[1] = 'master') {
                    $running = 1;
                } else { print "pid $pid is not Postfix\n"; }
            } else { print "pid '$pid' is not valid\n"; }
        } else { print "cannot open '" . $self->{'pidf'} . "': $!\n"; }

        if ($running) {
            if (-e $logfile) {
                if (not -e $offsetfile) { 
                    $sendflag = 0;
                    parse($logfile,$offsetfile,1);
                } else {
                    $ino_last = stat($logfile)->ino;
                    if ($ino_last == $ino){
                        parse($logfile,$offsetfile,0)
                    } elsif ($ino_last != $ino){
                        $ino = $ino_last;
                        parse($rotatedlog,$offsetfile,0);
                        parse($logfile,$offsetfile,1)
                    }
                }
                if ($sendflag == 1) {
                    foreach my $k (sort keys %stat) {
                        $zabbix->Add($self->{'name'} . '.' . $k, $stat{$k});
                    }
                }
            }
            $zabbix->Add($self->{'name'} . '.ping', '1');
        } else {
            $zabbix->Add($self->{'name'} . '.ping', '0');
        }
        foreach (keys %stat) { $stat{$_}=0 }
        $zabbix->Send();
        $sendflag = 1;
        sleep(15);
    }
}

1;