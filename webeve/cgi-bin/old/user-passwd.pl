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


my $query = new CGI;
my $MainTmpl = HTML::Template->new(filename => "$BasePath/main.tmpl");
my $SubTmpl = HTML::Template->new(filename => "$BasePath/user-passwd.tmpl");
$MainTmpl->param( 'TITLE' => 'Passwort ändern' );

# -----------------------------------------------------------------------

my $Action = $query->param('Action') || '';
my $OldPass = $query->param('OldPass') || '';
my $NewPass1 = $query->param('NewPass1') || '';
my $NewPass2 = $query->param('NewPass2') || '';


my @UserData = CheckLogin();

if(@UserData > 0)
{
    my $UserID = $UserData[0];

    if($Action eq 'Ändern')
    {
	my $Message;

	if($NewPass1 ne $NewPass2)
	{
	    $Message = "Neues Passwort stimmt nicht mit Passwortwiederholung überein!";
	    $Message = "<font color=\"#ff0000\">$Message</font>";
	}
	else
	{
	    my $sql = sprintf( "SELECT password(%s) = User.Password FROM User WHERE User.UserID = %d",
			       sqlQuote($OldPass),
			       $UserID );

	    my $Result = FetchOneColumn(SendSQL($sql));	    

	    if( $Result == 1 )
	    {
		$sql = sprintf("UPDATE User SET Password=password(%s)
                                WHERE password(%s) = User.Password
                                AND User.UserID = %d",
			       sqlQuote($NewPass1),
			       sqlQuote($OldPass),
			       $UserID );
	    
		DoSQL($sql);

		logger("Changed password");
		$Message = "Passwort wurde geändert!";
		$Message = "<font color=\"#008000\">$Message</font>";
	    }
	    else
	    {
		$Message = "Altes Passwort ist falsch!";
		$Message = "<font color=\"#ff0000\">$Message</font>";
	    }
	}

	$SubTmpl->param('Message' => $Message);
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
