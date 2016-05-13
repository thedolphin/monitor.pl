#!/usr/bin/perl

# Parts based on munin pgsql plugin, copyright (c) 2009 Magnus Hagander, Redpill Linpro AB

package PgSQL;

use DBI;
use strict;

sub new {
    my $class = shift;
    my $self = {};

    my @dsnav = ();
    push @dsnav, "host=$_" if $_ = shift;
    push @dsnav, "port=$_" if $_ = shift;

    my $dbname = shift || 'template1';
    push @dsnav, "dbname=$dbname";

    $self->{'dsn'} = "DBI:Pg:" . join(';',@dsnav);
    $self->{'user'} = shift;
    $self->{'pass'} = shift;
    $self->{'zabbix'} = shift;
    $self->{'name'} = shift || 'pgsql';

    bless($self,$class);
    return $self;
}

sub run {
    my $self = shift;
    my $z = $self->{'zabbix'};

    while(1) {
        $self->{'dbh'} = DBI->connect($self->{'dsn'}, $self->{'user'}, $self->{'pass'});

        if ($self->{'dbh'}) {
            $z->Add($self->{'name'} . '.ping', 1);

            $self->activity;
            $self->cache;
            $self->scans;
            $self->replication;

            $self->selectrow(
                    'select checkpoints_timed, checkpoints_req, buffers_checkpoint,'.
                           'buffers_clean,buffers_backend,buffers_alloc from pg_stat_bgwriter',
                'bgwriter_'
            );

            $self->selectcolumn(
                'select lower(mode) as key, count(*) as value from pg_locks group by mode', 'locks_',
                ['accesssharelock', 'rowsharelock',
                 'rowexclusivelock', 'shareupdateexclusivelock',
                 'sharelock', 'sharerowexclusivelock',
                 'exclusivelock', 'accessexclusivelock',
                 'applicationsharelock', 'applicationexclusivelock'
                ]
            );

            $self->selectrow('select sum(pg_database_size(oid)) as size,'.
                                    'sum(pg_stat_get_db_xact_commit(oid)) as xact_commit,'.
                                    'sum(pg_stat_get_db_xact_rollback(oid)) as xact_rollback '.
                                'from pg_database', '');

        } else {
            $z->Add($self->{'name'} . '.ping', 0);
        }
        $z->Send();
        $self->{'dbh'}->disconnect();
        undef $self->{'dbh'};
        sleep(30);
    }
}

sub activity {
    my $self = shift;
    my $dbname = shift;

    my $activity = {
        'waiting'    => 0,
        'active'     => 0,
        'waiting'    => 0,
        'autovacuum' => 0,
        'idle_tx'    => 0,
        'unknown'    => 0,
        'total'      => 0
       };

    my $timings = {
        'active'     => 0,
        'autovacuum' => 0
       };

    my $sql = "select state,date_part('epoch', now() - query_start) as time,query from pg_stat_activity";
    my $ref = $self->{'dbh'}->selectall_arrayref($sql);

    foreach my $row (@{$ref}) {

            my ($state, $time, $query) = @{$row};
            $activity->{'total'}++;

            if ($state =~ /^(waiting|idle)/) {
                $state =~ s/ in transaction.*/_tx/;
                $activity->{$state}++;
            } elsif (
                    $state eq 'disabled' or
                    $query eq '<insufficient privilege>' ) {
                $activity->{'unknown'}++;
            } else {
                $state = $query =~ /^autovacuum: / ? 'autovacuum' : 'active';
                $activity->{$state}++;
                $timings->{$state} = int($time) if $timings->{$state} < $time;
            }
    }

    while (my ($key, $value) = each %{$activity}) {
        $self->{'zabbix'}->Add($self->{'name'} .'.activity_'. $key, $value);
    }

    while (my ($key, $value) = each %{$timings}) {
        $self->{'zabbix'}->Add($self->{'name'} .'.activity_'. $key .'_time', $value);
    }
}

sub selectrow {
    my ($self, $sql, $prefix) = @_;

    my $ref = $self->{'dbh'}->selectrow_hashref($sql);

    while (my ($key, $value) = each %{$ref}) {
        $self->{'zabbix'}->Add($self->{'name'} .'.'. $prefix . $key, $value);
    }
}

sub selectcolumn {
    my ($self, $sql, $prefix, $keys, $defv) = @_;

    my $ref = $self->{'dbh'}->selectall_hashref($sql, 'key');

    my %res = map { $_ => $defv || 0 } @{$keys};

    while(my ($key, $value) = each %{$ref}) {
        $res{$key} = $value->{'value'};
    }

    while (my ($key, $value) = each %res) {
        $self->{'zabbix'}->Add($self->{'name'} .'.'. $prefix . $key, $value);
    }
}

sub cache {
    my $self = shift;

    my $ref = $self->{'dbh'}->selectrow_hashref("select sum(blks_read) AS blks_read, sum(blks_hit) AS blks_hit FROM pg_stat_database");

    $self->{'zabbix'}->Add($self->{'name'} .'.db_blks_read', $ref->{'blks_read'});
    $self->{'zabbix'}->Add($self->{'name'} .'.db_blks_hitrate', int(($ref->{'blks_hit'} * 100) / ($ref->{'blks_hit'} + $ref->{'blks_read'})));
}

sub scans {
    my $self = shift;

    my %res = (
        'system_index' => 0,
        'system_table' => 0,
        'user_index'   => 0,
        'user_table'   => 0
    );

    my $total = 0;

    my $sql = "SELECT n.nspname, c.relkind, sum(pg_stat_get_numscans(c.oid))
            FROM pg_class c LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind in ('r','i','t')
            GROUP BY n.nspname, c.relkind ";

    my $ref = $self->{'dbh'}->selectall_arrayref($sql);

    foreach my $row (@{$ref}) {

        my $ns = ($row->[0] eq 'pg_catalog' || $row->[0] eq 'information_schema') ? 'system' : 'user';
        my $type = $row->[1] eq 'i' ? 'index' : 'table';

        $res{$ns .'_'. $type} += $row->[2];
        $total += $row->[2];

    }

    while (my ($key, $value) = each %res) {
        $self->{'zabbix'}->Add($self->{'name'} .'.'. $key .'_scans', $value);
    }
}

sub replication {
    my $self = shift;

    my $sql = "select state as replication_state,
                   sent_location - write_location as replica_write_queue,
                   pg_current_xlog_location() - sent_location as master_send_queue,
                   trunc(extract(epoch from backend_start)) as replica_start_time from pg_stat_replication";

    my $ref = $self->{'dbh'}->selectall_arrayref($sql, { Slice => {} });

    if (scalar(@{$ref}) > 0) {
        while (my ($key, $value) = each %{$ref->[0]}) {
            if ($key eq "replication_state") {
                $value = $value eq "streaming" ? 1 : 0;
            } else {
                $value = 0 if $value < 0;
            }
            $self->{'zabbix'}->Add($self->{'name'} .'.'. $key, $value);
        }
    } else {
        $self->{'zabbix'}->Add($self->{'name'} .'.replication_state', 0);
    }
}

1;
