# == Class: spil_mysql::server::mysqlstatsd
#
# Class to install mysql statsd collector on a mysql host.
#
# === Parameters
#
# [*mysqlstatsd_password*]
#   Passowrd mysql statsd uses for connecting to mysql server.
#
class spil_mysql::server::mysqlstatsd (
  $mysqlstatsd_password = $spil_mysql::params::mysqlstatsd_password,
  ) inherits spil_mysql::params {

  package{ 'spil-libs-mysql-statsd':
    ensure => installed,
  }

  file{'mysqlstatsd_logdir':
    ensure => 'directory',
    path   => '/var/log/mysql_statsd/',
    owner  => 'root',
    group  => 'admin',
    mode   => '2750'
  }

  file{'mysqlstatsd_daemon':
    path   => '/etc/rc.d/init.d/mysql_statsd',
    owner  => 'root',
    group  => 'admin',
    mode   => '0750',
    source => "puppet:///modules/${module_name}/mysql_statsd"
  }

  file{'mysqlstatsd_conf':
    path    => '/etc/mysql-statsd.conf',
    owner   => 'root',
    group   => 'admin',
    mode    => '0640',
    content => template("${module_name}/mysql-statsd.conf.erb")
  }

  file{'mysqlstatsd_cron':
    path   => '/etc/cron.d/SPI-mysql_statsd.cron',
    owner  => 'root',
    group  => 'admin',
    mode   => '0640',
    source => "puppet:///modules/${module_name}/SPI-mysql_statsd.cron"
  }
}
