#!/usr/bin/perl -w

# $Id$

use strict;

use CGI::Carp qw(fatalsToBrowser set_message);

set_message('<hr><b>Hierbei handelt es sich vermutlich um einen Programmfehler.<br>'.
	    'Bitte schicke die Meldung oberhalb der Linie an mich (<a href="mailto:ch@goessenreuth.de">'.
	    'ch@goessenreuth.de</a>), damit ich den Fehler beheben kann.</b>');

# my $app = TTForm->new( PARAMS => {'MainTmpl' => 'main-2.tmpl'} ); # Alternative main template

my $app = WebEveX->new( TMPL_PATH => '/space/webeve/templates' );
# my $app = WebEve->new( TMPL_PATH => '/home/cwh/web/webeve/templates' );
#- my $app = WebEve->new( TMPL_PATH => '/home/cwh/web/webeve/templates',
#- 		       PARAMS => {'debug' => 1} );

$app->run();

# -------------------------------------------
# -------------------------------------------

package WebEveX;

use strict;
use base 'WebEve::WebEveApp';
use File::Basename;
use Date::Calc qw( Today_and_Now );
use WebEve::cMySQL;
#use WebEve::mysql;

sub setup
{
    my $self = shift;

    $self->mode_param('mode');
    $self->start_mode('list');
    $self->run_modes( 'login' => 'Login',
		      'logout' => 'Logout',
		      'list' => 'EventList' );

    $self->{dbh} = WebEve::cMySQL->connect('default');
}

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
}

sub teardown
{
    my $self = shift;

    $self->{dbh}->disconnect;    
}

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

sub _FillMenu
{
    my $self = shift;
    
    $self->{MainTmpl}->param('NavMenu' =>
			     $self->_getNavMenu( $self->{IsAdmin}  ) ) if $self->{UserID};

    return 1;
}

sub _NavMenuCleanup($@)
{
    my $self = shift;

    my ( $IsAdmin, @Entries ) = @_;
    my @Result = ();

    my $FileName = basename( $0 );    
    my $rm = $self->get_current_runmode();

    foreach my $Entry (@Entries)
    {
	my $Admin = delete( $Entry->{'Admin'} );

	if( !( $Admin ) || $IsAdmin )
	{
	    if( exists( $Entry->{'SubLevel'} ) ) 
	    {
		my @tmp = $self->_NavMenuCleanup( $IsAdmin, @{$Entry->{'SubLevel'}} );
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


sub _getNavMenu(;$)
{
    my $self = shift;

    my ($IsAdmin) = @_;

    my @Entries = ( { 'Admin' => 0, 'Title' => 'Login', 'RunMode' => 'login' },
		    { 'Admin' => 0, 'Title' => 'Übersicht', 'RunMode' => 'list',
		      'SubLevel' => [ { 'Admin' => 0, 'Title' => 'Neuer Termin', 'RunMode' => 'add' } ] },
		    { 'Admin' => 0, 'Title' => 'Passwort', 'RunMode' => 'passwd' },
		    { 'Admin' => 0, 'Title' => 'Templates', 'RunMode' => 'config' },
		    { 'Admin' => 1, 'Title' => 'Benutzer', 'RunMode' => 'user.pl',
		      'SubLevel' => [ { 'Admin' => 1, 'Title' => 'Neuer Benutzer', 'RunMode' => 'adduser' },
				      { 'Admin' => 1, 'Title' => 'Neuer Verein', 'RunMode' => 'addorg' } ] },
		    { 'Admin' => 0, 'Title' => 'Logout', 'RunMode' => 'logout' }
		    );

    my @tmp = $self->_NavMenuCleanup( $IsAdmin, @Entries );
    return \@tmp;
}

sub _MakeSessionID($)
{
        my $i;
        my $SID = crypt($_[0], 'SI');
        my @Chars = split(//, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890');

        for($i = 0; $i < 37; $i++)
        {
                $SID .= @Chars[rand(@Chars)];
        }

        return $SID;
}

sub logger($)
{
    my $self = shift;
    my ($message) = @_;
    my $UserName = $self->{'UserName'} || $self->{'REMOTE_HOST'};

    open( LOG, ">>". $self->{'Logfile'} );

    printf( LOG "%4d-%02d-%02d %02d:%02d:%02d %s: %s\n", Today_and_Now(), $UserName, $message );

    close( LOG );
}


# ---------------------------------------------------------
# Run Modes
# ---------------------------------------------------------

sub Logout()
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Logout' );

    my $SessionID = $self->query->cookie('sessionID');
    $self->{dbh}->do("DELETE FROM Logins WHERE SessionID = '$SessionID'");

    $self->logger("Logged out");

    $self->header_type('redirect');
    $self->header_props(-uri=>'kalender.pl');
    
    return '<center>Please wait ...</center>';
}


sub Login()
{
    my $self = shift;
    # Settings

    my $query = $self->query();

    my $SubTmpl = $self->load_tmpl( 'login.tmpl');
    $self->{'MainTmpl'}->param( 'TITLE' => 'Login' );

    # -----------------------------------------------------------------------

    my $User = $query->param('User') || '';
    my $Password = $query->param('Password') || '';

    # This query removes expired loginmarks from database.
    # (User should be ticked off for not logging out properly!)
    $self->{dbh}->do('DELETE FROM Logins WHERE Expires < now()');

    # User calls this page without any parameters
    if($User eq '' && $Password eq '')
    {
	if( $self->{UserID} )
	{
	    $SubTmpl->param( 'User' => $self->{UserName} );
	}
	my $Cookie = $query->cookie(-name=>'WebEveCookieTest',
				    -value=>'Cookies_enabled');
	
	$self->header_props(-cookie=>$Cookie);

	return $SubTmpl->output;
    }

    # User submits either a username or a password or both.
    if($User ne '' || $Password ne '')
    {
	my $CookieTest = $query->cookie('WebEveCookieTest');
	my $Relogin = $self->{'UserID'} ? 1 : 0;

	unless( $CookieTest )
	{
	    $self->logger("Cookies disabled!");
	    $SubTmpl->param( 'NoCookies' => 1 );

	    return $SubTmpl->output;
	}
	elsif($self->_CheckUser($User, $Password))
	{
	    if( $Relogin )
	    {
		$self->logger("Deleting old session.");

		my $OldSessionID = $self->{dbh}->quote($self->query->cookie('sessionID'));
		$self->{dbh}->do("DELETE FROM Logins WHERE SessionID = $OldSessionID");
	    }

	    $self->{dbh}->do("UPDATE User SET LastLogin = now() where UserID = ".$self->{UserID});

	    my $SessionID = _MakeSessionID($User);

	    my $Cookie = $query->cookie(-name=>'sessionID',
					-value=>$SessionID);

	    $self->header_props(-cookie=>$Cookie);

	    $self->{dbh}->do("INSERT INTO Logins (SessionID, UserID, Expires) ".
			     "VALUES('$SessionID', ".$self->{UserID}.", ADDDATE(now(), INTERVAL 8 HOUR))");

	    $self->logger("logged in as $User");

	    $self->_FillMenu();
	    return $self->EventList();
	}
	else
	{
	    $self->logger("Login failed: '$User'");

	    $SubTmpl->param( 'WrongPasswd' => 1 );

	    return $SubTmpl->output;
	}
    }
}


sub EventList
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Event List' );

    return "<b>EVENT LIST</b>";
}

1;
