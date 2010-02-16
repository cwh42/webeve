# $Id$
# ===============================================================================
# The Class 'cOrg'
# ===============================================================================

package WebEve::cOrg;

use strict;
use base qw(WebEve::cBase);
#use WebEve::cMySQL;
use overload '""' => "getName";

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

sub getName
{
    my $self = shift;
    return $self->{OrgName};
}

sub getEMail
{
    my $self = shift;
    return $self->{eMail};
}

sub getWebsite
{
    my $self = shift;
    return $self->{Website};
}

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

sub getPref
{
    my $self = shift;
    my $PrefType = shift;

    my $OrgID = $self->{OrgID};

    my $sql = sprintf("SELECT PrefValue FROM OrgPrefs ".
		      "WHERE OrgID = %d AND PrefType = %s",
		      $OrgID,
		      $self->getDBH()->quote($PrefType));

    my $sth = $self->getDBH()->prepare($sql);
    $sth->execute();

    my @result = ();

    while( my $row = $sth->fetchrow_arrayref() )
    {
	push( @result, $row->[0] );
    }

    return wantarray ? @result : $result[0];
}

sub setPref
{
    my $self = shift;
    my $PrefType = shift;
    my @NewValues = @_;
    my $OrgID = $self->{OrgID};

    my $PrefTypeQuoted = $self->getDBH()->quote($PrefType);

    @NewValues = grep {$_ ne ''} @NewValues;
    my @OldValues = $self->getOrgPref($OrgID, $PrefType);

    my ($ToAddRef, $ToDeleteRef) = array_diff(\@NewValues, \@OldValues, 1);

    my @ToAdd = @$ToAddRef;
    my @ToDelete = @$ToDeleteRef;

    #print STDERR "ALL:".join(',', @OldValues)."\n";
    #print STDERR "SEL:".join(',', @NewValues)."\n";

    #print STDERR "ADD:".join(',', @ToAdd)."\n";
    #print STDERR "DEL:".join(',', @ToDelete)."\n";

    if(@ToAdd)
    {
	my $sql = "INSERT INTO OrgPrefs (OrgID, PrefType, PrefValue) VALUES ";
	$sql .=  join( ', ', map { "($OrgID, $PrefTypeQuoted, ".$self->getDBH()->quote($_).")" } @ToAdd );

	print STDERR "$sql\n" if $self->param('debug');

	$self->getDBH()->do($sql);
    }

    if(@ToDelete)
    {
	my $sql = "DELETE FROM OrgPrefs WHERE OrgID = $OrgID  AND PrefType = $PrefTypeQuoted AND (";
	$sql .=  join( ' OR ', map { "PrefValue = ".$self->getDBH()->quote($_) } @ToDelete );
	$sql .= ")";

	$self->getDBH()->do($sql);
    }

    return 1;
}

1;
