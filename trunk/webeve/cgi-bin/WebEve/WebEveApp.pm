package WebEve::WebEveApp;

use strict;

use base 'CGI::Application';

# -------------------------------------------------------------------------
# The official init-Method
#
sub cgiapp_init
{
    my $self = shift;

    # Prepare some stuff
    # --------------------------------
    my $MainTmpl = $self->param('MainTmpl');
    $self->{MainTmpl} = $self->load_tmpl( $MainTmpl ? $MainTmpl : 'main.tmpl' );    

    print STDERR $self->dump() if $self->param('debug');
}

# -------------------------------------------------------------------------
# Overload run() (Mostly unchanged from CGI::Application)
# Added automatic main template support
#
sub run {
        my $self = shift;
        my $q = $self->query();

        my $rm_param = $self->mode_param() || croak("No rm_param() specified");

        my $rm;

        # Support call-back instead of CGI mode param
        if (ref($rm_param) eq 'CODE') {
                # Get run-mode from subref
                $rm = $rm_param->($self);
        } else {
                # Get run-mode from CGI param
                $rm = $q->param($rm_param);
        }

        # If $rm undefined, use default (start) mode
        my $def_rm = $self->start_mode() || '';
        $rm = $def_rm unless (defined($rm) && length($rm));

        # Set get_current_runmode() for access by user later
        $self->{__CURRENT_RUNMODE} = $rm;

        # Allow prerun_mode to be changed
        delete($self->{__PRERUN_MODE_LOCKED});

        # Call PRE-RUN hook, now that we know the run-mode
        # This hook can be used to provide run-mode specific behaviors
        # before the run-mode actually runs.
        $self->cgiapp_prerun($rm);

        # Lock prerun_mode from being changed after cgiapp_prerun()
        $self->{__PRERUN_MODE_LOCKED} = 1;

        # If prerun_mode has been set, use it!
        my $prerun_mode = $self->prerun_mode();
        if (length($prerun_mode)) {
                carp ("Replacing previous run-mode '$rm' with prerun_mode '$prerun_mode'") if ($^W);
                $rm = $prerun_mode;
                $self->{__CURRENT_RUNMODE} = $rm;
        }

        my %rmodes = ($self->run_modes());

        my $rmeth;
        my $autoload_mode = 0;
        if (exists($rmodes{$rm})) {
                $rmeth = $rmodes{$rm};
        } else {
                # Look for run-mode "AUTOLOAD" before dieing
                unless (exists($rmodes{'AUTOLOAD'})) {
                        croak("No such run-mode '$rm'");
                }
                carp ("No such run-mode '$rm'.  Using run-mode 'AUTOLOAD'") if ($^W);
                $rmeth = $rmodes{'AUTOLOAD'};
                $autoload_mode = 1;
        }

        # Process run mode!
        my $body = eval { $autoload_mode ? $self->$rmeth($rm) : $self->$rmeth() };
        die "Error executing run mode '$rm': $@" if $@;

        # Set up HTTP headers
        my $headers = $self->_send_headers();

        # Build up total output
        my $output = $headers;

	# ----------------------------------------------------------
	# Changes by cwh@suse.de

	# Fill in all the stuff in Main Template
        # Support return as SCALARREF
        if (ref($body) eq 'SCALAR') {
                $self->{MainTmpl}->param('CONTENT' => $$body);
        } else {
                $self->{MainTmpl}->param('CONTENT' => $body);
        }

	$output .= $self->{MainTmpl}->output;
	# ----------------------------------------------------------

        # Send output to browser (unless we're in serious debug mode!)
        unless ($ENV{CGI_APP_RETURN_ONLY}) {
                print $output;
        }

        # clean up operations
        $self->teardown();

        return $output;
}

1;
