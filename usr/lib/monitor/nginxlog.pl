#!/usr/bin/perl

package NginxLog;

use strict;

sub new {
    my $class = shift;
    my $self = {};

    $self->{'logf'} = shift;
    $self->{'pidf'} = shift;
    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'nginxlog';

    bless ($self, $class);
    return $self;
}

sub run {
    my $self = shift;
    my $zabbix = $self->{'zabbix'};

    while(1) {
        my $fh;
        my $pid;
        my $running = 0;
        my %stat = ( 200 => 0, 301 => 0, 302 => 0, 304 => 0, 400 => 0, 404 => 0, 499 => 0, 500 => 0, 502 => 0, 503 => 0, 504 => 0);
        my %uas = ( yandex => 0, docomo => 0, msnbot => 0, sosospider => 0, bing => 0, baidu => 0, obot => 0, other => 0);
        my %php =( fast => 0, '1sec' => 0, '2sec' => 0, '5sec' => 0, '10sec' => 0, slow => 0);

        if (open ($fh, "<" . $self->{'pidf'})) {
            $pid = <$fh>;
            close ($fh);
            chomp $pid;
            if ($pid =~ /^\d+$/) {
                my @resp = `ps -o comm $pid`;
                chomp $resp[1];
                if ($resp[1] eq 'nginx') {
                    $running = 1;
                } else { print "pid $pid is not nginx\n"; }
            } else { print "pid '$pid' is not valid\n"; }
        } else { print "cannot open '" . $self->{'pidf'} . "': $!\n"; }

        if ($running) {
            my $logf = $self->{'logf'} . '.parse';
            rename ($self->{'logf'}, $logf) || die "$!";
            kill 30, $pid;
            sleep(1);
            open ($fh, "<$logf") || die "$!";
            while (<$fh>) {
                my ($date, $host, $status, $upstatus, $time, $upstream, $ua) = split /\|/;
                $stat{$status}++;
                if ($ua =~ /Yandex/)        { $uas{'yandex'}++ }
                elsif ($ua =~ /DoCoMo/)     { $uas{'docomo'}++ }
                elsif ($ua =~ /msnbot/)     { $uas{'msnbot'}++ }
                elsif ($ua =~ /Sosospider/) { $uas{'sosospider'}++ }
                elsif ($ua =~ /Googlebot/)  { $uas{'google'}++ }
                elsif ($ua =~ /Yahoo/)      { $uas{'yahoo'}++ }
                elsif ($ua =~ /bingbot/)    { $uas{'bing'}++  }
                elsif ($ua =~ /Baidu/)      { $uas{'baidu'}++ }
                elsif ($ua =~ /oBot/)       { $uas{'obot'}++  }
                else                        { $uas{'other'}++ }
                if ($upstream =~ /php/) {
                    if ($time <= 0.5)                  { $php{'fast'}++  }
                    elsif ($time <= 1 and $time > 0.5) { $php{'1sec'}++  }
                    elsif ($time <= 2 and $time > 1)   { $php{'2sec'}++  }
                    elsif ($time <= 5 and $time > 2)   { $php{'5sec'}++  }
                    elsif ($time <= 10 and $time > 5)  { $php{'10sec'} ++ }
                    else                               { $php{'slow'} ++ }
                }
            }
            close($fh);
            foreach my $k (sort keys %stat) {
                $zabbix->Add($self->{'name'} . '.status_' . $k, $stat{$k});
            }
            foreach my $k (sort keys %uas) {
                $zabbix->Add($self->{'name'} . '.ua_' . $k, $uas{$k});
            }
            foreach my $k (sort keys %php) {
                $zabbix->Add($self->{'name'} . '.php_' . $k, $php{$k});
            }
            $zabbix->Add($self->{'name'} . '.ping', '1');
        } else {
            $zabbix->Add($self->{'name'} . '.ping', '0');
        }
        $zabbix->Send();
        sleep(15);
    }
}

1;