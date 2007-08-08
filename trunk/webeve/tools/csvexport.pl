#!/usr/bin/perl -w

use strict;
use Text::CSV_XS;
use WebEve::Config;
use WebEve::cEventList;
use WebEve::cMySQL;

main();

sub main
{
    my $EventList = WebEve::cEventList->new( 'PublicOnly' => 1 );

    $EventList->readData();

    my $csv = Text::CSV_XS->new( { binary => 1 } );

    foreach my $DateObj ( $EventList->getDateList() )
    {
	my $OrgName = $DateObj->getOrg;
        
        ( my $desc = $DateObj->getDesc ) =~ s/(\n|\r|<br>|<bt\/>)/ /g;
        $desc =~ s/<[a-zA-Z0-9\/]+?>//g;

        if( $csv->combine( $DateObj->getDate->getDateStr,
                           $DateObj->getTime,
                           $DateObj->getPlace,
                           $DateObj->getOrg,
                           $desc ) )
        {
            print $csv->string()."\r\n";
        }
        else
        {
            print STDERR $csv->error_input()."\n";
        }
    }

}

