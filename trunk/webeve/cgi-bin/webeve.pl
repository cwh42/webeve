#!/usr/bin/perl -w

# $Id$

use strict;

use CGI::Carp qw(fatalsToBrowser set_message);

set_message('<hr><b>Hierbei handelt es sich vermutlich um einen Programmfehler.<br>'.
	    'Bitte schicke die Meldung oberhalb der Linie an mich (<a href="mailto:ch@goessenreuth.de">'.
	    'ch@goessenreuth.de</a>), damit ich den Fehler beheben kann.</b>');

my $app = WebEveX->new();

$app->run();

# -------------------------------------------
# -------------------------------------------

package WebEveX;

use strict;
use base qw( WebEve::WebEveApp );
use WebEve::cEventList;
use WebEve::cEvent;
use WebEve::cDate;
use WebEve::cOrg;

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
		      'delete' => 'Delete', 
		      'edit' => 'Edit', 
		      'passwd' => 'Passwd',
		      'config' => 'Config',
		      'userlist' => 'UserList',
		      'useradd' => 'UserAdd',
		      'useredit' => 'UserEdit',
		      'orglist' => 'OrgList',
		      'orgadd' => 'OrgAdd',
		      'orgedit' => 'OrgEdit' );
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
		      'SubLevel' => [ { 'Admin' => 1, 'Title' => 'Neuer Benutzer', 'RunMode' => 'useradd' } ] },
		    { 'Admin' => 1, 'Title' => 'Vereine', 'RunMode' => 'orglist',
		      'SubLevel' => [ { 'Admin' => 1, 'Title' => 'Neuer Verein', 'RunMode' => 'orgadd' } ] },
		    { 'Admin' => 0, 'Title' => 'Logout', 'RunMode' => 'logout' }
		    );

    my @tmp = $self->_NavMenuCleanup( @Entries );
    return \@tmp;
}

# -----------------------------------------------------------------------------

sub _getUsersOrgList
{
    my $self = shift;

    my %Params = @_;

    my $UserID = $Params{'UserID'} ? $Params{'UserID'} : $self->getUser()->{UserID};
    my @SelOrgID = @{$Params{'Selected'}} if exists( $Params{'Selected'} );

    my $sql = "SELECT o.OrgID, o.OrgName ".
	"FROM Org_User ou LEFT JOIN Organization o ON ou.OrgID = o.OrgID ".
	"WHERE ou.UserID = $UserID ".
	"ORDER BY o.OrgName";

    my @Data = ();

    my $sth = $self->getDBH()->prepare($sql);
    $sth->execute();

    while( my $row = $sth->fetchrow_hashref() )
    {
	$row->{'selected'} = 1 if grep { $_ == $row->{OrgID}} (@SelOrgID);
	push( @Data, $row);
    }

    return \@Data;
}

sub _getUserList
{
    my $self = shift;
    my @SelUserID = @_;

    my $sql = "SELECT u.UserID, u.FullName, u.UserName, u.eMail, u.isAdmin, u.LastLogin ".
	"FROM User u ".
	"ORDER BY u.UserName";

    my @Data = ();

    my $sth = $self->getDBH()->prepare($sql);
    $sth->execute();

    while( my $row = $sth->fetchrow_hashref() )
    {
	$row->{'selected'} = 1 if grep { $_ == $row->{UserID}} (@SelUserID);
	push( @Data, $row);
    }

    return \@Data;
}

sub _getOrgList
{
    my $self = shift;
    my @SelOrgID = @_;

    my $sql = "SELECT o.OrgID, o.OrgName, o.eMail, o.Website ".
	"FROM Organization o ORDER BY o.OrgName";

    my @Data = ();

    my $sth = $self->getDBH()->prepare($sql);
    $sth->execute();

    while( my $row = $sth->fetchrow_hashref() )
    {
	$row->{'selected'} = 1 if grep { $_ == $row->{OrgID}} (@SelOrgID);
	push( @Data, $row);
    }

    return \@Data;

}

# ---------------------------------------------------------

sub getOrgPref($$)
{
    my $self = shift;

    my ($OrgID, $PrefType) = @_;

    my $sql = sprintf("SELECT PrefValue FROM OrgPrefs up ".
		      "LEFT JOIN OrgPrefTypes pt ON up.PrefType = pt.TypeID ".
		      "WHERE OrgID = %d AND TypeName = %s",
		      $OrgID,
		      $self->getDBH()->quote($PrefType));

    my $sth = $self->getDBH()->prepare($sql);
    $sth->execute();

    my @result = ();

    while( my $row = $sth->fetchrow_arrayref() )
    {
	push( @result, $row->[0] );
    }

    return @result;
}

sub setOrgPref($$@)
{
    my $self = shift;

    my ( $OrgID, $PrefType, @NewValues ) = @_;

    my $sql = sprintf("SELECT TypeID FROM OrgPrefTypes WHERE TypeName = %s LIMIT 1",
		      $self->getDBH()->quote($PrefType));

    my $PrefTypeID = $self->getDBH()->selectrow_array($sql);

    unless( $PrefTypeID )
    {
	my $sql = sprintf("INSERT INTO OrgPrefTypes (TypeName) VALUES (%s)",
			  $self->getDBH()->quote($PrefType));

	$self->getDBH()->do($sql);

	$PrefTypeID = $self->getDBH()->selectrow_array("SELECT LAST_INSERT_ID() FROM OrgPrefTypes LIMIT 1");
    }

    my @OldValues = $self->getOrgPref($OrgID, $PrefType);

    my ($ToAddRef, $ToDeleteRef) = $self->_ArrayDiff(\@NewValues, \@OldValues, 1);

    my @ToAdd = @$ToAddRef;
    my @ToDelete = @$ToDeleteRef;

    #print STDERR "ALL:".join(',', @OldValues)."\n";
    #print STDERR "SEL:".join(',', @NewValues)."\n";

    #print STDERR "ADD:".join(',', @ToAdd)."\n";
    #print STDERR "DEL:".join(',', @ToDelete)."\n";

    if(@ToAdd)
    {
	my $sql = "INSERT INTO OrgPrefs (OrgID, PrefType, PrefValue) VALUES ";
	$sql .=  join( ', ', map { "($OrgID, $PrefTypeID, ".$self->getDBH()->quote($_).")" } @ToAdd );

	$self->getDBH()->do($sql);
    }

    if(@ToDelete)
    {
	my $sql = "DELETE FROM OrgPrefs WHERE OrgID = $OrgID  AND PrefType = $PrefTypeID AND (";
	$sql .=  join( ' OR ', map { "PrefValue = ".$self->getDBH()->quote($_) } @ToDelete );
	$sql .= ")";

	$self->getDBH()->do($sql);
    }

    return 1;
}

# ---------------------------------------------------------

sub getUserPref($)
{
    my $self = shift;

    my ($PrefType) = @_;

    my $sql = sprintf("SELECT PrefValue FROM UserPrefs up ".
		      "LEFT JOIN UserPrefTypes pt ON up.PrefType = pt.TypeID ".
		      "WHERE UserID = %d AND TypeName = %s",
		      $self->getUser()->{UserID},
		      $self->getDBH()->quote($PrefType));

    my $sth = $self->getDBH()->prepare($sql);
    $sth->execute();

    my @result = ();

    while( my $row = $sth->fetchrow_arrayref() )
    {
	push( @result, $row->[0] );
    }

    return @result;
}

sub setUserPref($@)
{
    my $self = shift;

    my ( $PrefType, @NewValues ) = @_;
    my $UserID = $self->getUser()->{UserID};

    my $sql = sprintf("SELECT TypeID FROM UserPrefTypes WHERE TypeName = %s LIMIT 1",
		      $self->getDBH()->quote($PrefType));

    my $PrefTypeID = $self->getDBH()->selectrow_array($sql);

    unless( $PrefTypeID )
    {
	my $sql = sprintf("INSERT INTO UserPrefTypes (TypeName) VALUES (%s)",
			  $self->getDBH()->quote($PrefType));

	$self->getDBH()->do($sql);

	$PrefTypeID = $self->getDBH()->selectrow_array("SELECT LAST_INSERT_ID() FROM UserPrefTypes LIMIT 1");
    }

    my @OldValues = $self->getUserPref($PrefType);

    my ($ToAddRef, $ToDeleteRef) = $self->_ArrayDiff(\@NewValues, \@OldValues, 1);

    my @ToAdd = @$ToAddRef;
    my @ToDelete = @$ToDeleteRef;

    #print STDERR "ALL:".join(',', @OldValues)."\n";
    #print STDERR "SEL:".join(',', @NewValues)."\n";

    #print STDERR "ADD:".join(',', @ToAdd)."\n";
    #print STDERR "DEL:".join(',', @ToDelete)."\n";

    if(@ToAdd)
    {
	my $sql = "INSERT INTO UserPrefs (UserID, PrefType, PrefValue) VALUES ";
	$sql .=  join( ', ', map { "($UserID, $PrefTypeID, ".$self->getDBH()->quote($_).")" } @ToAdd );

	$self->getDBH()->do($sql);
    }

    if(@ToDelete)
    {
	my $sql = "DELETE FROM UserPrefs where UserID = $UserID  AND PrefType = $PrefTypeID AND (";
	$sql .=  join( ' OR ', map { "PrefValue = ".$self->getDBH()->quote($_) } @ToDelete );
	$sql .= ")";

	$self->getDBH()->do($sql);
    }

    return 1;
}

# ---------------------------------------------------------


# ---------------------------------------------------------
# Run Modes
# ---------------------------------------------------------

sub WrongRM
{
    my $self = shift;
    $self->{MenuItem} = '';

    $self->logger("Tried non-existing runmode: '".shift()."'");    

    $self->_FillMenu('list');
    return $self->EventList();
}

sub Logout()
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Logout' );

    my $SessionID = $self->query->cookie('sessionID');
    $self->getDBH()->do("DELETE FROM Logins WHERE SessionID = '$SessionID'");

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
    $self->getDBH()->do('DELETE FROM Logins WHERE Expires < now()');

    # User calls this page without any parameters
    if($User eq '' && $Password eq '')
    {
	if( $self->getUser()->{UserID} )
	{
	    $SubTmpl->param( 'User' => $self->getUser()->{UserName} );
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
	my $Relogin = $self->getUser()->{'UserID'} ? 1 : 0;

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

		my $OldSessionID = $self->getDBH()->quote($self->query->cookie('sessionID'));
		$self->getDBH()->do("DELETE FROM Logins WHERE SessionID = $OldSessionID");
	    }

	    $self->getDBH()->do("UPDATE User SET LastLogin = now() where UserID = ".$self->getUser()->{UserID});

	    my $SessionID = $self->_MakeSessionID($User);

	    my $Cookie = $query->cookie(-name=>'sessionID',
					-value=>$SessionID);

	    $self->header_props(-cookie=>$Cookie);

	    $self->getDBH()->do("INSERT INTO Logins (SessionID, UserID, Expires) ".
			     "VALUES('$SessionID', ".$self->getUser()->{UserID}.", ADDDATE(now(), INTERVAL 8 HOUR))");

	    $self->logger("logged in as $User");

	    $self->_FillMenu('list');
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

    my %params = ( 'ForUserID' => $self->getUser()->{UserID},
		   'BeforeToday' => 1 );

    my @ShowOrg = ();

    if( $query->param('ShowOrg') )
    {
	@ShowOrg = $query->param('ShowOrg');
	$self->setUserPref('ShowOrg', @ShowOrg);
    }
    else
    {
	@ShowOrg = $self->getUserPref('ShowOrg');
    }

    @ShowOrg = map { $_->{'OrgID'} } ( @{$self->_getUsersOrgList()} ) unless( scalar(@ShowOrg) );

    $params{'ForOrgID'} = \@ShowOrg;

    my $EventList = WebEve::cEventList->new( %params );
    $EventList->readData();

    my @Dates = ();

    foreach my $DateObj ( $EventList->getDateList() )
    {
	my $HashRef = { 'Date' => $DateObj->getDate->getDateStr,
			'Time' => $DateObj->getTime,
			'Place' => $DateObj->getPlace,
			'Desc' => $DateObj->getDesc,
			'Org' => $DateObj->getOrg('all'),
			'EntryID' => $DateObj->getID,
			'Public' => $DateObj->isPublic,
			'IsOver' => $DateObj->getDate->isOver };

	push( @Dates, $HashRef );	
    }

    $SubTmpl->param('List' => \@Dates);

    $SubTmpl->param('FullName' => $self->getUser()->{FullName});
    $SubTmpl->param('User' => $self->getUser()->{UserName});
    $SubTmpl->param('Admin' => $self->getUser()->{isAdmin});

    $SubTmpl->param('Orgs' => $self->_getUsersOrgList( 'Selected' => \@ShowOrg ));

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

    $SubTmpl->param('Orgs' => $self->_getUsersOrgList());
    $SubTmpl->param('Public' => 1);

    if($Action eq 'Save')
    {
	my $Event = WebEve::cEvent->new();
	
	$Event->setOrgID($OrgID);
	$Event->setIsPublic($Public);
	$Event->setPlace($Place);

	$SubTmpl->param('DateError' => 1) unless $Event->setDate($DateStr);
	$SubTmpl->param('TimeError' => 1) unless $Event->setTime($TimeStr);
	$SubTmpl->param('DescError' => 1) unless $Event->setDesc($Description);


	if( $Event->isValid() )
	{
	    if($Event->SaveData($self->getUser()->{UserID}))
	    {
		$SubTmpl->param('Saved' => 1);
		$SubTmpl->param('SvOrgName' => $Event->getOrg('all'));
		$SubTmpl->param('SvEntryID' => $Event->getID());
		$SubTmpl->param('SvDate' => $Event->getDate->getDateStr());
		$SubTmpl->param('SvTime' => $Event->getTime());
		$SubTmpl->param('SvPlace' => $Event->getPlace());
		$SubTmpl->param('SvDescription' => $Event->getDesc());
		$SubTmpl->param('SvPublic' => $Event->isPublic());

		if( $query->param('KeepOrg') )
		{
		    $SubTmpl->param('Orgs' => $self->_getUsersOrgList( 'Selected' => [$Event->getOrgID()]));
		    $SubTmpl->param('KeepOrg' => 1);
		}

		if( $query->param('IncDate') )
		{
		    $Event->getDate->incr();
		    my $tmpDate = join('-', reverse($Event->getDate->getDate()));
		    $SubTmpl->param('Date' => $tmpDate);
		    $SubTmpl->param('IncDate' => 1);
		}

		if( $query->param('KeepTime') )
		{
		    $SubTmpl->param('Time' => $Event->getTime());
		    $SubTmpl->param('KeepTime' => 1);
		}

		if( $query->param('KeepPlace') )
		{
		    $SubTmpl->param('Place' => $Event->getPlace());
		    $SubTmpl->param('KeepPlace' => 1);
		}

		if( $query->param('KeepDesc') )
		{
		    $SubTmpl->param('Description' => $Event->getDesc());
		    $SubTmpl->param('KeepDesc' => 1);
		}

		if( $query->param('KeepPublic') )
		{
		    $SubTmpl->param('Public' => $Event->isPublic());
		    $SubTmpl->param('KeepPublic' => 1);
		}
	    }
	    else
	    {
		$SubTmpl->param('Saved' => 0);
		$SubTmpl->param('Error' => 1);
	    }

	}
	else
	{
	    foreach( qw( KeepOrg IncDate KeepTime KeepPlace KeepDesc KeepPublic) )
	    {
		$SubTmpl->param($_ => $query->param($_) );
	    }

	    $SubTmpl->param('Orgs' => $self->_getUsersOrgList( 'Selected' => [$OrgID] ));
	    $SubTmpl->param('Date' => $query->param('Date'));
	    $SubTmpl->param('Time' => $query->param('Time'));
	    $SubTmpl->param('Place' => $query->param('Place'));
	    $SubTmpl->param('Description' => $query->param('Description'));
	    $SubTmpl->param('Public' => $Public ? 1 : 0);
	}
    }
    
    return $SubTmpl->output;
}

sub Delete
{
    my $self = shift;
    my $result = '';

    $self->{'MainTmpl'}->param( 'TITLE' => 'Termin(e) löschen' );
    my $SubTmpl = $self->load_tmpl( 'delete.tmpl');

    my $query = $self->query();

    my @EntryIDs = $query->param('EntryID');
    my $Confirm = $query->param('Confirm') ? 1 : 0;

    my %params = ( 'ForUserID' => $self->getUser()->{UserID},
		   'BeforeToday' => 1 );

    $params{'ID'} = \@EntryIDs if( scalar(@EntryIDs) > 0 );

    my $EventList = WebEve::cEventList->new( %params );

    if( $Confirm )
    {
	my $delcount = $EventList->deleteData($self->getUser()->{UserID});
	$self->logger( "Deleted $delcount of ".$EventList->getEventCount()." events." );

	$self->_FillMenu('list');
	$result = $self->EventList();
    }
    else
    {
	my @Dates = ();

	foreach my $DateObj ( $EventList->getDateList() )
	{
	    my $HashRef = { 'Date' => $DateObj->getDate->getDateStr,
			    'Time' => $DateObj->getTime,
			    'Place' => $DateObj->getPlace,
			    'Desc' => $DateObj->getDesc,
			    'Org' => $DateObj->getOrg('all'),
			    'Public' => $DateObj->isPublic };

	    push( @Dates, $HashRef );	
	}

	$SubTmpl->param('List' => \@Dates);

	@EntryIDs = $EventList->getIDs();
	my $QueryString = '';
	$QueryString = '&EntryID='.join( '&EntryID=', @EntryIDs ) if @EntryIDs;
	$SubTmpl->param('EntryIDs' => $QueryString);

	$self->_FillMenu('list');
	$result = $SubTmpl->output;
    }

    return $result;
}

sub Edit
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Termin bearbeiten' );

    my $SubTmpl = $self->load_tmpl( 'edit.tmpl');

    my $query = $self->query();

    my $EntryID = $query->param('EntryID') || '';

    unless( $EntryID )
    {
	$self->_FillMenu('list');
	return $self->EventList();
    }

    # -----------------------------------------------------------------------
    my $result = '';

    my $OrgID = $query->param('OrgID') || '';
    my $Public = $query->param('Public') || 0;
    my $DateStr = $query->param('Date') || '';
    my $TimeStr = $query->param('Time') || '';
    my $Place = $query->param('Place') || '';
    my $Description = $query->param('Description') || '';

    my $Action = $query->param('Action') || '';

    $SubTmpl->param('Orgs' => $self->_getUsersOrgList());
    $SubTmpl->param('Public' => 1);

    my $Event = WebEve::cEvent->newFromDB($EntryID);

    if($Action eq 'Save')
    {
	$Event->setOrgID($OrgID);
	$Event->setIsPublic($Public);
	$Event->setPlace($Place);

	$SubTmpl->param('DateError' => 1) unless $Event->setDate($DateStr);
	$SubTmpl->param('TimeError' => 1) unless $Event->setTime($TimeStr);
	$SubTmpl->param('DescError' => 1) unless $Event->setDesc($Description);

	if( $Event->isValid() )
	{
	    if($Event->SaveData($self->getUser()->{UserID}))
	    {
		$self->_FillMenu('list');
		$result = $self->EventList();
	    }
	    else
	    {
		$SubTmpl->param('Saved' => 0);
		$SubTmpl->param('Error' => 1);

		$self->_FillMenu('list');
		$result = $SubTmpl->output();
	    }

	}
	else
	{
	    $SubTmpl->param('EntryID' => $query->param('EntryID'));
	    $SubTmpl->param('Orgs' => $self->_getUsersOrgList( 'Selected' => [$OrgID] ));
	    $SubTmpl->param('Date' => $query->param('Date'));
	    $SubTmpl->param('Time' => $query->param('Time'));
	    $SubTmpl->param('Place' => $query->param('Place'));
	    $SubTmpl->param('Description' => $query->param('Description'));
	    $SubTmpl->param('Public' => $Public ? 1 : 0);

	    $self->_FillMenu('list');
	    $result = $SubTmpl->output();
	}
    }
    else
    {
	$SubTmpl->param('EntryID' => $query->param('EntryID'));
	$SubTmpl->param('Orgs' => $self->_getUsersOrgList( 'Selected' => [$Event->getOrgID()] ));
	my $tmpDate = join('-', reverse($Event->getDate->getDate()));
	$SubTmpl->param('Date' => $tmpDate);
	$SubTmpl->param('Time' => $Event->getTime());
	$SubTmpl->param('Place' => $Event->getPlace());
	$SubTmpl->param('Description' => $Event->getDesc());
	$SubTmpl->param('Public' => $Event->isPublic());

	$self->_FillMenu('list');
	$result = $SubTmpl->output();
    }
    
    return $result;
}

sub Passwd
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Passwort ändern' );
    my $SubTmpl = $self->load_tmpl( 'user-passwd.tmpl');

    my $query = $self->query();

    my $Action = $query->param('Action') || '';
    my $OldPass = $query->param('OldPass') || '';
    my $NewPass1 = $query->param('NewPass1') || '';
    my $NewPass2 = $query->param('NewPass2') || '';

    my $UserID = $self->getUser()->{UserID};

    if($Action eq 'save')
    {
	if($NewPass1 ne $NewPass2)
	{
	    $SubTmpl->param('NewPWError' => 1);
	}
	else
	{
	    my $sql = sprintf( "SELECT password(%s) = User.Password FROM User WHERE User.UserID = %d LIMIT 1",
			       $self->getDBH()->quote($OldPass),
			       $UserID );
	    
	    my $Result = $self->getDBH()->selectrow_array($sql);

	    if( $Result == 1 )
	    {
		$sql = sprintf("UPDATE User SET Password=password(%s)
                                WHERE password(%s) = User.Password
                                AND User.UserID = %d",
			       $self->getDBH()->quote($NewPass1),
			       $self->getDBH()->quote($OldPass),
			       $UserID );
	    
		$self->getDBH()->do($sql);

		$self->logger("Changed password");
		$SubTmpl->param('OK' => 1);
	    }
	    else
	    {
		$SubTmpl->param('OldPWError' => 1);
		$self->logger("password change failed");
	    }
	}
    }

    return $SubTmpl->output();    
}

sub _OrgName($)
{
    my $self = shift;
    my ($OrgID) = @_;

    my $sql = "SELECT OrgName FROM Organization WHERE OrgID = $OrgID LIMIT 1";

    my $Result = $self->getDBH()->selectrow_array($sql);

    return $Result;
}

sub Config
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Konfiguration' );
    my $SubTmpl;

    my $query = $self->query();

    if( $query->param('OrgID') )
    {
	$SubTmpl = $self->load_tmpl( 'tmpl-upload.tmpl' );
	my $OrgID = $query->param('OrgID');

	$SubTmpl->param('OrgName' => $self->_OrgName($OrgID));
	$SubTmpl->param('OrgID' => $OrgID);

	if( $query->param('action') )
	{
	    $self->setOrgPref( $OrgID, 'bgcolor', $query->param('bgcolor'));
	    $self->setOrgPref( $OrgID, 'textcolor', $query->param('textcolor'));
	    $self->setOrgPref( $OrgID, 'linkcolor', $query->param('linkcolor'));
	    $self->setOrgPref( $OrgID, 'font', $query->param('font'));
	}

	$SubTmpl->param('bgcolor' => $self->getOrgPref($OrgID, 'bgcolor'));
	$SubTmpl->param('textcolor' => $self->getOrgPref($OrgID, 'textcolor'));
	$SubTmpl->param('linkcolor' => $self->getOrgPref($OrgID, 'linkcolor'));
	$SubTmpl->param('font' => $self->getOrgPref($OrgID, 'font'));
    }
    else
    {
	$SubTmpl = $self->load_tmpl( 'config.tmpl' );
	$SubTmpl->param('Orgs' => $self->_getUsersOrgList());

    }

    return $SubTmpl->output();    
}

sub UserList
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Benutzer' );
    my $SubTmpl = $self->load_tmpl('user-list.tmpl');

    $SubTmpl->param( 'Users' => $self->_getUserList() );

    return $SubTmpl->output();
}

sub UserAdd
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Neuer Benutzer' );
    my $SubTmpl = $self->load_tmpl( 'user-add.tmpl' );

    my $query = $self->query();

    my $Action = $query->param('Action') || '';

    my $LoginName = $query->param('Login') || '';
    $LoginName = $self->_trim( $LoginName );

    my $FullName = $query->param('FullName') || '';
    my $eMail = $query->param('eMail') || '';
    my $Password = 'default';
    my @Orgs =  $query->param('Orgs');


    if($Action eq 'Save')
    {
	my $Error = 0;

	if($LoginName eq '')
	{
	    $Error = 1;
	    $SubTmpl->param('LoginError' => 1);
	}
	else
	{
	    my $sql = "SELECT COUNT(UserID) FROM User WHERE UserName = '$LoginName'";

	    if( $self->getDBH()->selectrow_array($sql) )
	    {
		$Error = 1;
		$SubTmpl->param('UserExists' => 1);
	    }
	}

	if($FullName eq '')
	{
	    $Error = 1;
	    $SubTmpl->param('FullNameError' => 1);
	}
	
	if($eMail eq '')
	{
	    $Error = 1;
	    $SubTmpl->param('eMailError' => 1);
	}

	unless($Error)
	{
	    $self->getDBH()->do("INSERT INTO User (FullName, eMail, UserName, Password)
                   VALUES('$FullName', '$eMail', '$LoginName' , password('$Password'))");

	    my $UserID = $self->getDBH()->selectrow_array("SELECT last_insert_id() FROM User LIMIT 1");

	    if(@Orgs)
	    {
		my $sql = "INSERT INTO Org_User (OrgID, UserID) VALUES ";
		$sql .=  join( ', ', map { "($_, $UserID)" } @Orgs );

		$self->getDBH()->do($sql);
	    }

	    $SubTmpl->param('Saved' => $LoginName);
	    $self->logger( "Created new user: '$LoginName' ($FullName); Orgs: ".join( ', ', @Orgs ) );
	    @Orgs = ();
	}
	else
	{
	    $SubTmpl->param('Login' => $query->param('Login'));
	    $SubTmpl->param('FullName' => $query->param('FullName'));
	    $SubTmpl->param('eMail' => $query->param('eMail'));
	    $self->logger( "creating new user failed" );
	}
    }

    $SubTmpl->param('Orgs' => $self->_getOrgList(@Orgs));

    return $SubTmpl->output();
}

sub UserEdit
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Benutzer bearbeiten' );
    my $SubTmpl = $self->load_tmpl( 'user-edit.tmpl' );

    my $query = $self->query();

    my $Action = $query->param('Action') || '';

    my $UserID = $query->param('UserID') || '';
    my $FullName = $query->param('FullName') || '';
    my $eMail = $query->param('eMail') || '';
    my $isAdmin = $query->param('isAdmin') ? 1 : 0;
    my @Orgs =  $query->param('Orgs');

    if($Action eq 'Save')
    {
	my $Error = 0;

        if(@Orgs == 0)
        {
	    $SubTmpl->param( 'OrgError' => 1 );
	    $Error = 1;
        }

        if($UserID eq '')
        {
	    $Error = 1;
        }

        if($FullName eq '')
        {
	    $SubTmpl->param( 'FullNameError' => 1 );
	    $Error = 1;
        }

        if($eMail eq '')
        {
	    $SubTmpl->param( 'eMailError' => 1 );
	    $Error = 1;
        }
	
	unless( $Error )
	{
	    my $FullNameSQL = $self->getDBH()->quote($FullName);
	    my $eMailSQL = $self->getDBH()->quote($eMail);

	    $self->getDBH()->do("UPDATE User
                               SET FullName = $FullNameSQL,
                               eMail = $eMailSQL,
                               isAdmin = $isAdmin
                               WHERE UserID = $UserID");

	    my $ArrRef = $self->_getUsersOrgList( 'UserID' => $UserID );
	    my @UserOrgs = map { $_->{OrgID} } @$ArrRef;

	    my ($ToAddRef, $ToDeleteRef) = $self->_ArrayDiff(\@Orgs, \@UserOrgs);

	    my @ToAdd = @$ToAddRef;
	    my @ToDelete = @$ToDeleteRef;

	    #print STDERR "ALL:".join(',', @UserOrgs)."\n";
	    #print STDERR "SEL:".join(',', @Orgs)."\n";

	    #print STDERR "ADD:".join(',', @ToAdd)."\n";
	    #print STDERR "DEL:".join(',', @ToDelete)."\n";

	    if(@ToAdd)
	    {
		my $sql = "INSERT INTO Org_User (OrgID, UserID) VALUES ";
		$sql .=  join( ', ', map { "($_, $UserID)" } @ToAdd );

		$self->getDBH()->do($sql);
	    }

	    if(@ToDelete)
	    {
		my $sql = "DELETE FROM Org_User where UserID = $UserID  AND (";
		$sql .=  join( ' OR ', map { "OrgID = $_" } @ToDelete );
		$sql .= ")";

		$self->getDBH()->do($sql);
	    }

	    $self->logger( "Modified user: '$FullName' ($UserID); Admin: $isAdmin; ".
			   "Add Orgs: ".join( ', ', @ToAdd )."; Remove Orgs: ".join( ', ', @ToDelete ) );

	    $self->_FillMenu('userlist');
	    return $self->UserList();
	}
	else
	{
	    $SubTmpl->param('UserID' => $query->param('UserID'));
	    $SubTmpl->param('Login' => $query->param('Login'));
	    $SubTmpl->param('FullName' => $query->param('FullName'));
	    $SubTmpl->param('eMail' => $query->param('eMail'));
	    $SubTmpl->param('isAdmin' => 'checked') if $query->param('isAdmin');
	    $SubTmpl->param('Orgs' => $self->_getOrgList(@Orgs));
	}
    }
    else
    {
	my $sql = "SELECT u.UserID, u.FullName, u.UserName, u.eMail, u.isAdmin, u.LastLogin ".
	    "FROM User u ".
	    "WHERE u.UserID = $UserID";

	my $UserData = $self->getDBH()->selectrow_hashref($sql);

	$SubTmpl->param('UserID' => $UserData->{UserID});
	$SubTmpl->param('UserName' => $UserData->{UserName});
	$SubTmpl->param('FullName' => $UserData->{FullName});
	$SubTmpl->param('eMail' => $UserData->{eMail});
	$SubTmpl->param('LastLogin' => $UserData->{LastLogin});
	$SubTmpl->param('isAdmin' => 'checked') if $UserData->{isAdmin};

	my $ArrRef = $self->_getUsersOrgList( 'UserID' => $UserID );
	my @UsersOrgs = map { $_->{OrgID} } @$ArrRef;

	my $OrgList = $self->_getOrgList(@UsersOrgs);
	$SubTmpl->param('Orgs' => $OrgList);
    }

    return $SubTmpl->output();
}

sub OrgList
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Vereine' );
    my $SubTmpl = $self->load_tmpl('org-list.tmpl');

    $SubTmpl->param( 'Orgs' => $self->_getOrgList() );

    return $SubTmpl->output();
}

sub OrgAdd
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Neuer Verein' );
    my $SubTmpl = $self->load_tmpl( 'org-add.tmpl' );

    my $query = $self->query();

    my $Action = $query->param('Action') || '';
    
    my $Name = $query->param('Name') || '';
    my $eMail = $query->param('eMail') || '';
    my $Website = $query->param('Website') || '';
    my @Users =  $query->param('Users');   
    
    if($Action eq 'Save')
    {
	my $Error = 0;

	if( $Name eq '' )
	{
	    $SubTmpl->param( 'NameError' => 1 );
	    $Error = 1;
	}

	if( $eMail ne '' && !($eMail =~ /\@/) )
	{
	    $SubTmpl->param( 'eMailError' => 1 );
	    $Error = 1;
	}

	unless( $Error )
	{
	    my $NameSQL = $self->getDBH()->quote($Name);
	    my $eMailSQL = $self->getDBH()->quote($eMail);
	    my $WebsiteSQL = $self->getDBH()->quote($Website);

	    $self->getDBH()->do("INSERT INTO Organization
                   (OrgName, eMail, Website)
                   VALUES ($NameSQL, $eMailSQL, $WebsiteSQL)");
	    
	    # Update relations Orgs->Users
	    my $OrgID = $self->getDBH()->selectrow_array("SELECT LAST_INSERT_ID() FROM Organization LIMIT 1");

	    if(@Users)
	    {
		my $sql = "INSERT INTO Org_User (OrgID, UserID) VALUES ";
		$sql .=  join( ', ', map { "($OrgID, $_)" } @Users );

		$self->getDBH()->do($sql);
	    }

	    $self->logger("Added Organization: '$Name' ($OrgID); Users: ".join( ', ', @Users ));

	    $self->_FillMenu('orglist');
	    return $self->OrgList();
	}
	else
	{
	    $SubTmpl->param('Name' => $query->param('Name'));
	    $SubTmpl->param('eMail' => $query->param('eMail'));
	    $SubTmpl->param('Website' => $query->param('Website'));
	    $SubTmpl->param('Users' => $self->_getUserList(@Users));
	}
    }
    else
    {
	$SubTmpl->param('Users' => $self->_getUserList());
    }

    return $SubTmpl->output();
}

sub OrgEdit
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Verein bearbeiten' );
    my $SubTmpl = $self->load_tmpl( 'org-edit.tmpl' );

    my $query = $self->query();

    my $Action = $query->param('Action') || '';

    my $OrgID = $query->param('OrgID') || '';
    my $Name = $query->param('Name') || '';
    my $eMail = $query->param('eMail') || '';
    my $Website = $query->param('Website') || '';
    my @Users =  $query->param('Users');   

    if($Action eq 'Save')
    {
	my $Error = 0;

	if($OrgID eq '')
	{
	    $Error = 1;
	}

	if( $eMail ne '' && !($eMail =~ /\@/) )
	{
	    $Error = 1;
	    $SubTmpl->param( 'eMailError' => 1 );
	}

	unless( $Error )
	{
	    my $eMailSQL = $self->getDBH()->quote($eMail);
	    my $WebsiteSQL = $self->getDBH()->quote($Website);

	    $self->getDBH()->do("UPDATE Organization
                               SET eMail = $eMailSQL, Website = $WebsiteSQL
                               WHERE OrgID = $OrgID");
	    
	    # Update relations Orgs->Users
	    my $Org = WebEve::cOrg->new( OrgID => $OrgID);

	    my $ArrRef = $Org->getUsers();
	    my @OrgUsers = map { $_->{UserID} } @$ArrRef;

	    my ($ToAddRef, $ToDeleteRef) = $self->_ArrayDiff(\@Users, \@OrgUsers);

	    my @ToAdd = @$ToAddRef;
	    my @ToDelete = @$ToDeleteRef;

	    #print STDERR "ALL:".join(',', @OrgUsers)."\n";
	    #print STDERR "SEL:".join(',', @Users)."\n";

	    #print STDERR "ADD:".join(',', @ToAdd)."\n";
	    #print STDERR "DEL:".join(',', @ToDelete)."\n";

	    if(@ToAdd)
	    {
		my $sql = "INSERT INTO Org_User (OrgID, UserID) VALUES ";
		$sql .=  join( ', ', map { "($OrgID, $_)" } @ToAdd );

		$self->getDBH()->do($sql);
	    }

	    if(@ToDelete)
	    {
		my $sql = "DELETE FROM Org_User where OrgID = $OrgID  AND (";
		$sql .=  join( ' OR ', map { "UserID = $_" } @ToDelete );
		$sql .= ")";

		$self->getDBH()->do($sql);
	    }

	    $self->logger("Modified Organization: '$OrgID'; Add Users: ".join( ', ', @ToAdd ).
			  "; Remove Users: ".join( ', ', @ToDelete ));

	    $self->_FillMenu('orglist');
	    return $self->OrgList();
	}
	else
	{
	    $SubTmpl->param('OrgID' => $query->param('OrgID'));
	    $SubTmpl->param('Name' => $query->param('Name'));
	    $SubTmpl->param('eMail' => $query->param('eMail'));
	    $SubTmpl->param('Website' => $query->param('Website'));
	    $SubTmpl->param('Users' => $self->_getUserList(@Users));
	}
    }
    else # $Action ne 'Save'
    {
	my $sql = "SELECT o.OrgID, o.OrgName, o.eMail, o.Website ".
	    "FROM Organization o ".
	    "WHERE o.OrgID = $OrgID";

	my $OrgData = $self->getDBH()->selectrow_hashref($sql);

	$SubTmpl->param('OrgID' => $OrgData->{OrgID});
	$SubTmpl->param('OrgName' => $OrgData->{OrgName});
	$SubTmpl->param('eMail' => $OrgData->{eMail});
	$SubTmpl->param('Website' => $OrgData->{Website});

	my $Org = WebEve::cOrg->new( OrgID => $OrgID);
	my $ArrRef = $Org->getUsers();

	my @OrgsUsers = map { $_->{UserID} } @$ArrRef;

	my $UserList = $self->_getUserList(@OrgsUsers);
	$SubTmpl->param('Users' => $UserList);
    }

    return $SubTmpl->output();
}

1;
