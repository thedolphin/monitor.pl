Name:           monitor
Version:        0.10.1
Release:        1%{?dist}
Summary:        Perl-based Zabbix agent daemon

Group:          Applications/Internet
License:        GPL
URL:            http://www.wikimart.ru/
Source0:        monitor.tar.gz
Buildroot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Buildarch:      noarch

AutoReqProv:    no
Requires:       bash, perl, perl(Data::Dumper), perl(DBI), perl(DBD::mysql), perl(JSON), perl(JSON::XS)
Requires(post):     /sbin/chkconfig
Requires(preun):    /sbin/chkconfig

%description
Perl-based Zabbix agent daemon

%prep

%build

%install

rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT
tar -xzvf %{SOURCE0} -C $RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT

%post
/sbin/chkconfig --add monitor
/etc/init.d/monitor start

%preun
if [ "$1" = 0 ]
then
  /etc/init.d/monitor forcestop
  /sbin/chkconfig --del monitor
fi

%files
/etc/init.d/monitor
/etc/monitor.pl
%config(noreplace) /usr/bin/monitor.pl
/usr/lib/monitor/diskstats.pl
/usr/lib/monitor/memcache.pl
/usr/lib/monitor/monitor.pl
/usr/lib/monitor/mysql.pl
/usr/lib/monitor/nginx.pl
/usr/lib/monitor/nginxlog.pl
/usr/lib/monitor/process.pl
/usr/lib/monitor/zabbix.pl
/usr/lib/monitor/rabbit.pl
/usr/lib/monitor/sphinx.pl
/usr/lib/monitor/snmp.pl
/usr/lib/monitor/phpfpm.pl
/usr/lib/monitor/redis.pl
/usr/lib/monitor/ccissraid.pl

%changelog
* Thu Jan 17 2012 - dolphin@wikimart.ru
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
