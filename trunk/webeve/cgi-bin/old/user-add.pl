#!/usr/bin/perl

#########################################################################
# user-add.pl - v0.9                                       19. Apr 2002 #
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
my $SubTmpl = HTML::Template->new(filename => "$BasePath/user-add.tmpl");
$MainTmpl->param( 'TITLE' => 'Neuer Benutzer' );

# -----------------------------------------------------------------------

my @UserData = CheckLogin();

if($UserData[3] == 0)
{
        print "Location: $BaseURL/edit-list.pl\n";
        print "Content-type: text/html\n\n";
        print "empty";
	exit(0);
}

my $Action = $query->param('Action') || '';

my $LoginName = $query->param('Login') || '';
my $FullName = $query->param('FullName') || '';
my $eMail = $query->param('eMail') || '';
my $Password = 'default';
my @Orgs =  $query->param('Orgs');

if(@UserData > 0)
{
    if($Action eq 'Save')
    {
	my @Message = CheckValues();

	if( @Message == 0 )
	{
	    DoSQL("INSERT INTO User (FullName, eMail, UserName, Password)
                   VALUES('$FullName', '$eMail', '$LoginName' , password('$Password'))");

	    my $sth = SendSQL("SELECT last_insert_id() FROM User LIMIT 1");
	    my $UserID = FetchOneColumn($sth);

	    if(@Orgs)
	    {
		my $sql = "INSERT INTO Org_User (OrgID, UserID) VALUES ";
		$sql .=  join( ', ', map { "($_, $UserID)" } @Orgs );

		DoSQL($sql);
	    }

	    $SubTmpl->param('Message' => "<font color=\"#008000\">Neuer Benutzer '$LoginName' angelegt.</font>");
	    logger( "Created new user: '$LoginName' ($FullName); Orgs: ".join( ', ', @Orgs ) );
	    @Orgs = ();
	}
	else
	{
	    $SubTmpl->param('Login' => $query->param('Login'));
	    $SubTmpl->param('FullName' => $query->param('FullName'));
	    $SubTmpl->param('eMail' => $query->param('eMail'));

	    my $Message = join(', ', @Message);
	    $SubTmpl->param('Message' => "<font color=\"#ff0000\">Fehler in $Message</font>");
	}
    }

    my %AllOrgs = getAllOrgs();
    my @LoopData = ();

    foreach my $OrgID ( keys( %AllOrgs ) )
    {
	my $selected;

	foreach(@Orgs)
	{
	    $selected = 'checked' if($_ == $OrgID);
	}

	push( @LoopData, { 'OrgID' => $OrgID,
			   'OrgName' => $AllOrgs{$OrgID}->[0],
			   'Selected' => $selected});
    }

    $SubTmpl->param('Orgs' => \@LoopData);

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

    $LoginName = trim($LoginName);

    if($LoginName eq '')
    {
	push(@EmptyFields, 'Login-Name');
    }
    else
    {
	my $sth = SendSQL("SELECT COUNT(UserID)
                               FROM User
                               WHERE UserName = '$LoginName'");

	push(@EmptyFields, 'Login-Name: Benutzer existiert bereits') if( FetchOneColumn($sth) > 0 );
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
