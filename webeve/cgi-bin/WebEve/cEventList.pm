# $Id$
# ===============================================================================
# The Class 'cEventList'
# ===============================================================================

package WebEve::cEventList;

use strict;
use vars qw( );
use POSIX qw( ceil );
use WebEve::cEvent;
use WebEve::cMySQL;

# -------------------------------------------------------------------------------
# The Constructor
# -------------------------------------------------------------------------------

sub new
{
    my $class = shift;

    die "Constructor has to be used as instance method!" if ref($class);

    my $self = {};

    bless( $self, $class );

    # Initialize variables
    $self->_init(@_);

    return $self;
}

# -------------------------------------------------------------------------------
#
# get a list of dates
# -------------------------------------------------------------------------
# Understands the following parameters:
# bool BeforeToday - also get dates in the past
# bool PublicOnly - get only public dates
# num | arrayref ForOrgID - get only dates for the specified OrgID(s)
# num | arrayref ID - get only dates with the specified EntryID(s)
# num PerPage - return at most num dates
# num Page - return the num'th block of dates

sub _init
{
    my $self = shift;

    my %Params = @_;

    if( exists( $Params{'ForUserID'} ) && $Params{'ForUserID'} )
    {
	$self->{'ForUserID'} = $Params{'ForUserID'};
    }

    # ------------------------------------------

    foreach( 'BeforeToday', 'PublicOnly' )
    {
	if( exists( $Params{$_} ) && $Params{$_} )
	{
	    $self->{$_} = 1;
	}
	else
	{
	    $self->{$_} = 0;
	}
    }

    # ------------------------------------------

    foreach( 'ForOrgID', 'ID' )
    {
	if( exists( $Params{$_} ) )
	{
	    if( ref( $Params{$_} ) eq 'ARRAY' )
	    {
		$self->{$_} = $Params{$_};
	    }
	    else
	    {
		$self->{$_} = [ $Params{$_} ];
	    }
	}
    }

    # ------------------------------------------
 
    $self->{PerPage} = $Params{'PerPage'} || '0';
    $self->{Page} = $Params{'Page'} || '1';
}


sub readData
{
    my $self = shift;

    my $join;
    my $where;
    my @where = ();

    unless( $self->{'BeforeToday'} )
    {
	push( @where,
	      '( Date >= CURDATE() OR ( DAYOFMONTH(Date) = 0 '.
	      'AND YEAR(Date) >= YEAR(CURDATE()) '.
	      'AND MONTH(Date) >= MONTH(CURDATE()) ) )' );
    }

    if( $self->{'PublicOnly'} )
    {
	push( @where, 'Public = 1' );
    }

    if( $self->{'ForOrgID'} )
    {
	my $tmp = join( ' OR ', map { "d.OrgID = $_" } @{$self->{ForOrgID}} );
	
	push( @where, "( $tmp )" ) unless( $self->{ForOrgID}->[0] == 0 && @{$self->{ForOrgID}} == 1);
    }

    if( $self->{'ForUserID'} )
    {
	$join = "LEFT JOIN Org_User ou ON d.OrgID = ou.OrgID";

	my $tmp = "ou.UserID = ".$self->{'ForUserID'};
	
	push( @where, "( $tmp )" );
    }

    if( $self->{'ID'} )
    {
	my $tmp = join( ' OR ', map { "EntryID = $_" } @{$self->{ID}} );

	push( @where, "( $tmp )" ) unless( scalar(@{$self->{ID}}) == 0 );
    }

    # ------------------------------------------------------------------------

    $where = 'WHERE '.join( ' AND ', @where ) if @where;

    # ------------------------------------------------------------------------

    my $dbh = WebEve::cMySQL->connect('default');
    
    my $Count = @{$dbh->selectcol_arrayref("select count(*) from Dates d $join $where")}[0];

    $self->{Pages} = 1;
    my $limit = '';

    if( $self->{'PerPage'} )
    {
	my $Len = $self->{'PerPage'};
	my $Page = $self->{'Page'};

	$Page -= 1;
	$Page = 0 if $Page < 0;

	my $Pages = ceil( $Count / $Len );
	$self->{Pages} = $Pages;

	$Page = $Pages - 1 if $Page >= $Pages;
	
	my $From = $Page * $Len;
	
	$limit = "LIMIT $From, $Len";
    }

    my $sql = "SELECT d.EntryID,
                      d.Date,
	              d.Time,
                      d.Place,
	              d.Description,
	              d.UserID,
	              d.OrgID,
	              d.Public,
	              d.LastChange
               FROM Dates d $join
	       $where
	       ORDER by d.Date, d.Time
               $limit";

#    print STDERR "\n-------------\n$sql\n----------------\n";

    my @Dates = ();
    
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    while( my $hrefData = $sth->fetchrow_hashref() )
    {
	push( @Dates, WebEve::cEvent->newForEventList( $hrefData ) );
    }
    
    $self->{'DateList'} = \@Dates;

    return scalar(@Dates);
}

sub getDateList
{
    my $self = shift;
    
    return @{$self->{'DateList'}};
}

sub getPageCount
{
    my $self = shift;

    return $self->{'Pages'};
}

1;
