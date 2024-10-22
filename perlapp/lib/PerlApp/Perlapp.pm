package PerlApp::Perlapp;
use strict;
use warnings;

use JSON;
use Data::Dumper;
use Encode;
use DBI;

my $instance; # Singleton instance
my $logger;
my $db;

sub instance {
	my ($class, $log_instance) = @_;

	# Return the existing instance if it exists
	return $instance if defined $instance;

	my $self = {
		debug => 1,
	};

	# Store the logger instance for use in this module
	$logger = $log_instance if $log_instance;

	$instance = bless $self, $class;

	$self->_connect_to_db();

	return $instance;
}

# Database connection method
sub _connect_to_db {
	my ($self) = @_;

	my $dsn = "DBI:mysql:database=shareddb;host=db;port=3306";
	my $username = "root";  # Replace with your MySQL username
	my $password = "root";  # Replace with your MySQL password

	# Establish connection to the MySQL database
	$db = DBI->connect($dsn, $username, $password, {
		RaiseError => 1,
		AutoCommit => 1,
		mysql_enable_utf8 => 1,
	}) or die $DBI::errstr;

	$logger->info("Connected to the database");
}

sub getTnbList
{
	my ($self, $json) = @_;
	my $param = $json->{params};

	$logger->info("Fetching TNB list from the database");
	my $sth = $db->prepare("SELECT * FROM tnbs");
	$sth->execute();
	my $tnbs_from_db = $sth->fetchall_arrayref({});
	my $tnb;

	my $number = $param->{number};

	if ($number) {
		$sth = $db->prepare("SELECT tnb FROM tnbs WHERE tnb = ?");
		$sth->execute($number);
		($tnb, undef) = $sth->fetchrow_array();
	}

	my @tnbs;
	push(@tnbs, {tnb => "D001", name => "Deutsche Telekom", isTnb => (defined $tnb && $tnb eq "D001" ? JSON::true : JSON::false)});
	foreach (@{$tnbs_from_db}) {
		if ($_->{tnb} =~/(D146|D218|D248)/) {
			next;
		}
		eval {
			push(@tnbs, {tnb => $_->{tnb}, name => $_->{name}, isTnb => (defined $tnb && $tnb eq $_->{tnb} ? JSON::true : JSON::false)});
		};
	}

	@tnbs = sort {lc $a->{name} cmp lc $b->{name}} @tnbs;

	return {faultCode => "200", faultString => "Method success", tnbs => \@tnbs};
}

sub healthCheck
{
	my ($self, $json) = @_;

	my $jsonrpc = $json->{jsonrpc};
	my $id = $json->{id};

	return {id => $id, error => undef, result => {faultCode => "200", faultString => "Method success"}, version => $jsonrpc};
}

1;
