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
    my $Org = $query->param('org') || '0';
    my $Format = $query->param('format') || 'html';

    my $TmplFile = $Format eq 'js' ? "js" : "html";

    my $MainTmpl = HTML::Template->new(filename => "$TemplatePath/kalender-plugin-$TmplFile.tmpl",
				       die_on_bad_params => 0);

    my $Today = WebEve::cDate->new('today');

    my %params;

    if( $Org )
    {
	$params{ 'PublicOnly' } = 0;
	$params{ 'ForOrgID' } = $query->param('org');
    }
    else
    {
	$params{ 'PublicOnly' } = 1;
    }

    my $EventList = WebEve::cEventList->new( %params );
    $EventList->readData();

    my @TodayDates = ();

    foreach my $DateObj ( $EventList->getDateList() )
    {
 	if( $DateObj->getDate->isToday )
	{
	    my $OrgName = $DateObj->getOrg;
	    
	    my $HashRef = { 'Desc' => $DateObj->getDesc };
	    $HashRef->{ 'Org' } = $OrgName unless( $Org );

	    $HashRef->{'Org'} =~ s/\"/&quot;/g;
	    $HashRef->{'Desc'} =~ s/\"/&quot;/g;
	    
	    push( @TodayDates, $HashRef );
	}
    }

    $MainTmpl->param('Events' => \@TodayDates );    
    $MainTmpl->param('Date' => $Today->getDateStr);    

    print $query->header();
    print $MainTmpl->output;
}
