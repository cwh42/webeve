#!/usr/bin/perl

#########################################################################
# $Id$
# (c)2003 C.Hofmann tr1138@bnbt.de                                     
#########################################################################

use strict;
use CGI;
use HTML::Template;
use WebEve::Config;
use WebEve::cEventList;
use WebEve::cMySQL;

main();

sub main
{
    my $query = new CGI;

    my $MainTmpl = HTML::Template->new(filename => "$TemplatePath/kalender-plugin.tmpl",
				       die_on_bad_params => 0);

    my $Today = WebEve::cDate->new('today');
    my $EventList = WebEve::cEventList->new( PublicOnly => 1 );
    $EventList->readData();

    my @TodayDates = ();

    foreach my $DateObj ( $EventList->getDateList() )
    {
 	if( $DateObj->getDate->isToday )
	{
	    my $OrgName = $DateObj->getOrg;
	    
	    my $HashRef = { 'Desc' => $DateObj->getDesc,
			    'Org' => $OrgName };
	    
	    push( @TodayDates, $HashRef );
	}
    }

    $MainTmpl->param('Events' => \@TodayDates );    
    $MainTmpl->param('Date' => $Today->getDateStr);    

    print $query->header();
    print $MainTmpl->output;
}
