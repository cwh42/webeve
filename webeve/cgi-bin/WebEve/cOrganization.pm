# $Id$
# ===============================================================================
# The Class 'cOrganization'
# ===============================================================================

package WebEve::cOrganization;

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
    $self->_init(@_);

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
               WHERE o.OrgID = $OrgID";

    my $dbh = WebEve::cMySQL->connect('default');

    my $hrefData = $dbh->selectrow_hashref($sql);

    foreach(keys(%$hrefData))
    {
	$self->{$_} = $hrefData->{$_};
    }
}

# --------------------------------------------------------------------------------
# Public Methods
# --------------------------------------------------------------------------------
# Checking Methods
# --------------------------------------------------------------------------------


# --------------------------------------------------------------------------------
# Getting data
# --------------------------------------------------------------------------------


1;
