#!/usr/bin/perl

#########################################################################
# edit-list.pl - v0.9                                      19. Apr 2002 #
# (c)1999-2002 C.Hofmann tr1138@bnbt.de                                 #
#########################################################################

use strict;
use HTML::Template;
use Date::Calc qw( Today Delta_Days Days_in_Month );
use CGI;
use WebEve::mysql;
use WebEve::termine;
use WebEve::Config;

# Settings

my $MainTmpl = HTML::Template->new(filename => "$BasePath/main.tmpl", die_on_bad_params => 0);
my $SubTmpl = HTML::Template->new(filename => "$BasePath/edit-list.tmpl", die_on_bad_params => 0);
$MainTmpl->param( 'TITLE' => 'Übersicht' );

# -----------------------------------------------------------------------

my @UserData = CheckLogin();

if(@UserData > 0)
{
    my %Orgs = getAllOrgs();
    my @Termine;
    my @LoopData;

    my @UserOrgIDs = getUserOrgIDs($UserData[0]);

    my %Dates = getDates( 'BeforeToday' => 1,
			  'ForOrgID' => \@UserOrgIDs );

    foreach my $DateObj ( @{$Dates{'Dates'}} )
    {
	push(@LoopData, { 'Date' => $DateObj->getDate,
			  'Time' => $DateObj->getTime,
			  'Place' => $DateObj->getPlace,
			  'Desc' => $DateObj->getDesc,
			  'EntryID' => $DateObj->getID,
			  'Org' => $Orgs{ $DateObj->getOrgID }->[0],
			  'Public' => $DateObj->isPublic,
			  'IsOver' => $DateObj->isOver } );
    }

    $SubTmpl->param('FullName' => $UserData[1]);
    $SubTmpl->param('User' => $UserData[5]);
    $SubTmpl->param('Admin' => $UserData[3]);
    $SubTmpl->param('Orgs' => getOrgList($UserData[0]));
    $SubTmpl->param('List' => \@LoopData);

    $MainTmpl->param('NavMenu' => getNavMenu( $UserData[3] ) ) ;
    $MainTmpl->param('CONTENT' => $SubTmpl->output());

    print "Content-type: text/html\n\n";
    print $MainTmpl->output;
}
else
{
        print "Location: $BaseURL/login.pl\n";
        print "Content-type: text/html\n\n";
        print "empty";
}
