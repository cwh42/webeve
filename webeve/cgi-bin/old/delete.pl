#!/usr/bin/perl
#/usr/bin/perl5.00503

#########################################################################
# edit.pl - v0.1                                           17. Jan 2001 #
# (c)2000-2001 C.Hofmann tr1138@bnbt.de                                 #
#########################################################################

use strict;
use HTML::Template;
use WebEve::mysql;
use WebEve::termine;
use WebEve::Config;
use CGI;

# Settings

my $query = new CGI;
my $MainTmpl = HTML::Template->new(filename => "$BasePath/main.tmpl");
my $SubTmpl = HTML::Template->new(filename => "$BasePath/delete.tmpl");
$MainTmpl->param( 'TITLE' => 'Termine löschen' );

# -----------------------------------------------------------------------

my @EntryIDs = $query->param('EntryID');
my $Action = $query->param('Action') || '';

my @UserData = CheckLogin();

if(@UserData > 0)
{
    unless( @EntryIDs )
    {
	print "Location: $BaseURL/edit-list.pl\n";
	print "Content-type: text/html\n\n";
	print "empty";
	exit;
    }
    
    my $Where = '';
    $Where = 'EntryID = '.join( ' OR EntryID = ', @EntryIDs );

    if($Action eq 'Delete' )
    {
	DoSQL("DELETE FROM Dates WHERE $Where");

	logger("Deleted date: ".join( ', ', @EntryIDs));

	print "Location: $BaseURL/edit-list.pl\n";
	print "Content-type: text/html\n\n";
	print "empty";
	exit;
    }
    else
    {
	my %Orgs = getAllOrgs();	
	my @UserOrgIDs = getUserOrgIDs($UserData[0]);

	my %Dates = getDates( 'BeforeToday' => 1,
			      'ForOrgID' => \@UserOrgIDs,
			      'ID' => \@EntryIDs );

	my @LoopData = ();
	@EntryIDs = ();

	foreach my $DateObj ( @{$Dates{'Dates'}} )
	{
	    push(@LoopData, { 'Date' => $DateObj->getDate,
			      'Time' => $DateObj->getTime,
			      'Place' => $DateObj->getPlace,
			      'Desc' => $DateObj->getDesc,
			      'Org' => $Orgs{ $DateObj->getOrgID }->[0] } );

	    push(@EntryIDs, $DateObj->getID );
	}

	$SubTmpl->param('List' => \@LoopData);
	my $QueryString = '';
	$QueryString = '&EntryID='.join( '&EntryID=', @EntryIDs ) if @EntryIDs;
	$SubTmpl->param('EntryIDs' => $QueryString);
	$MainTmpl->param('NavMenu' => getNavMenu( $UserData[3] ) ) ;
	$MainTmpl->param('CONTENT' => $SubTmpl->output());

	print "Content-type: text/html\n\n";
	print $MainTmpl->output();
    }
}
else
{
    print "Location: $BaseURL/login.pl\n";
    print "Content-type: text/html\n\n";
    print "empty";
}
