package WebEve::WebEveApp;

use strict;

use base 'CGI::Application';
use base 'WebEve::cBase';

use File::Basename;
use CGI::Carp;
use Socket;

# -------------------------------------------------------------------------
# The init-Method
#
sub cgiapp_init
{
    my $self = shift;

    # Prepare some stuff
    # --------------------------------
    $self->tmpl_path( $self->getConfig('TemplatePath') );

    my $MainTmpl = $self->param('MainTmpl');
    $self->{MainTmpl} = $self->load_tmpl( $MainTmpl ? $MainTmpl : 'main.tmpl' );    

    print STDERR $self->dump() if $self->param('debug');

    $self->{'Logfile'} = $self->param('Logfile') || $self->getConfig( 'LogFile' );

    $self->_getRemoteHost();

    if(exists $ENV{MOD_PERL})
    { 
	print STDERR "\n-----------------------------------------\n";
	print STDERR "-----------------------------------------\n";
	print STDERR " WARNING:\n";
	print STDERR " Running under ".$ENV{MOD_PERL}."!\n";
	print STDERR " This script is not tested with mod_perl!\n";
	print STDERR "-----------------------------------------\n";
	print STDERR "-----------------------------------------\n";
    }
    else
    {
#	print STDERR "\nOK, NOT running under mod-perl.\n";
    }

    $self->{dbh} = WebEve::cMySQL->connect('default');
}

# -----------------------------------------------------------------------------

sub _getRemoteHost()
{
    my $self = shift;

    $self->{'REMOTE_HOST'} = $ENV{'REMOTE_HOST'} if defined( $ENV{'REMOTE_HOST'} );

    my $ip = inet_aton( $ENV{'REMOTE_ADDR'} );
    my ( $HostName ) = gethostbyaddr($ip, AF_INET);

    $self->{'REMOTE_HOST'} = $? ? $ENV{'REMOTE_ADDR'} : $HostName;

    return 1;
}

# -----------------------------------------------------------------------------

sub cgiapp_prerun
{
    my $self = shift;

    # Check whether user is logged in
    # --------------------------------
    if( $self->_CheckLogin() )
    {
	$self->_FillMenu();
    }
    else
    {
	$self->logger('User not logged in.');
	$self->prerun_mode('login');
    }
}

# -----------------------------------------------------------------------------

sub teardown
{
    my $self = shift;

    $self->{dbh}->disconnect;    
}

# -----------------------------------------------------------------------------

sub _CheckLogin()
{
    my $self = shift;
    my $query = $self->query();
    my $SessionID = $self->{dbh}->quote($query->cookie('sessionID')||'');
    
    my $sql = "SELECT u.UserID, u.FullName, u.eMail, u.isAdmin, u.LastLogin, u.UserName ".
	"FROM Logins l LEFT JOIN User u ON u.UserID = l.UserID ".
	"WHERE SessionID = $SessionID ".
	"AND Expires > now()";

    my $UserData = $self->{dbh}->selectrow_hashref($sql);

    if( defined($UserData) )
    {
	foreach(keys(%$UserData))
	{
	    $self->{$_} = $UserData->{$_};
	}

	return 1;
    }
    else
    {
	return 0;
    }
}

# -----------------------------------------------------------------------------

sub _CheckUser($$)
{
    my $self = shift;

    my $User_sql = $self->{dbh}->quote($_[0]);
    my $Password_sql = $self->{dbh}->quote($_[1]);

    my $sql = "SELECT UserID, FullName, eMail, isAdmin, LastLogin, UserName ".
	"FROM User ".
	"WHERE UserName = $User_sql ".
	"AND Password = password($Password_sql)";

    my $UserData = $self->{dbh}->selectrow_hashref($sql);

    if( defined($UserData) )
    {
	foreach(keys(%$UserData))
	{
	    $self->{$_} = $UserData->{$_};
	}

	return 1;
    }
    else
    {
	return 0;
    }
}

# -----------------------------------------------------------------------------

sub _MakeSessionID($)
{
    my $self = shift;

    my $i;
    my $SID = crypt($_[0], 'SI');
    my @Chars = split(//, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890');
    
    for($i = 0; $i < 37; $i++)
    {
	$SID .= @Chars[rand(@Chars)];
    }
    
    return $SID;
}

# -----------------------------------------------------------------------------

sub _FillMenu(;$)
{
    my $self = shift;
    $self->{'RunMode'} = shift;
    
    $self->{MainTmpl}->param('NavMenu' =>
			     $self->_getNavMenu( $self->{IsAdmin} ) ) if $self->{UserID};

    return 1;
}

# -----------------------------------------------------------------------------

sub _NavMenuCleanup(@)
{
    my $self = shift;

    my @Entries = @_;
    my @Result = ();

    my $FileName = basename( $0 );    
    my $rm = $self->{'RunMode'} ? $self->{'RunMode'} : $self->get_current_runmode();

    foreach my $Entry (@Entries)
    {
	my $Admin = delete( $Entry->{'Admin'} );

	if( !( $Admin ) || $self->{isAdmin} )
	{
	    if( exists( $Entry->{'SubLevel'} ) ) 
	    {
		my @tmp = $self->_NavMenuCleanup( @{$Entry->{'SubLevel'}} );
		$Entry->{'SubLevel'} = \@tmp;
	    }

	    if( $Entry->{'RunMode'} eq $rm )
	    {
		$Entry->{'Current'} = 1;
	    }

	    $Entry->{'FileName'} = "$FileName?mode=".$Entry->{'RunMode'};

	    push( @Result, $Entry );
	}
    }

    return @Result;
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
