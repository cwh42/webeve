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

        # Replace HTML linebreaks to spaces
        ( my $desc = $DateObj->getDesc ) =~ s/(\n|\r|<br>|<bt\/>)/ /g;

	# Remove all other HTML tags
        $desc =~ s/<[a-zA-Z0-9\/]+?>//g;

	# Make spaces unique
	$desc =~ s/\s{2,}/ /g;

        if( $csv->combine( $DateObj->getDate->getDateStr,
                           $DateObj->getTime,
                           $DateObj->getPlace,
                           $DateObj->getOrg,
                           $DateObj->getTitle,
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

