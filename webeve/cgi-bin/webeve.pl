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
use base 'WebEve::WebEveApp';
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
		      'delete' => 'Delete', 
		      'edit' => 'Edit', 
		      'passwd' => 'Passwd',
		      'config' => 'Config',
		      'userlist' => 'UserList',
		      'useradd' => 'UserAdd',
		      'useredit' => 'Useredit',
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

sub _trim($)
{
    my ($string) = @_;

    $string =~ s/^\s+//s;
    $string =~ s/\s+$//s;

    return $string;
}

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

	    my $SessionID = $self->_MakeSessionID($User);

	    my $Cookie = $query->cookie(-name=>'sessionID',
					-value=>$SessionID);

	    $self->header_props(-cookie=>$Cookie);

	    $self->{dbh}->do("INSERT INTO Logins (SessionID, UserID, Expires) ".
			     "VALUES('$SessionID', ".$self->{UserID}.", ADDDATE(now(), INTERVAL 8 HOUR))");

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
			'Org' => $DateObj->getOrg('all'),
			'EntryID' => $DateObj->getID,
			'Public' => $DateObj->isPublic,
			'IsOver' => $DateObj->getDate->isOver };

	push( @Dates, $HashRef );	
    }

    $SubTmpl->param('List' => \@Dates);

    $SubTmpl->param('FullName' => $self->{FullName});
    $SubTmpl->param('User' => $self->{UserName});
    $SubTmpl->param('Admin' => $self->{isAdmin});

    @ShowOrg = map { $_->{'OrgID'} } ( @{$self->_getUsersOrgList()} ) if( scalar(@ShowOrg) == 0 );
    $SubTmpl->param('Orgs' => $self->_getUsersOrgList(@ShowOrg));

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
	    if($Event->SaveData($self->{UserID}))
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
		    $SubTmpl->param('Orgs' => $self->_getUsersOrgList($Event->getOrgID()));
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

	    $SubTmpl->param('Orgs' => $self->_getUsersOrgList($OrgID));
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

    my %params = ( 'ForUserID' => $self->{UserID},
		   'BeforeToday' => 1 );

    $params{'ID'} = \@EntryIDs if( scalar(@EntryIDs) > 0 );

    my $EventList = WebEve::cEventList->new( %params );

    if( $Confirm )
    {
	my $delcount = $EventList->deleteData($self->{UserID});
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
	    if($Event->SaveData($self->{UserID}))
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
	    $SubTmpl->param('Orgs' => $self->_getUsersOrgList($OrgID));
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
	$SubTmpl->param('Orgs' => $self->_getUsersOrgList($Event->getOrgID()));
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

    my $UserID = $self->{UserID};

    if($Action eq 'save')
    {
	if($NewPass1 ne $NewPass2)
	{
	    $SubTmpl->param('NewPWError' => 1);
	}
	else
	{
	    my $sql = sprintf( "SELECT password(%s) = User.Password FROM User WHERE User.UserID = %d LIMIT 1",
			       $self->{dbh}->quote($OldPass),
			       $UserID );
	    
	    my $Result = $self->{dbh}->selectrow_array($sql);

	    if( $Result == 1 )
	    {
		$sql = sprintf("UPDATE User SET Password=password(%s)
                                WHERE password(%s) = User.Password
                                AND User.UserID = %d",
			       $self->{dbh}->quote($NewPass1),
			       $self->{dbh}->quote($OldPass),
			       $UserID );
	    
		$self->{dbh}->do($sql);

		$self->logger("Changed password");
		$SubTmpl->param('OK' => 1);
	    }
	    else
	    {
		$SubTmpl->param('OldPWError' => 1);
	    }
	}
    }

    return $SubTmpl->output();    
}

sub Config
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Konfiguration' );
    #my $SubTmpl = $self->load_tmpl( '');

    my $query = $self->query();

    return 0;
}

sub _getUserList
{
    my $self = shift;
    my @Userlist;

    my $sql = "SELECT u.UserID, u.FullName, u.UserName, u.eMail, u.isAdmin, u.LastLogin ".
	"FROM User u ".
	"ORDER BY u.UserName";

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    while( my $hrefData = $sth->fetchrow_hashref() )
    {
	push( @Userlist, $hrefData);
    }

    return \@Userlist;
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
    $LoginName = _trim( $LoginName );

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

	    if( $self->{dbh}->selectrow_array($sql) )
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
	    $self->{dbh}->do("INSERT INTO User (FullName, eMail, UserName, Password)
                   VALUES('$FullName', '$eMail', '$LoginName' , password('$Password'))");

	    my $UserID = $self->{dbh}->selectrow_array("SELECT last_insert_id() FROM User LIMIT 1");

	    if(@Orgs)
	    {
		my $sql = "INSERT INTO Org_User (OrgID, UserID) VALUES ";
		$sql .=  join( ', ', map { "($_, $UserID)" } @Orgs );

		$self->{dbh}->do($sql);
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
	}
    }

    my $OrgList = $self->_getOrgList();

    foreach my $Org ( @$OrgList )
    {
	my $selected = '';

	foreach(@Orgs)
	{
	    $selected = 'checked' if($_ == $Org->{'OrgID'});
	}

	$Org->{'Selected'} = $selected;
    }

    $SubTmpl->param('Orgs' => $OrgList);

    return $SubTmpl->output();
}

sub UserEdit
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Benutzer Bearbeiten' );
    #my $SubTmpl = $self->load_tmpl( '');

    my $query = $self->query();

    return 0;
}

sub _getOrgList
{
    my $self = shift;
    my @Orglist;

    my $sql = "SELECT o.OrgID, o.OrgName, o.eMail, o.Website ".
	"FROM Organization o ORDER BY o.OrgName";

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    while( my $hrefData = $sth->fetchrow_hashref() )
    {
	push( @Orglist, $hrefData);
    }

    return \@Orglist;
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
    #my $SubTmpl = $self->load_tmpl( '');

    my $query = $self->query();

    return 0;
}

sub OrgEdit
{
    my $self = shift;

    $self->{'MainTmpl'}->param( 'TITLE' => 'Verein Bearbeiten' );
    #my $SubTmpl = $self->load_tmpl( '');

    my $query = $self->query();

    return 0;
}

1;
