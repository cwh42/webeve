# $Id$
# ===============================================================================
# The Class 'cEvent'
# ===============================================================================

package WebEve::cEvent;

use strict;
use vars qw( $Count $HashRefOrgs );
use WebEve::cDate;
use WebEve::cMySQL;

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

sub newForEventList
{
    my $class = shift;

    die "Constructor has to be used as instance method!" if ref($class);

    my $self = {};

    bless( $self, $class );

    # Initialize variables
    $self->_fillValues(@_);

    $Count++;
    return $self;
}

sub DESTROY
{
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

sub _fillValues
{
    my $self = shift;
    my $Param = shift;

    if( exists( $Param->{'EntryID'} ) )
    {
	foreach( 'EntryID',
		 'Date',
		 'Time',
		 'Place',
		 'Description',
		 'UserID',
		 'OrgID',
		 'Public',
		 'LastChange' )
	{
	    if( exists($Param->{$_}) )
	    {
		$self->{$_} = $Param->{$_};
	    }
	    else
	    {
		$self->{$_} = '';
	    }
	}

	return 1;
    }
    else
    {
	$self->{Error} = "EntryID is missing.";
	return 0;
    }
}    

# -------------------------------------------------------------------------------

sub _getFromDB
{
    my $self = shift;

    if( defined( $_[0] ) )
    {
	my $EntryID = $_[0];

	my $sql = "SELECT d.Date,
	                  d.Time,
                          d.Place,
                          d.Description,
      	                  d.UserID,
      	                  d.OrgID,
      	                  d.Public,
      	                  d.LastChange
      	           FROM Dates d
      	           WHERE EntryID = $EntryID
      	           ORDER by d.Date, d.Time";
      
	my $dbh = WebEve::cMySQL->connect('default');

	my $hrefData = $dbh->selectrow_hashref($sql);

	if( scalar( keys( %{$hrefData} ) ) == 0 )
	{
	    $self->{Error} = "No data from DB for ID:$EntryID";
	    return 0;
	}
	else
	{
	    foreach my $Key ( keys( %{$hrefData} ) )
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
    unless( ref($HashRefOrgs) )
    {
	my $dbh = WebEve::cMySQL->connect_cached();
	my $sql = "SELECT OrgID, OrgName FROM Organization";

	# HashRefOrgs is a Class-Values
	$HashRefOrgs = $dbh->selectall_hashref($sql, 'OrgID');
    }
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

    unless( exists( $self->{'Time'} ) )
    {
	$self->{'Time'} = '-01:00:00';
    }

    my ($hour, $min) = split(/:/, $self->{'Time'});

    if( $hour >= 0 )
    {
	return sprintf( "%02d:%02d",
			$hour,
			$min );
    }
    else
    {
	return '';
    }
}

# -------------------------------------------------------------------------------

sub getPlace
{
    my $self = shift;

    return $self->{'Place'};
}

sub setPlace($)
{
    my $self = shift;

    $self->{Place} = $_[0];
    $self->{changed} = 1;

    return 1;
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
    $self->{changed} = 1;

    return 1;
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

    if( exists($HashRefOrgs->{ $_[0] }) )
    {
	$self->{OrgID} = $_[0];
	$self->{changed} = 1;
	return 1;
    }
    else
    {
	$self->{Error} = "OrgID is invalid";
	return 0;
    }
}

# -------------------------------------------------------------------------------

sub getOrg(;$)
{
    my $self = shift;
    my $Mode = shift || 'clean';

    _fillOrgCache();

    my $OrgName = $HashRefOrgs->{ $self->{'OrgID'} }->{'OrgName'};
    $OrgName = '' if( $OrgName eq '-unbekannt-' && $Mode eq 'clean');

    return $OrgName;
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

# -------------------------------------------------------------------------------

sub getTmplParams($)
{
    my $self = shift;
    my $Prefix = shift || '';

    return { $Prefix.'Date' => $self->getDate->getDateStr,
	     $Prefix.'Time' => $self->getTime,
	     $Prefix.'Place' => $self->getPlace,
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

    return $self->{'Public'};
}

sub setIsPublic($)
{
    my $self = shift;

    $self->{Public} = $_[0] > 0;
    $self->{changed} = 1;

    return 1;
}

# -------------------------------------------------------------------------------
# -------------------------------------------------------------------------------

sub SaveData()
{
    my $self = shift;


# Funzt noch garnet!!
    if( exists( $self->{'EntryID'} ) )
    {
    }
    else
    {
	my $sql = sprintf("INSERT INTO Dates (Date, Time, Place, Description, OrgID, UserID, Public)
                          VALUES( '%d-%02d-%02d', '%02d:%02d:00', %s, %s, %d, %d, %d)",
			  $self->{'Year'}, $self->{'Month'}, $self->{'Day'},
			  $self->{'Hour'}, $self->{'Min'},
			  sqlQuote($self->{'Place'}),
			  sqlQuote($self->{'Description'}),
			  $self->{'OrgID'},
			  $self->{'UserID'},
			  $self->{'Public'} );
	
	$self->{'EntryID'} = FetchOneColumn(SendSQL("SELECT LAST_INSERT_ID() FROM Dates LIMIT 1"));
    }
    $self->{changed} = 0;
    return 1;
}


1;
