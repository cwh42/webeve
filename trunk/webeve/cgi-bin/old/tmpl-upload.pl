#!/usr/bin/perl

#########################################################################
# tmpl-upload.pl - v0.9                             Created: 2002-04-30 #
# (c)2000-2002 C.Hofmann - tr1138@bnbt.de      Last Updated: 2002-11-26 #
#########################################################################

use strict;
use HTML::Template;
use POSIX qw(strftime);
use WebEve::mysql;
use WebEve::termine;
use WebEve::Config;
use CGI;

main();

sub SaveFile($$)
{
    my ($TmplKind, $query) = @_;
    my $Filename = $query->param($TmplKind);
    if( $Filename )
    {
	my $OrgID = $query->param('OrgID') || '';
	my $fh = $query->upload($TmplKind);

	my $FullName = sprintf("$BasePath/custom/template-%02d-%s.tmpl", $OrgID, $TmplKind);

	if( -f $FullName )
	{
	    my $Date = strftime("%Y-%m-%d--%H-%M-%S", localtime);
	    rename($FullName, "$FullName-$Date"); 
	}

	my $Status = open(OUT, ">$FullName");

	if( $Status )
	{
	    while(<$fh>)
	    {
		print OUT;
	    }

	    close(OUT);
	}

	return $Status;
    }
    else
    {
	return -1;
    }
}


sub main
{
    my $query = new CGI;
    my $MainTmpl = HTML::Template->new(filename => "$BasePath/main.tmpl");
    my $SubTmpl = HTML::Template->new(filename => "$BasePath/tmpl-upload.tmpl");
    $MainTmpl->param( 'TITLE' => 'Template upload' );

    # -----------------------------------------------------------------------

    my $Action = $query->param('Action') || '';

    my @UserData = CheckLogin();

    if(@UserData > 0)
    {
	$SubTmpl->param('Orgs' => getOrgList($UserData[0]));

	if( $Action eq 'Speichern' )
	{
	    my $IsValid = 0;
	    my $OrgID = $query->param('OrgID') || '';
	    my @UsersOrgs = getOrgListArray( $UserData[0] );

	    foreach my $ID ( @UsersOrgs )
	    {
		$IsValid = 1 if $ID = $OrgID;
	    }

	    if( $IsValid )
	    {
		my $Result1 = SaveFile( 'simple', $query );
#		my $Result2 = SaveFile( 'advanced', $query );

		if( $Result1 == 1 )
		{
		    $SubTmpl->param('SimpleSaved' => 1);
		    logger("Uploaded simple template for Org $OrgID");
		}
		else
		{
		    $SubTmpl->param('SimpleError' => 1);
		    logger("ERROR: Could not save simple template for Org $OrgID");
		}

#		if( $Result2 == 1 )
#		{
#		    $SubTmpl->param('AdvancedSaved' => 1);
#		    logger("Uploaded advanced template for Org $OrgID");
#		}
#		else
#		{
#		    $SubTmpl->param('AdvancedError' => 1);
#		    logger("ERROR: Could not save advanced template for Org $OrgID");
#		}
	    }
	    else
	    {
		$SubTmpl->param('OtherError' => 'Für diesen Verein darfst Du kein Template heraufladen.');
		logger("ATTENTION: not allowed to upload template for Org $OrgID");
	    }


	}

	$MainTmpl->param('NavMenu' => getNavMenu( $UserData[3] ) ) ;
	$MainTmpl->param('CONTENT' => $SubTmpl->output());

	print "Content-type: text/html\n\n";
	print $MainTmpl->output();
    }
    else
    {
	print "Location: $BaseURL/login.pl\n";
	print "Content-type: text/html\n\n";
	print "empty";
    }
}
