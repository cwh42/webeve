# ===============================================================================
# The Class 'cEventList'
# ===============================================================================

package WebEve::cEventList;

use strict;
use vars qw( );
use WebEve::cEvent;
use WebEve::cMySQL;

$Count = 0;

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
#
# Returns a hash:
# Pages - the number of pages when getting dates with PerPage entries
# Dates - a reference to the array with all the dates

sub _init
{
    my $class = shift;

    my %Params = @_;

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
		$self->{$_} = $Params{'$_'};
	    }
	    else
	    {
		$self->{$_} = [ $Params{'$_'} ];
	    }
	}
    }

    # ------------------------------------------
 
    $self->{PerPage} = $Params{'PerPage'} || '0';
    $self->{Page} = $Params{'Page'} || '1';
}


sub readData
{
    my $class = shift;

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
	my $tmp = join( ' OR ', map { "OrgID = $_" } @{$self->{ForOrgID}} );
	
	push( @where, "( $tmp )" ) unless( $self->{ForOrgID}->[0] == 0 && @{$self->{ForOrgID}} == 1);
    }

    if( $self->{'ID'} )
    {
	my $tmp = join( ' OR ', map { "EntryID = $_" } @{$self->{ID}} );

	push( @where, "( $tmp )" ) unless( scalar(@{$self->{ID}}) == 0 );
    }

    # ------------------------------------------------------------------------

    $where = 'WHERE '.join( ' AND ', @where ) if @where;

    # ------------------------------------------------------------------------

#
#
#
    my $sth = SendSQL( "select count(*) from Dates $where;" );
    my $Count = FetchOneColumn($sth);
#
#
#

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

    my $sql = "SELECT EntryID,
	              Date,
	              Time,
                      Place,
	              Description,
	              UserID,
	              OrgID,
	              Public,
	              LastChange
	       FROM Dates
	       $where
	       ORDER by Dates.Date, Dates.Time
               $limit";

#    print STDERR $sql."\n";

    my $dbh = WebEve::cMySQL->connect('default');

    my @Dates;
    
    while( my $hrefData = $dbh->selectrow_hashref($sql) )
    {
	push( @Dates, WebEve::cEvent->new( %{$hrefData} ) )
    }
    
    $self->{'DateList'} = \@Dates;

    return WebEve::cEvent->Count;
}