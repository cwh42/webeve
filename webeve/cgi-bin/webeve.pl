#!/usr/bin/perl -w

# $Id$

use strict;

# my $app = TTForm->new( PARAMS => {'MainTmpl' => 'main-2.tmpl'} ); # Alternative main template

my $app = WebEve->new( TMPL_PATH => '/home/cwh/web/webeve/templates' );
#- my $app = WebEve->new( TMPL_PATH => '/home/cwh/web/webeve/templates',
#- 		       PARAMS => {'debug' => 1} );

$app->run();

# -------------------------------------------
# -------------------------------------------

package WebEve;

use strict;
use base 'WebEve::WebEveApp';
use WebEve::termine;
use WebEve::mysql;

sub setup
{
    my $self = shift;

    $self->mode_param(\&_CheckMode);
    $self->start_mode('list');
    $self->run_modes( 'login' => 'Login',
		      'logout' => 'Logout',
		      'list' => 'EventList' );

    $self->{dbh} = WebEve::cMySQL->connect('default');
}

sub _CheckMode
{
    my $self = shift;
    my $q = $self->query();
    my $RunMode = $q->param('mode');

    # Check whether user is logged in
    # --------------------------------
    my @UserData = CheckLogin();

    if( scalar(@UserData) )
    {
	$self->{UserID} = $UserData[0];
	$self->{FullName} = $UserData[1];
	$self->{eMail} = $UserData[2];
	$self->{isAdmin} = $UserData[3];
	$self->{LastLogin} = $UserData[4];
	$self->{UserName} = $UserData[5];

	$self->_FillMenu();
    }
    else
    {
	logger('User not logged in.');
	$RunMode = 'login';
    }

    return $RunMode;
}

sub teardown
{
    my $self = shift;

    $self->{dbh}->disconnect;    
}

sub _FillMenu
{
    my $self = shift;
    
    $self->{MainTmpl}->param('NavMenu' =>
			     getNavMenu( getNavMenu( $self->{IsAdmin} ) ) ) if $self->{UserID};

    return 1;
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

# ---------------------------------------------------------
# Run Modes
# ---------------------------------------------------------

sub Logout()
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Logout' );

    my $SessionID = $self->query->cookie('sessionID');
    DoSQL("DELETE FROM Logins WHERE SessionID = '$SessionID'");

    logger("Logged out");

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
    DoSQL('DELETE FROM Logins WHERE Expires < now()');

    # User calls this page without any parameters
    if($User eq '' && $Password eq '')
    {
	if( $self->{UserID} )
	{
	    $SubTmpl->param( 'User' => $self->{UserName} );
	}

	return $SubTmpl->output;
    }

    # User submits either a username or a password or both.
    if($User ne '' || $Password ne '')
    {
	my @UserData = CheckUser($User, $Password);

	if(@UserData > 0)
	{
	    LogOut() if $self->{UserID};

	    DoSQL("UPDATE User SET LastLogin = now() where UserID = $UserData[0]");

	    my $SessionID = _MakeSessionID($User);

	    my $Cookie = $query->cookie(-name=>'sessionID',
					-value=>$SessionID,
					-expires=>'+8h');

	    $self->header_props(-cookie=>$Cookie);

	    DoSQL("INSERT INTO Logins (SessionID, UserID, Expires) ".
		  "VALUES('$SessionID', $UserData[0], ADDDATE(now(), INTERVAL 8 HOUR))");

	    logger("logged in as $User");

	    $self->{UserID} = $UserData[0];
	    $self->{FullName} = $UserData[1];
	    $self->{eMail} = $UserData[2];
	    $self->{isAdmin} = $UserData[3];
	    $self->{LastLogin} = $UserData[4];
	    $self->{UserName} = $UserData[5];

	    $self->_FillMenu();
	    return $self->EventList();
	}
	else
	{
	    logger("Login failed: '$User'");

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
