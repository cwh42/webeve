#!/usr/bin/perl -w

# $Id$

use strict;

use CGI::Carp qw(fatalsToBrowser set_message);

set_message('<hr><b>Hierbei handelt es sich vermutlich um einen Programmfehler.<br>'.
	    'Bitte schicke die Meldung oberhalb der Linie an mich (<a href="mailto:ch@goessenreuth.de">'.
	    'ch@goessenreuth.de</a>), damit ich den Fehler beheben kann.</b>');

# my $app = TTForm->new( PARAMS => {'MainTmpl' => 'main-2.tmpl'} ); # Alternative main template

my $app = WebEveX->new( TMPL_PATH => '/space/webeve/templates' );

# my $app = WebEveX->new( TMPL_PATH => '/space/webeve/templates',
#  			PARAMS => {'debug' => 1} );

# my $app = WebEveX->new( TMPL_PATH => '/home/cwh/web/webeve/templates' );

# my $app = WebEveX->new( TMPL_PATH => '/home/cwh/web/webeve/templates',
# 			PARAMS => {'debug' => 1} );

$app->run();

# -------------------------------------------
# -------------------------------------------

package WebEveX;

use strict;
use base 'WebEve::WebEveApp';
use File::Basename;
use Date::Calc qw( Today_and_Now );
use WebEve::cMySQL;
use WebEve::cEventList;
use WebEve::cEvent;
use WebEve::cDate;

sub setup
{
    my $self = shift;

    $self->mode_param('mode');
    $self->start_mode('list');
    $self->run_modes( 'AUTOLOAD' => 'WrongRM',
		      'login' => 'Login',
		      'logout' => 'Logout',
		      'list' => 'EventList',
		      'add' => 'Add', 
		      'passwd' => 'Passwd',
		      'config' => 'Config',
		      'userlist' => 'UserList',
		      'useradd' => 'UserAdd',
		      'orgadd' => 'OrgAdd' );

    $self->{dbh} = WebEve::cMySQL->connect('default');
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

sub _FillMenu
{
    my $self = shift;
    
    $self->{MainTmpl}->param('NavMenu' =>
			     $self->_getNavMenu( $self->{IsAdmin}  ) ) if $self->{UserID};

    return 1;
}

# -----------------------------------------------------------------------------

sub _NavMenuCleanup(@)
{
    my $self = shift;

    my @Entries = @_;
    my @Result = ();

    my $FileName = basename( $0 );    
    my $rm = $self->get_current_runmode();

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

# -----------------------------------------------------------------------------

sub _getNavMenu
{
    my $self = shift;

    my @Entries = ( { 'Admin' => 0, 'Title' => 'Login', 'RunMode' => 'login' },
		    { 'Admin' => 0, 'Title' => 'Übersicht', 'RunMode' => 'list',
		      'SubLevel' => [ { 'Admin' => 0, 'Title' => 'Neuer Termin', 'RunMode' => 'add' } ] },
		    { 'Admin' => 0, 'Title' => 'Passwort', 'RunMode' => 'passwd' },
		    { 'Admin' => 0, 'Title' => 'Templates', 'RunMode' => 'config' },
		    { 'Admin' => 1, 'Title' => 'Benutzer', 'RunMode' => 'userlist',
		      'SubLevel' => [ { 'Admin' => 1, 'Title' => 'Neuer Benutzer', 'RunMode' => 'useradd' },
				      { 'Admin' => 1, 'Title' => 'Neuer Verein', 'RunMode' => 'orgadd' } ] },
		    { 'Admin' => 0, 'Title' => 'Logout', 'RunMode' => 'logout' }
		    );

    my @tmp = $self->_NavMenuCleanup( @Entries );
    return \@tmp;
}

# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------

sub logger($)
{
    my $self = shift;
    my ($message) = @_;
    my $UserName = $self->{'UserName'} || $self->{'REMOTE_HOST'};

    open( LOG, ">>". $self->{'Logfile'} );

    printf( LOG "%4d-%02d-%02d %02d:%02d:%02d %s: %s\n", Today_and_Now(), $UserName, $message );

    close( LOG );
}

# -----------------------------------------------------------------------------

sub _ParseTime($)
{
    my ($TimeStr) = @_;

    my $Hour = 0;
    my $Minute = 0;

    $TimeStr =~ s/^\s+//g; 
    $TimeStr =~ s/\s+$//g; 

    if( $TimeStr =~ /^(\d+)$/ )
    {
	$Hour = $1;
	$Minute = 0;
    }
    elsif( $TimeStr =~ /^(\d+)\D(\d+).*$/ )
    {
	$Hour = $1;
	$Minute = $2;
    }

    return 0 if( $Hour < 0 || $Hour > 23 || $Minute < 0 || $Minute > 59 );

    return $Hour, $Minute;
}

sub _getOrgList
{
    my $self = shift;

    my @SelOrgID = @_;


    my $sql = "SELECT o.OrgID, o.OrgName ".
	"FROM Org_User ou, Organization o ".
	"WHERE ou.UserID = ".$self->{UserID}.
	" AND ou.OrgID = o.OrgID ".
	"ORDER BY o.OrgName";

    my @Data = ();

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    while( my $row = $sth->fetchrow_hashref() )
    {
	$row->{'selected'} = 1 if grep { $_ == $row->{OrgID}} (@SelOrgID);
	push( @Data, $row);
    }

    return \@Data;
}

# ---------------------------------------------------------
# Run Modes
# ---------------------------------------------------------

sub WrongRM
{
    my $self = shift;

    $self->logger("Tried non-existing runmode: '".shift()."'");    

    return $self->EventList();
}

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

    $self->{'MainTmpl'}->param( 'TITLE' => 'Login' );
    my $SubTmpl = $self->load_tmpl( 'login.tmpl');

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

    $self->{'MainTmpl'}->param( 'TITLE' => 'Übersicht' );
    my $SubTmpl = $self->load_tmpl( 'edit-list.tmpl');

    my $query = $self->query();

    # -----------------------------------------------------------------------

    my @ShowOrg = $query->param('ShowOrg');

    my %params = ( 'ForUserID' => $self->{UserID},
		   'BeforeToday' => 1 );

    $params{'ForOrgID'} = \@ShowOrg if( scalar(@ShowOrg) > 0 );

    my $EventList = WebEve::cEventList->new( %params );
    $EventList->readData();

    my @Dates = ();

    foreach my $DateObj ( $EventList->getDateList() )
    {
	my $HashRef = { 'Date' => $DateObj->getDate->getDateStr,
			'Time' => $DateObj->getTime,
			'Place' => $DateObj->getPlace,
			'Desc' => $DateObj->getDesc,
			'Org' => $DateObj->getOrg,
			'EntryID' => $DateObj->getID,
			'Public' => $DateObj->isPublic,
			'IsOver' => $DateObj->getDate->isOver };

	push( @Dates, $HashRef );	
    }

    $SubTmpl->param('List' => \@Dates);

    $SubTmpl->param('FullName' => $self->{FullName});
    $SubTmpl->param('User' => $self->{UserName});
    $SubTmpl->param('Admin' => $self->{isAdmin});

    @ShowOrg = map { $_->{'OrgID'} } ( @{$self->_getOrgList()} ) if( scalar(@ShowOrg) == 0 );
    $SubTmpl->param('Orgs' => $self->_getOrgList(@ShowOrg));

    return $SubTmpl->output;
}

sub Add
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Neuer Termin' );
    my $SubTmpl = $self->load_tmpl( 'add.tmpl');

    my $query = $self->query();

    # -----------------------------------------------------------------------

    my $OrgID = $query->param('OrgID') || '';
    my $Public = $query->param('Public') || 0;
    my $DateStr = $query->param('Date') || '';
    my $TimeStr = $query->param('Time') || '';
    my $Place = $query->param('Place') || '';
    my $Description = $query->param('Description') || '';

    my $Action = $query->param('Action') || '';

    $SubTmpl->param('Orgs' => $self->_getOrgList());
    $SubTmpl->param('Public' => 1);

    if($Action eq 'Save')
    {
	my $Event = WebEve::cEvent->new();
	
	my @result = ();

	push(@result, $Event->setOrgID($OrgID));
	push(@result, $Event->setIsPublic($Public));
	push(@result, $Event->setDate($DateStr));
	push(@result, $Event->setTime($TimeStr));
	push(@result, $Event->setPlace($Place));
	push(@result, $Event->setDesc($Description));

	push(@result, $Event->isValid );

	push(@result, $Event->SaveData($self->{UserID}));

	return join(', ', @result);

#	my $Date = WebEve::cDate->new( $DateStr );	
#	my @Time = ParseTime($TimeStr);
#	$Description =~ s/^\s+//g; 
#	$Description =~ s/\s+$//g; 
#
#	$SubTmpl->param('DateError' => 1) unless $Date->isValid;
#	$SubTmpl->param('TimeError' => 1) if @Time == 1;
#	$SubTmpl->param('DescError' => 1) if $Description eq '';
#
#	if( $Date->isValid && @Time > 1 && $Description ne '' )
#	{
#	    my $DateSQL = $Date->getDateStrSQL();
#	    my $TimeSQL = "'".join('-', @Time).":00'";
#
#	    my $PlaceSQL = sqlQuote($Place);
#	    my $DescriptionSQL = sqlQuote($Description);
#
#	    my $sql = sprintf("INSERT INTO Dates (Date, Time, Place, Description, OrgID, UserID, Public) ".
#			      "VALUES(%s, %s, %s, %s, %d, %d, %d)",
#			      $DateSQL,
#			      $TimeSQL,
#			      $PlaceSQL,
#			      $DescriptionSQL,
#			      $OrgID,
#			      $self->{UserID},
#			      $Public);
#
#	    $self->{dbh}->do($sql);
#
#	    my ($LastID) = $self->{dbh}->selectrow_array("SELECT LAST_INSERT_ID() FROM Dates LIMIT 1");
#
#	    if($LastID)
#	    {
#		logger("Added date: $LastID");
#
#		$SubTmpl->param('Saved' => 1);
#		$SubTmpl->param('SvOrgName' => 'XXX');
#		$SubTmpl->param('SvEntryID' => $LastID);
#		$SubTmpl->param('SvDate' => $Date->getDateStr());
#
#		if( @Time == 1 || ($Time[0] == 0 && $Time[1]) )
#		{
#		    $TimeStr = '';
#		}
#		else
#		{
#		    $TimeStr = sprintf("%02d:%02d", @Time);
#		}
#
#		$SubTmpl->param('SvTime' => $TimeStr);
#		$SubTmpl->param('SvPlace' => $query->param('Place'));
#		$SubTmpl->param('SvDescription' => $query->param('Description'));
#		$SubTmpl->param('SvPublic' => $Public ? 1 : 0);
#	    }
#	    else
#	    {
#		$SubTmpl->param('Saved' => 0);
#		$SubTmpl->param('Error' => 1);
#		logger("ERROR: Could not insert date!");
#	    }
#
#	}
#	else
#	{
#	    $SubTmpl->param('Orgs' => $self->_getOrgList($OrgID));
#	    $SubTmpl->param('Date' => $query->param('Date'));
#	    $SubTmpl->param('Time' => $query->param('Time'));
#	    $SubTmpl->param('Place' => $query->param('Place'));
#	    $SubTmpl->param('Description' => $query->param('Description'));
#	    $SubTmpl->param('Public' => $Public ? 1 : 0);
#	}
    }

    return $SubTmpl->output;
}

sub Passwd
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Passwort ändern' );

    return 0;
}

sub Config
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Konfiguration' );

    return 0;
}

sub UserList
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Benutzer &amp; Vereine' );

    return 0;
}

sub UserAdd
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Neuer Benutzer' );

    return 0;
}

sub OrgAdd
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Neuer Verein' );

    return 0;
}

1;
