#!/usr/bin/perl

use warnings;
use strict;
use Mojolicious::Lite;
use Config::Simple;
use Log::Log4perl qw(get_logger);
use JSON;

# Ensure Devel::Cover is included if not already set in the environment
BEGIN {
	if ($ENV{HARNESS_PERL_SWITCHES}) {
		eval {
			require Devel::Cover;
			Devel::Cover->import();
			print "Devel::Cover is correctly initialized\n";
		};
		if ($@) {
			die "Failed to initialize Devel::Cover: $@\n";
		}
	}
}

use lib '/root/daemon/lib';
use PerlApp::Perlapp;

my $config_file_path = '/usr/local/etc/perlapp/perlapp.conf';
my $cfg = Config::Simple->new($config_file_path) or die Config::Simple->error();

my $logger_conf_path = $cfg->param('logger.configfile');
Log::Log4perl::init($logger_conf_path);
my $logger = get_logger("PerlApp::Perlapp");

# Initialize PerlApp module
my $perlApp = PerlApp::Perlapp->instance($logger);

# Route to handle HTTP POST requests with JSON payload
post '/jsonrpc' => sub {
	my $c = shift;
	# log request
	$logger->info($c->req->body);

	# Get JSON from request
	my $json_payload = $c->req->json;

	if (!$json_payload) {
		$logger->error("Invalid JSON request.");
		return $c->render(json => { faultCode => 400, faultString => "Invalid JSON request" }, status => 400);
	}

	# Check if the method is 'getTnbList'
	if ($json_payload->{method} && $json_payload->{method} eq 'getTnbList') {
		my $result;
		eval {
			$logger->info("Method called correctly");
			$result = $perlApp->getTnbList($json_payload);
		};
		if ($@) {
			$logger->error("Error processing request: $@");
			return $c->render(json => { faultCode => 500, faultString => "Internal server error" }, status => 500);
		}

		# Return the result as JSON
		return $c->render(json => $result);
	}
	if ($json_payload->{method} && $json_payload->{method} eq 'healthCheck') {
	my $result;
	eval {
		$logger->info("Method called correctly");
		$result = $perlApp->healthCheck($json_payload);
	};
	if ($@) {
		$logger->error("Error processing request: $@");
		return $c->render(json => { faultCode => 500, faultString => "Internal server error" }, status => 500);
	}

	# Return the result as JSON
	return $c->render(json => $result);
}

	else {
		return $c->render(json => { faultCode => 400, faultString => "Unknown method" }, status => 400);
	}
};

# Start the Mojolicious server
app->start;

if ($ENV{HARNESS_PERL_SWITCHES}) {
	# Ensure proper cleanup on termination
	$SIG{TERM} = sub {
		print "Received TERM signal, exiting...\n";
		# Make sure to end coverage collection
		if (eval {require Devel::Cover}) {
			Devel::Cover->finish;
		}
		exit 0;
	};
}

__DATA__