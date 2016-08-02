%define _unpackaged_files_terminate_build 0

Name:           monitor
Version:        0.18.2
Release:        2%{?dist}
Summary:        Perl-based Zabbix agent daemon

Group:          Applications/Internet
License:        GPL

Buildarch:      noarch

AutoReqProv:    no
Requires:       bash, perl, perl(Data::Dumper), perl(JSON)

Source0:        https://github.com/thedolphin/monitor.pl/archive/%{version}.tar.gz

%description
Perl-based Zabbix agent daemon

%prep
%setup -n monitor.pl-%{version}

%install
%{__cp} -r . $RPM_BUILD_ROOT

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%config(noreplace) /etc/monitor.pl
/usr/lib/systemd/system/monitor.service
/usr/lib/monitor/*
/usr/share/monitor/*

%changelog
* Tue Aug  2 2016 - a.rumyantsev@rambler-co.ru
- v0.19.0 LLD version of rabbit module

* Tue Jul 12 2016 - a.rumyantsev@rambler-co.ru
- v0.18.0 Ethtool and MDRaid modules
- v0.18.1 Small fixes

* Mon Jul 11 2016 - a.rumyantsev@rambler-co.ru
- v0.17.3 Mysql non-standard socket location support

* Mon Feb  8 2016 - arum@1c.ru
- v0.17.1 PostgreSQL replication basic monitoring

* Mon Jan 25 2016 - arum@1c.ru
- v0.17.0 Initial PostgreSQL support added

* Mon Dec 14 2015 - arum@1c.ru
- v0.16.1 Switched to systemd, zabbix host name defaults to system hostname

* Mon Aug 25 2014 - dolphin@wikimart.ru
- v0.15.0 DiskUsage module added

* Tue Jul 29 2014 - dolphin@wikimart.ru
- v0.14.0 Haproxy module added

* Mon Jul 14 2014 - dkhlynin@wikimart.ru
- v0.13.1 Added php_avg_resp_time to NginxLog module

* Wed Jul 09 2014 - dolphin@wikimart.ru
- v0.13.0 LLD version of DiskStat added

* Wed Jun 04 2014 - dolphin@wikimart.ru
- v0.12.5 Mysql & Megaraid fixes

* Thu Jan 30 2014 - dolphin@wikimart.ru
- v0.12.4 Mysql Innodb_row_lock_current_waits fix

* Thu Jan 23 2014 - dolphin@wikimart.ru
- v0.12.3 NginxLog fixed

* Wed Dec 04 2013 - dolphin@wikimart.ru
- v0.12.2 Redis protocol fix

* Fri Oct 18 2013 - dolphin@wikimart.ru
- v0.12.1 Nginxlog module portability fix

* Sat Oct 05 2013 - dolphin@wikimart.ru
- v0.12.0 Megaraid module added

* Wed Oct 03 2012 - dkhlynin@wikimart.ru 
- v0.11.2 ccissraid: added CentOS-6 support

* Thu Sep 06 2012 - dolphin@wikimart.ru
- v0.11.1 Tool for generating complex zabbix templates for cisco networking hardware

* Mon Aug 13 2012 - dkhlynin@wikimart.ru
- v0.11.0 Added postfix module & logrotate configuration file

* Sun Feb 12 2012 - dolphin@wikimart.ru
- v0.10.2 Rabbit node memory usage added

* Tue Jan 17 2012 - dolphin@wikimart.ru
- v0.10.1 Redis hitrate added

* Thu Nov 24 2011 - dkhlynin@wikimart.ru
- v0.10.0 CCISS RAID module added

* Wed Oct 12 2011 - dolphin@wikimart.ru
- v0.9.0 Redis module added

* Mon Oct 10 2011 - dolphin@wikimart.ru
- v0.8.0 Diskstats module rewritten

* Thu Oct 6 2011 - dolphin@wikimart.ru
- v0.7.0 PHP FPM module improvement and code cleanup, versioning changed

* Tue Oct 4 2011 - dolphin@wikimart.ru
- v0.0.6 Added PHP FPM module

* Fri Sep 30 2011 - dolphin@wikimart.ru
- v0.0.5 Added snmp module

* Tue Jul 26 2011 - dolphin@wikimart.ru
- v0.0.4 Added sphinx module

* Tue Jul 26 2011 - dolphin@wikimart.ru
- v0.0.3 Added rabbitmq monitoring via rabbit_management plugin

* Tue Jul 5 2011 - dolphin@wikimart.ru
- v0.0.2 Added hit_rate, free_mem to memcache module

* Tue Jul 5 2011 - dolphin@wikimart.ru
- v0.0.1 Initial packaging
