package Virtualmin::Config::Plugin::MySQL;
use strict;
use warnings;
no warnings qw(once);
use parent 'Virtualmin::Config::Plugin';

our $config_directory;
our (%gconfig, %miniserv);
our $trust_unknown_referers = 1;

sub new {
  my $class = shift;
  # inherit from Plugin
  my $self = $class->SUPER::new(name => 'MySQL');

  return $self;
}

# actions method performs whatever configuration is needed for this
# plugin. TODO Needs to make a backup so changes can be reverted.
sub actions {
  my $self = shift;

  use Cwd;
  my $cwd = getcwd();
  my $root = $self->root();
  chdir($root);
  $0 = "$root/init-system.pl";
  push(@INC, $root);
  eval 'use WebminCore'; ## no critic
  init_config();

  $self->spin();
  if ($gconfig{'os_type'} eq "freebsd" ||
      init::action_status("mysql")) {
    init::enable_at_boot("mysql");
  } else {
    init::enable_at_boot("mysqld");
  }
  init::enable_at_boot("postgresql");
  foreign_require("mysql", "mysql-lib.pl");
  if (mysql::is_mysql_running()) {
    mysql::stop_mysql();
  }
  my $conf = mysql::get_mysql_config();
  my ($sect) = grep { $_->{'name'} eq 'mysqld' } @$conf;
  if ($sect) {
    mysql::save_directive($conf, $sect,
        "innodb_file_per_table", [ 1 ]);
    flush_file_lines($sect->{'file'});
  }
  my $err = mysql::start_mysql();
  if ($err) { $self->done(0); } # Something went wrong.
  else { $self->done(1); } # OK!
}

1;
