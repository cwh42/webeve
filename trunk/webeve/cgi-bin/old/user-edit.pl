#!/usr/bin/perl

#########################################################################
# user-edit.pl - v0.9                                      19. Apr 2002 #
# (c)2000-2002 C.Hofmann tr1138@bnbt.de                                 #
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
my $SubTmpl = HTML::Template->new(filename => "$BasePath/user-edit.tmpl");
$MainTmpl->param( 'TITLE' => 'Benutzer bearbeiten' );

# -----------------------------------------------------------------------

my $Action = $query->param('Action') || '';

my $UserID = $query->param('UserID') || '';
my $FullName = $query->param('FullName') || '';
my $eMail = $query->param('eMail') || '';
my $isAdmin = $query->param('isAdmin') || 0;
$isAdmin = 1 if $isAdmin ne 0;
my @Orgs =  $query->param('Orgs');

my @UserData = CheckLogin();

if($UserData[3] == 0)
{
        print "Location: $BaseURL/edit-list.pl\n";
        print "Content-type: text/html\n\n";
        print "empty";
	exit(0);
}

if(@UserData > 0)
{
    if($Action eq 'Save')
    {
	my @Message = CheckValues();

	if( @Message == 0 )
	{
	    my $FullNameSQL = sqlQuote($FullName);
	    my $eMailSQL = sqlQuote($eMail);

	    my $sth = SendSQL("UPDATE User
                               SET FullName = $FullNameSQL,
                               eMail = $eMailSQL,
                               isAdmin = $isAdmin
                               WHERE UserID = $UserID");

	    my @UserOrgs = getOrgListArray($UserID);

	    my ($ToAddRef, $ToDeleteRef) = ArrayDiff(\@Orgs, \@UserOrgs);

	    my @ToAdd = @$ToAddRef;
	    my @ToDelete = @$ToDeleteRef;

	    #print STDERR "ALL:".join(',', @UserOrgs)."\n";
	    #print STDERR "SEL:".join(',', @Orgs)."\n";

	    #print STDERR "ADD:".join(',', @ToAdd)."\n";
	    #print STDERR "DEL:".join(',', @ToDelete)."\n";

	    if(@ToAdd)
	    {
		my $sql = "INSERT INTO Org_User (OrgID, UserID) VALUES ";
		$sql .=  join( ', ', map { "($_, $UserID)" } @ToAdd );

		DoSQL($sql);
	    }

	    if(@ToDelete)
	    {
		my $sql = "DELETE FROM Org_User where UserID = $UserID  AND (";
		$sql .=  join( ' OR ', map { "OrgID = $_" } @ToDelete );
		$sql .= ")";

		DoSQL($sql);
	    }

	    logger("Modified user ID: '$UserID'");

	    print "Location: $BaseURL/user-list.pl\n";
	    print "Content-type: text/html\n\n";
	    print "empty";
	}
	else
	{
	    $SubTmpl->param('UserID' => $query->param('UserID'));
	    $SubTmpl->param('Login' => $query->param('Login'));
	    $SubTmpl->param('FullName' => $query->param('FullName'));
	    $SubTmpl->param('eMail' => $query->param('eMail'));
	    $SubTmpl->param('isAdmin' => 'checked') if $query->param('isAdmin');

	    my %Orgs = getAllOrgs();
	    my @LoopData = ();

	    foreach my $OrgID ( keys( %Orgs ) )
	    {
		my $selected;

		foreach(@Orgs)
		{
		    $selected = 'checked' if($_ == $OrgID);
		}

		push( @LoopData, { 'OrgID' => $OrgID,
				   'OrgName' => $Orgs{$OrgID}->[0],
				   'Selected' => $selected});
	    }

	    $SubTmpl->param('Orgs' => \@LoopData);

	    my $Message = join(', ', @Message);
	    $SubTmpl->param('Message' => "<font color=\"#ff0000\">Fehler in $Message</font>");
	}
    }
    else
    {
	my $sth = SendSQL("SELECT u.FullName, u.UserName, u.eMail, u.isAdmin, u.LastLogin
                               FROM User u
                               WHERE u.UserID = $UserID");

	my ($FullName, $LoginName, $eMail, $isAdmin, $LastLogin) = FetchSQLData($sth);

	$SubTmpl->param('UserID' => $UserID);
	$SubTmpl->param('Login' => $LoginName);
	$SubTmpl->param('FullName' => $FullName);
	$SubTmpl->param('eMail' => $eMail);
	$SubTmpl->param('LastLogin' => $LastLogin);
	$SubTmpl->param('isAdmin' => 'checked') if $isAdmin;

	my %Orgs = getAllOrgs();
	my @UsersOrgs = getOrgListArray($UserID);

	my @LoopData = ();

	foreach my $OrgID ( keys( %Orgs ) )
	{
	    my $selected;

	    foreach(@UsersOrgs)
	    {
		$selected = 'checked' if($_ == $OrgID);
	    }

	    push( @LoopData, { 'OrgID' => $OrgID,
			       'OrgName' => $Orgs{$OrgID}->[0],
			       'Selected' => $selected});
	}

	$SubTmpl->param('Orgs' => \@LoopData);
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


sub CheckValues
{
        my @EmptyFields;

        if(@Orgs == 0)
        {
                push(@EmptyFields, 'Vereine');
        }

        if($UserID eq '')
        {
                push(@EmptyFields, 'UserID');
        }

        if($FullName eq '')
        {
                push(@EmptyFields, 'Voller Name');
        }

        if($eMail eq '')
        {
                push(@EmptyFields, 'eMail');
        }

        return @EmptyFields;
}

sub trim($)
{
    my ($string) = @_;

    $string =~ s/^\s+//s;
    $string =~ s/\s+$//s;

    return $string;
}

