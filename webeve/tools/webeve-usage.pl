#!/usr/bin/perl -w

use strict;
use WebEve::cMySQL;

my $dbh = WebEve::cMySQL->connect('default');

my $sql = "SELECT OrgName, UserName, LastLogin, LoginCount ".
    "FROM Organization INNER JOIN Org_User USING(OrgID) ".
    "INNER JOIN User USING(UserID) ".
#    "WHERE UserName != 'cwh' ".
    "ORDER BY OrgName, LoginCount DESC;";

my $sth = $dbh->prepare($sql);
$sth->execute();

my %data = ();

while( my $row = $sth->fetchrow_hashref() )
{
    push( @{$data{ delete($row->{'OrgName'}) }}, $row );
}

my ( $maxlen ) = $dbh->selectrow_array( "SELECT max(length(UserName)) FROM User;" );

foreach my $Org ( keys( %data ) )
{
    print "$Org:\n";

    foreach my $User ( @{$data{$Org}} )
    {
	print "  - ";
	printf( "%-${maxlen}s, %19s, %3d\n",
		$User->{UserName},
		$User->{LastLogin} || '',
		$User->{LoginCount} );
    }
}
