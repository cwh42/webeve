#!/usr/bin/perl

#########################################################################
# user-list.pl - v0.9                                      19. Apr 2002 #
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
my $SubTmpl = HTML::Template->new(filename => "$BasePath/user-list.tmpl");
$MainTmpl->param( 'TITLE' => 'Benutzer' );

# -----------------------------------------------------------------------

my $Action = $query->param('Action') || '';

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
    # Fill Userlist
    my @UserLoopData = ();
    my %UserList = getUserList();

    foreach my $User ( sort { $a cmp $b } keys(%UserList) )
    {
	my $Admin = '';
	$Admin = '<font color="#ff0000"><b>@</b></font>' if( $UserList{$User}->[3] );

	push( @UserLoopData, { 'UserName' => $Admin.$User,
			   'UserID' => $UserList{$User}->[0],
			   'FullName' => $UserList{$User}->[1],
			   'eMail' => $UserList{$User}->[2],
			   'LastLogin' => $UserList{$User}->[4] } );
    }

    $SubTmpl->param( 'Users' => \@UserLoopData );

    # Fill Org-List
    my @OrgLoopData = ();
    my %OrgList = getAllOrgs();

    foreach my $OrgID ( sort { $OrgList{$a}->[0] cmp $OrgList{$b}->[0] } keys(%OrgList) )
    {
	push( @OrgLoopData, { 'OrgName' => $OrgList{$OrgID}->[0],
			      'OrgID' => $OrgID,
			      'eMail' => $OrgList{$OrgID}->[1],
			      'Website' => $OrgList{$OrgID}->[2] } );
    }

    $SubTmpl->param( 'Orgs' => \@OrgLoopData );

    # Output
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
