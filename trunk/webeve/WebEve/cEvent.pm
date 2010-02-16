# $Id$
# ===============================================================================
# The Class 'cEvent'
# ===============================================================================

package WebEve::cEvent;

use strict;
use vars qw( $Count $HashRefOrgs );

use base 'WebEve::cBase';

use WebEve::cDate;
use WebEve::cOrg;
use WebEve::cLog;

$Count = 0;

# -------------------------------------------------------------------------------
# The Constructors
# -------------------------------------------------------------------------------

sub new
{
    my $class = shift;

    die "Constructor has to be used as instance method!" if ref($class);

    my $self = {};

    bless( $self, $class );

    # Initialize variables
    $self->_init(@_);

    $Count++;
    return $self;
}

sub newFromDB
{
    my $class = shift;

    die "Constructor has to be used as instance method!" if ref($class);

    my $self = {};

    bless( $self, $class );

    # Initialize variables
    $self->_getFromDB(@_);

    $Count++;
    return $self;
}

sub DESTROY
{
    my $self = shift;

    --$Count;
}

# -------------------------------------------------------------------------------
# Private Methods:
# -------------------------------------------------------------------------------

sub _init
{
    my $self = shift;
    my %Param = @_;

    my $KeyCount = scalar( keys( %Param ) );

    if( exists( $Param{'EntryID'} ) )
    {
	$self->{warn} = "EntryID is not allowed with 'new'.";
    }
    else
    {
	$self->{'EntryID'} = $Param{'EntryID'};

	foreach( 'Date',
		 'Time',
		 'Place',
		 'Title',
		 'Description',
		 'UserID',
		 'OrgID',
		 'Public',
		 'LastChange' )
	{
	    if( exists($Param{$_}) )
	    {
		$self->{$_} = $Param{$_};
	    }
	    else
	    {
		$self->{$_} = '';
	    }
	}
    }

}    

# -------------------------------------------------------------------------------

sub _getFromDB
{
    my $self = shift;

    if( defined( $_[0] ) )
    {
	my $EntryID = $_[0];

	my $sql = "SELECT d.EntryID,
                          d.Date,
	                  d.Time,
                          d.Place,
                          d.Title,
                          d.Description,
      	                  d.UserID,
      	                  d.OrgID,
      	                  d.Public,
      	                  d.LastChange
      	           FROM Dates d
      	           WHERE EntryID = ?
      	           ORDER by d.Date, d.Time";

	my $sth = $self->getDBH()->prepare_cached($sql);
	
	$sth->execute($EntryID);

	my $hrefData = $sth->fetchrow_hashref();

	$sth->finish();

	if( scalar( keys( %$hrefData ) ) == 0 )
	{
	    $self->{Error} = "No data from DB for ID:$EntryID";
	    return 0;
	}
	else
	{
	    foreach my $Key ( keys( %$hrefData ) )
	    {
		$self->{$Key} = $hrefData->{$Key};
	    }

	    return 1;
	}
    }
    else
    {
	$self->{Error} = "EntryID not defined.";
    }
}

# -------------------------------------------------------------------------------

sub _fillOrgCache
{
    my $self = shift;

    unless( ref($HashRefOrgs) )
    {
	my $sql = "SELECT OrgID, OrgName FROM Organization";

	# HashRefOrgs is a Class-Value
	$HashRefOrgs = $self->getDBH()->selectall_hashref($sql, 'OrgID');
    }
}

# -------------------------------------------------------------------------------

sub logger
{
    my $self = shift;

    if(ref($self->{log}) ne 'WebEve::cLog')
    {
	my $Logfile = $self->getConfig( 'LogFile' );
	$self->{log} = WebEve::cLog->new($Logfile);
    }

    $self->{log}->logger(@_);
}
   
# -------------------------------------------------------------------------------
# Public Methods:
# -------------------------------------------------------------------------------

sub Count
{
    return $Count;
}

# -------------------------------------------------------------------------------

sub getErrorMessage
{
    my $self = shift;

    return $self->{Error};
}

# -------------------------------------------------------------------------------

sub getTime
{
    my $self = shift;
    
    my $result;

    if( !exists( $self->{Hour} ) || !exists( $self->{Minute} ))
    {
	if( exists($self->{'Time'}) )
	{
	    ($self->{Hour}, $self->{Minute}) = split(/:/, $self->{'Time'});
	}
    }

    if( exists( $self->{Hour} ) && exists( $self->{Minute} ))
    {
	if( $self->{Hour} >= 0 )
	{
	    $result = sprintf( "%02d:%02d",
			       $self->{Hour},
			       $self->{Minute} );
	}
	else
	{
	    $result = '';
	}
    }
    else
    {
	$result = '?';
    }

    return $result;
}

sub getTimeSQL
{
    my $self = shift;
    
    my $result;

    if( !exists( $self->{Hour} ) || !exists( $self->{Minute} ))
    {
	if( exists($self->{'Time'}) )
	{
	    ($self->{Hour}, $self->{Minute}) = split(/:/, $self->{'Time'});
	}
    }

    if( exists( $self->{Hour} ) && exists( $self->{Minute} ))
    {
	$result = sprintf( "%02d:%02d:00",
			   $self->{Hour},
			   $self->{Minute} );
    }
    else
    {
	$result = '-01:00:00';
    }

    return $result;
}

sub setTime($)
{
    my $self = shift;

    my $TimeStr = shift;
    my $result = 0;

    if( defined($TimeStr) && $TimeStr ne '' )
    {
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

	if( $Hour < 0 || $Hour > 23 || $Minute < 0 || $Minute > 59 )
	{
	    $result = 0;
	}
	else
	{
	    $self->{Hour} = $Hour;
	    $self->{Minute} = $Minute;

	    $result = 1;
	    $self->{changed} = 1;
	}

    }
    else
    {
	$self->{Hour} = -1;
	$self->{Minute} = 0;

	$result = 1;
	$self->{changed} = 1;
    }

    return $result;
}

# -------------------------------------------------------------------------------

sub getPlace
{
    my $self = shift;

    return $self->{'Place'} || '';
}

sub setPlace($)
{
    my $self = shift;

    $self->{Place} = $_[0];
    $self->{changed} = 1;

    return 1;
}

# -------------------------------------------------------------------------------
# Title

sub getTitle
{
    my $self = shift;

    return $self->{'Title'};
}

sub setTitle($)
{
    my $self = shift;

    $self->{'Title'} = $_[0];

    $self->{'Title'} =~ s/^\s+//g; 
    $self->{'Title'} =~ s/\s+$//g; 

    $self->{changed} = 1;

    return ( defined($self->getTitle) && $self->getTitle ne '') ? 1 : 0;
}

# -------------------------------------------------------------------------------
# Description

sub getDesc
{
    my $self = shift;

    return $self->{'Description'};
}

sub setDesc($)
{
    my $self = shift;

    $self->{Description} = $_[0];

    $self->{'Description'} =~ s/^\s+//g; 
    $self->{'Description'} =~ s/\s+$//g; 

    $self->{changed} = 1;

    return ( defined($self->getDesc) && $self->getDesc ne '') ? 1 : 0;
}

# -------------------------------------------------------------------------------
# OrgID

sub getOrgID
{
    my $self = shift;

    return $self->{'OrgID'};
}

sub setOrgID($)
{
    my $self = shift;

    my $result = 0;

    $self->_fillOrgCache();

    if( exists($HashRefOrgs->{ $_[0] }) )
    {
	$self->{OrgID} = $_[0];
	$self->{changed} = 1;
	$result = 1;
    }
    else
    {
	$self->{Error} = "OrgID is invalid";
	$result = 0;
    }

    return $result;
}

# -------------------------------------------------------------------------------

sub getOrg(;$)
{
    my $self = shift;
    my $Mode = shift || 'clean';

    #$self->_fillOrgCache();
    return WebEve::cOrg->new(OrgID => $self->{'OrgID'});
    #my $OrgName = $HashRefOrgs->{ $self->{'OrgID'} }->{'OrgName'};
    #$OrgName = '' if( $OrgName eq '-unbekannt-' && $Mode eq 'clean');

    #return $OrgName;
}

# -------------------------------------------------------------------------------

sub getID
{
    my $self = shift;

    return $self->{'EntryID'};
}

# -------------------------------------------------------------------------------

sub getDate
{
    my $self = shift;

    unless( ref($self->{DateObj}) )
    {
	$self->{DateObj} = WebEve::cDate->newSQL( $self->{Date} );
    }

    return $self->{DateObj};
}

sub setDate()
{
    my $self = shift;
    
    my $DateStr = shift;

    unless( ref($self->{DateObj}) )
    {
	$self->{DateObj} = WebEve::cDate->new( $DateStr );
    }
    else
    {
	$self->{DateObj}->setDate(@_);
    }

    return $self->{DateObj}->isValid;
}

# -------------------------------------------------------------------------------

sub getTmplParams($)
{
    my $self = shift;
    my $Prefix = shift || '';

    return { $Prefix.'Date' => $self->getDate->getDateStr,
	     $Prefix.'Time' => $self->getTime,
	     $Prefix.'Place' => $self->getPlace,
	     $Prefix.'Title' => $self->getTitle,
	     $Prefix.'Desc' => $self->getDesc,
	     $Prefix.'EntryID' => $self->getID,
	     $Prefix.'Org' => $self->getOrg,
	     $Prefix.'OrgID' => $self->getOrgID,
	     $Prefix.'Public' => $self->isPublic,
	     $Prefix.'IsOver' => $self->isOver };
}

# -------------------------------------------------------------------------------
# Public

sub isPublic
{
    my $self = shift;

    return $self->{'Public'} ? 1 : 0;
}

sub setIsPublic($)
{
    my $self = shift;

    $self->{Public} = $_[0] > 0;

    $self->{changed} = 1;

    return 1;
}

# -------------------------------------------------------------------------------
# Date!, Time?, Place?, Description!, OrgID!, UserID!, Public!

sub isValid
{
    my $self = shift;

#	( defined($self->getUserID) && $self->getUserID != 0 ) &&


    if( $self->getDate->isValid &&
	( exists($self->{Hour}) && exists($self->{Minute}) ) &&
	( defined($self->getTitle ) && $self->getTitle ne '' ) &&
	( defined($self->getOrgID) && $self->getOrgID ) &&
        ( defined($self->isPublic) ) )
    {
	return 1;
    }
    else
    {
	return 0;
    }
}

# -------------------------------------------------------------------------------
# -------------------------------------------------------------------------------

sub _CheckPermission($)
{
    my $self = shift;

    my $UserID = shift;
    my $OrgID = $self->getOrgID;

    my $sql = "SELECT count(*) FROM Org_User ".
	"WHERE OrgID = $OrgID AND UserID = $UserID LIMIT 1";

    return $self->getDBH()->selectrow_array($sql);
}

sub SaveData($)
{
    my $self = shift;

    my ($UserID) = shift;
    my $result = 0;

    unless( defined($UserID) )
    {
	$self->logger("ERROR: SaveData failed: no UserID");
	return 0;
    }

    unless( $self->isValid )
    {
	$self->logger("SaveData failed: not valid");
	return 0;
    }

    unless( $self->_CheckPermission($UserID) )
    {
	$self->logger("ERROR: SaveData failed: User not permitted");
	return 0;
    }

    my $DateSQL = $self->getDBH()->quote($self->{DateObj}->getDateStrSQL());
    my $TimeSQL = $self->getDBH()->quote($self->getTimeSQL);
    
    my $PlaceSQL = $self->getDBH()->quote($self->getPlace);
    my $TitleSQL = $self->getDBH()->quote($self->getTitle);
    my $DescriptionSQL = $self->getDBH()->quote($self->getDesc);

    if( exists( $self->{'EntryID'} ) && $self->{'EntryID'} )
    {
	my $sql = sprintf( "UPDATE Dates SET Date = %s, Time = %s, Place = %s, ".
			   "Title = %s, Description = %s, OrgID = %d, UserID = %d, Public = %d ".
			   "WHERE EntryID = %d",
			   $DateSQL,
			   $TimeSQL,
			   $PlaceSQL,
			   $TitleSQL,
			   $DescriptionSQL,
			   $self->getOrgID,
			   $UserID,
			   $self->isPublic,
			   $self->{'EntryID'} );

	$self->logger("SaveData: UPDATE for EntryID ".$self->{'EntryID'});

	$result = $self->getDBH()->do($sql) ? $self->{EntryID} : 0;
    }
    else
    {
	my $sql = sprintf( "INSERT INTO Dates (Date, Time, Place, Title, Description, OrgID, UserID, Public) ".
			   "VALUES(%s, %s, %s, %s, %s, %d, %d, %d)",
			   $DateSQL,
			   $TimeSQL,
			   $PlaceSQL,
			   $TitleSQL,
			   $DescriptionSQL,
			   $self->getOrgID,
			   $UserID,
			   $self->isPublic );

	$self->getDBH()->do($sql);

	$self->{EntryID} = $self->getDBH()->selectrow_array("SELECT LAST_INSERT_ID() FROM Dates LIMIT 1");

	$self->logger("SaveData: INSERT for new date: ".$self->{EntryID});

	$result = $self->{EntryID};
    }

    $self->{changed} = 0;

    return $result;
}

sub DeleteData($)
{
    my $self = shift;
    my ($UserID) = shift;
    my $result = 0;

    unless( defined($UserID) )
    {
	$self->logger("ERROR: DeleteData failed: no UserID");
	$result = 0;
    }
    elsif( ! $self->_CheckPermission($UserID) )
    {
	$self->logger("ERROR: DeleteData failed: User not permitted");
	$result = 0;
    }
    elsif( exists( $self->{'EntryID'} ) && $self->{'EntryID'} )
    {
	$self->logger("DeleteData: Deleted Event:".$self->getID());
	$result = $self->getDBH()->do("DELETE FROM Dates WHERE EntryID = ".$self->getID());
	$self->{EntryID} = undef if $result;
    }
    else
    {
	$self->logger("ERROR: DeleteData failed: EntryID missing");
	$result = 0;
    }

    return $result;
}

1;
