package Nessy::Daemon::StateMachine;

use strict;
use warnings;
#use warnings FATAL => 'all';

use Nessy::StateMachineFactory;

our $factory = Nessy::StateMachineFactory->new();


# ---------------------------- States ----------------------------------------
# Start state
our $s_new = $factory->define_start_state('NEW');

# Final states
our $s_aborted   = $factory->define_state('ABORTED');
our $s_done      = $factory->define_state('DONE');
our $s_fail      = $factory->define_state('FAIL');
our $s_released  = $factory->define_state('RELEASED');
our $s_withdrawn = $factory->define_state('WITHDRAWN');

# Long-lasting (wait) states
our $s_active  = $factory->define_state('ACTIVE');
our $s_waiting = $factory->define_state('WAITING');

# Acting states
our $s_aborting    = $factory->define_state('ABORTING');
our $s_activating  = $factory->define_state('ACTIVATING');
our $s_registering = $factory->define_state('REGISTERING');
our $s_releasing   = $factory->define_state('RELEASING');
our $s_renewing    = $factory->define_state('RENEWING');
our $s_withdrawing = $factory->define_state('WITHDRAWING');

# "Wait for retry" states
our $s_retrying_abort    = $factory->define_state('RETRYING_ABORT');
our $s_retrying_activate = $factory->define_state('RETRYING_ACTIVATE');
our $s_retrying_register = $factory->define_state('RETRYING_REGISTER');
our $s_retrying_release  = $factory->define_state('RETRYING_RELEASE');
our $s_retrying_renew    = $factory->define_state('RETRYING_RENEW');
our $s_retrying_withdraw = $factory->define_state('RETRYING_WITHDRAW');


# ---------------------------- Events ----------------------------------------
# Start event
our $e_start = $factory->define_event('START', 'command_interface');

# Machine driven events
our $e_activate = $factory->define_event('ACTIVATE', 'command_interface', 'timer_seconds'); # 201
our $e_conflict = $factory->define_event('CONFLICT', 'command_interface'); # 409
our $e_success  = $factory->define_event('SUCCESS', 'command_interface'); # 200, 204 (2xx)
our $e_timer    = $factory->define_event('TIMER', 'command_interface');
our $e_wait     = $factory->define_event('WAIT', 'command_interface'); # 202

# User driven events
our $e_abort    = $factory->define_event('ABORT', 'command_interface');
our $e_release  = $factory->define_event('RELEASE', 'command_interface');
our $e_withdraw = $factory->define_event('WITHDRAW', 'command_interface');  # Triggered by timeout

# Error events
our $e_fatal_error     = $factory->define_event('FATAL_ERROR', 'command_interface'); # 4xx
our $e_retryable_error = $factory->define_event('RETRYABLE_ERROR',
    'command_interface', 'timer_seconds');


# ---------------------------- Actions ---------------------------------------

sub a_register_claim {
    my ($from, $event, $to) = @_;
    $event->command_interface->register_claim();
}

sub a_create_timer {
    my ($from, $event, $to) = @_;
    $event->command_interface->create_timer(seconds => $event->timer_seconds);
}

sub a_notify_lock_active {
    my ($from, $event, $to) = @_;
    $event->command_interface->notify_lock_active();
}

sub a_delete_timer {
    my ($from, $event, $to) = @_;
    $event->command_interface->delete_timer();
}

sub a_release_claim {
    my ($from, $event, $to) = @_;
    $event->command_interface->release_claim();
}

sub a_notify_lock_released {
    my ($from, $event, $to) = @_;
    $event->command_interface->notify_lock_released();
}


# ---------------------------- Transitions -----------------------------------
$factory->define_transitions(

[$s_new              , $e_start           , $s_registering      , [\&a_register_claim       ]                         ],
[$s_registering      , $e_activate        , $s_active           , [\&a_create_timer         , \&a_notify_lock_active ]],
[$s_active           , $e_release         , $s_releasing        , [\&a_delete_timer         , \&a_release_claim      ]],
[$s_releasing        , $e_success         , $s_released         , [\&a_notify_lock_released ]                         ],
[$s_releasing        , $e_retryable_error , $s_retrying_release , [\&a_create_timer         ]                         ],
[$s_retrying_release , $e_timer           , $s_releasing        , [\&a_release_claim        ]                         ],

);


1;
