# $Id$
# ===============================================================================
# The Class 'cOrg'
# ===============================================================================

package WebEve::cOrg;

use strict;
use WebEve::cMySQL;

# --------------------------------------------------------------------------------
# The Constructor
# --------------------------------------------------------------------------------

sub new
{
    my $class = shift;

    die "Constructor has to be used as instance method!" if ref($class);

    my $self = {};

    bless( $self, $class );

    # Initialize variables
    my %Params = @_;
    my @Keys = keys( %Params );

    if( scalar(@Keys) == 1 && exists($Params{OrgID}))
    {
	$self->_getFromDB($Params{OrgID});
    }
    else
    {
	die('INSUFFICIENT PARAMETERS!');
#	$self->_init(@_);
    }

    return $self;
}

# --------------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------------

sub _getFromDB
{
    my $self = shift;
    my $OrgID = shift;

    my $sql = "SELECT o.OrgID, o.OrgName, o.eMail, o.Website
               FROM Organization o
               WHERE o.OrgID = $OrgID LIMIT 1";

    $self->{dbh} = WebEve::cMySQL->connect('default');

    my $hrefData = $self->{dbh}->selectrow_hashref($sql);

    foreach(keys(%$hrefData))
    {
	$self->{$_} = $hrefData->{$_};
    }
}

# --------------------------------------------------------------------------------
# Public Methods
# --------------------------------------------------------------------------------


sub getUsers
{
    my $self = shift;

    my @SelUserID = @_;
    my $OrgID = $self->{OrgID};

    my $sql = "SELECT u.UserID, u.FullName, u.UserName ".
	"FROM Org_User ou LEFT JOIN User u ON ou.UserID = u.UserID ".
	"WHERE ou.OrgID = $OrgID ".
	"ORDER BY u.UserName";

    my @Data = ();

    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    while( my $row = $sth->fetchrow_hashref() )
    {
	$row->{'selected'} = 1 if grep { $_ == $row->{UserID}} (@SelUserID);
	push( @Data, $row);
    }

    return \@Data;
}


1;
