#!/usr/bin/perl -w

use WebEve::cMySQL;

$db = WebEve::cMySQL->connect_cached();

$aRef = $db->selectall_arrayref('SELECT * FROM User', { Slice => {} });

foreach( @{$aRef} )
{
    print $_->{UserName}."\t";
    print $_->{FullName}."\t";
    print $_->{eMail}."\n";
}

$db->disconnect;

