#!/usr/bin/perl

#########################################################################
# login.pl - v0.9                                        19. April 2002 #
# (c)2000-2002 C.Hofmann tr1138@bnbt.de                                 #
#########################################################################

use strict;
use HTML::Template;
use WebEve::mysql;
use WebEve::termine;
use WebEve::Config;
use CGI;

main();

sub MakeSessionID($)
{
        my $i;
        my $SID = crypt($_[0], 'SI');
        my @Chars = split(//, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890');

        for($i = 0; $i < 37; $i++)
        {
                $SID .= @Chars[rand(@Chars)];
        }

        return $SID;
}


sub LogOut($)
{
    my $SessionID = $_[0]->cookie('sessionID');
    DoSQL("DELETE FROM Logins WHERE SessionID = '$SessionID'");
}


sub main()
{
    # Settings

    my $query = new CGI;
    my $MainTmpl = HTML::Template->new(filename => "$BasePath/main.tmpl");
    my $SubTmpl = HTML::Template->new(filename => "$BasePath/login.tmpl");
    $MainTmpl->param( 'TITLE' => 'Login' );

    # -----------------------------------------------------------------------

    my $User = $query->param('User') || '';
    my $Password = $query->param('Password') || '';
    my $LogOut = $query->param('LogOut') || '';

    my @LoggedIn = CheckLogin();

    # This query removes expired loginmarks from database.
    # (User should be ticked off for not logging out properly!)
    DoSQL('DELETE FROM Logins WHERE Expires < now()');

    # User is logged in and wants to log out
    if( $LogOut && @LoggedIn )
    {
	LogOut( $query );
	print $query->redirect('kalender.pl');
   
	exit(0);
    }

    # User calls this page without any parameters
    if($User eq '' && $Password eq '')
    {
	if( @LoggedIn )
	{
	    $SubTmpl->param( 'User' => $LoggedIn[5] );
	    $MainTmpl->param('NavMenu' => getNavMenu( $LoggedIn[3] ) );
	}

	$MainTmpl->param('CONTENT' => $SubTmpl->output());
	
	print $query->header();
	print $MainTmpl->output();

	exit(0);
    }

    # User submits either a username or a password or both.
    if($User ne '' || $Password ne '')
    {
	my @UserData = CheckUser($User, $Password);

	if(@UserData > 0)
	{
	    LogOut( $query ) if @LoggedIn;

	    DoSQL("UPDATE User SET LastLogin = now() where UserID = $UserData[0]");

	    my $SessionID = MakeSessionID($User);

	    my $Cookie = $query->cookie(-name=>'sessionID',
					-value=>$SessionID,
					-expires=>'+8h');

	    DoSQL("INSERT INTO Logins (SessionID, UserID, Expires) VALUES('$SessionID', $UserData[0], ADDDATE(now(), INTERVAL 8 HOUR))");

	    logger("logged in as $User");

	    print $query->header(-cookie=>$Cookie,
				 -location=>"$BaseURL/edit-list.pl");
	    print "empty\n";
	}
	else
	{
	    logger("Login failed: '$User'");

	    $SubTmpl->param( 'WrongPasswd' => 1 );

	    $MainTmpl->param('CONTENT' => $SubTmpl->output());
	    $MainTmpl->param('NavMenu' => getNavMenu( $LoggedIn[3] ) ) if @LoggedIn;

	    print "Content-type: text/html\n\n";
	    print $MainTmpl->output();
	}
    }
}
