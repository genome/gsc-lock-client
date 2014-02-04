#!/usr/bin/env perl

use strict;
use warnings;

use GSCLockClient::Keychain::Daemon::Claim;

use JSON;
use Carp;
use Test::More tests => 14;

test_failed_constructor();
test_constructor();
test_start_state_machine();

sub test_failed_constructor {

    my $claim;

    $claim = eval { GSCLockClient::Keychain::Daemon::Claim->new() };
    ok($@, 'Calling new() without args throws an exception');

    my %all_params = (
            url => 'http://test.org',
            resource_name => 'foo',
            keychain => 'bar',
        );
    foreach my $missing_arg ( keys %all_params ) {
        my %args = %all_params;
        delete $args{$missing_arg};

        $claim = eval { GSCLockClient::Keychain::Daemon::Claim->new( %args ) };
        like($@,
            qr($missing_arg is a required param),
            "missing arg $missing_arg throws an exception");
    }
}

sub test_constructor {
    my $claim;
    my $keychain = GSCLockClient::Keychain::Daemon::Fake->new();

    my $url = 'http://example.org';
    my $resource_name = 'foo';
    $claim = GSCLockClient::Keychain::Daemon::TestClaim->new(
                url => $url,
                resource_name => $resource_name,
                keychain => $keychain,
            );
    ok($claim, 'Create Claim');
}

sub test_start_state_machine {

    my $keychain = GSCLockClient::Keychain::Daemon::Fake->new();
    my $url = 'http://example.org';
    my $resource_name = 'foo';
    my $claim = GSCLockClient::Keychain::Daemon::TestClaim->new(
                keychain => $keychain,
                resource_name => $resource_name,
                url => $url,
            );
    ok($claim, 'Create new Claim');
    is($claim->state, 'new', 'Newly created Claim is in state new');

    $claim->expected_state_transitions('registering');
    ok($claim->start(),'start()');
    is(scalar($claim->remaining_state_transitions), 0, 'expected state transitions for start()');

    my $params = $claim->_http_post_params();
    is(scalar(@$params), 1, 'Sent 1 http post');

    my $json = JSON->new();
    my $got_url = shift @{$params->[0]};
    is($got_url, "${url}/claims", 'post URL param');

    my $got_body = $json->decode(shift @{$params->[0]});
    is_deeply($got_body,
            { resource => $resource_name },
            'post body param');

    my $got_cb = pop @{$params->[0]};
    is(ref($got_cb), 'CODE', 'Callback set in post params');

    is_deeply($params->[0],
              [ 'Content-Type' => 'application/json' ],
              'headers in http post');
}


package GSCLockClient::Keychain::Daemon::TestClaim;
BEGIN {
    our @ISA = qw( GSCLockClient::Keychain::Daemon::Claim );
}

sub new {
    my $class = shift;
    my %params = @_;
    my $expected = delete $params{expected_state_transitions};

    my $self = $class->SUPER::new(%params);
    $self->expected_state_transitions(@$expected) if $expected;
    return $self;
}

sub expected_state_transitions {
    my $self = shift;
    my @expected = @_;
    $self->{_expected_state_transitions} = \@expected;
}

sub remaining_state_transitions {
    return @{shift->{_expected_state_transitions}};
}

sub state {
    my $self = shift;
    unless (@_) {
        return $self->SUPER::state();
    }
    my $next = shift;
    my $expected_next_states = $self->{_expected_state_transitions};
    if ($expected_next_states) {
        Carp::croak("Tried to switch to state $next and there was no expected next state") unless (@$expected_next_states);
        my $expected_next = shift @$expected_next_states;
Test::More::diag "going from ".$self->SUPER::state()." to $next, expecting $expected_next";
        Carp::croak("next state $next does not match expected next state $expected_next") unless ($next eq $expected_next);
    }
    $self->SUPER::state($next);
}

sub _send_http_post {
    my $self = shift;
    my @params = @_;

    $self->{_http_post_params} ||= [];
    push @{$self->{_http_post_params}}, \@params;
}

sub _http_post_params {
    return shift->{_http_post_params};
}


package GSCLockClient::Keychain::Daemon::Fake;
sub new {
    my $class = shift;
    return bless {}, $class;
}

sub claim_failed {

}

sub claim_succeeded {

}



