#########################################################################
# termine.pm - v0.9                                        19. Apr 2002 #
# (c)2000-2002 C.Hofmann tr1138@bnbt.de                                 #
#########################################################################

package WebEve::termine;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
use Exporter;
use Socket;
use File::Basename;
use Date::Calc qw( Today_and_Now );
use POSIX qw( ceil );
use WebEve::mysql;
use WebEve::Config;
use WebEve::cEvent;
use CGI::Carp qw(fatalsToBrowser set_message);

set_message('<hr><b>Hierbei handelt es sich um einen Programmfehler.<br>'.
	    'Bitte schicke die Meldung oberhalb der Linie an <a href="mailto:ch@goessenreuth.de">'.
	    'ch@goessenreuth.de</a>, damit ich den Fehler beheben kann.</b>');

$CGI::POST_MAX=1024 * 100;  # max 100K posts

@ISA     = qw(Exporter);
@EXPORT  = qw(CheckUser
	      CheckLogin
	      logger
	      getDates
	      getOrgName
	      getNavMenu
	      getOrgList
	      getAllOrgs
	      getUserOrgIDs
	      getUserList
	      getOrgListArray
              getUserListArray
              ArrayDiff);

@EXPORT_OK = qw();


sub CheckUser($$)
{
    my $User_sql = sqlQuote($_[0]);
    my $Password_sql = sqlQuote($_[1]);

    my $sth = SendSQL("SELECT UserID, FullName, eMail, isAdmin, LastLogin, UserName
                           FROM User
                           WHERE UserName = $User_sql
                           AND Password = password($Password_sql)");

    return FetchSQLData($sth);
}

sub CheckLogin()
{
    my $query = new CGI;
    my $SessionID = $query->cookie('sessionID');

    my $sth = SendSQL("SELECT u.UserID, u.FullName, u.eMail, u.isAdmin, u.LastLogin, u.UserName
                           FROM Logins l, User u
                           WHERE u.UserID = l.UserID
                           AND SessionID = '$SessionID'
                           AND Expires > now()");

    return FetchSQLData($sth);
}

sub _NavMenuCleanup($@);

sub _NavMenuCleanup($@)
{
    my ( $IsAdmin, @Entries ) = @_;
    my @Result = ();

    my $FileName = basename( $0 );    

    foreach my $Entry (@Entries)
    {
	my $Admin = delete( $Entry->{'Admin'} );

	if( !( $Admin ) || $IsAdmin )
	{
	    if( exists( $Entry->{'SubLevel'} ) ) 
	    {
		my @tmp = _NavMenuCleanup( $IsAdmin, @{$Entry->{'SubLevel'}} );
		$Entry->{'SubLevel'} = \@tmp;
	    }

	    if( $Entry->{'FileName'} eq $FileName )
	    {
		$Entry->{'Current'} = 1;
	    }

	    push( @Result, $Entry );
	}
    }

    return @Result;
}


sub getNavMenu(;$)
{
    my ($IsAdmin) = @_;

    my @Entries = ( { 'Admin' => 0, 'Title' => 'Login', 'FileName' => 'login.pl' },
		    { 'Admin' => 0, 'Title' => 'Übersicht', 'FileName' => 'edit-list.pl',
		      'SubLevel' => [ { 'Admin' => 0, 'Title' => 'Neuer Termin', 'FileName' => 'add.pl' } ] },
		    { 'Admin' => 0, 'Title' => 'Passwort', 'FileName' => 'user-passwd.pl' },
		    { 'Admin' => 0, 'Title' => 'Templates', 'FileName' => 'tmpl-upload.pl' },
		    { 'Admin' => 1, 'Title' => 'Benutzer', 'FileName' => 'user-list.pl',
		      'SubLevel' => [ { 'Admin' => 1, 'Title' => 'Neuer Benutzer', 'FileName' => 'user-add.pl' },
				      { 'Admin' => 1, 'Title' => 'Neuer Verein', 'FileName' => 'org-add.pl' } ] },
		    { 'Admin' => 0, 'Title' => 'Logout', 'FileName' => 'login.pl?LogOut=1' }
		    );

    my @tmp = _NavMenuCleanup( $IsAdmin, @Entries );
    return \@tmp;
}


sub checkPermission
{

    return 0;
}


#
# get a list of dates
# -------------------------------------------------------------------------
# Understands the following parameters:
# bool BeforeToday - also get dates in the past
# bool PublicOnly - get only public dates
# num | arrayref ForOrgID - get only dates for the specified OrgID(s)
# num | arrayref ID - get only dates with the specified EntryID(s)
# num PerPage - return at most num dates
# num Page - return the num'th block of dates
#
# Returns a hash:
# Pages - the number of pages when getting dates with PerPage entries
# Dates - a reference to the array with all the dates

sub getDates(%)
{
    my %Params = @_;
    my @Dates;

    my $where;
    my @where = ();

    push( @where, '( Date >= CURDATE() OR ( DAYOFMONTH(Date) = 0 AND YEAR(Date) >= YEAR(CURDATE()) AND MONTH(Date) >= MONTH(CURDATE()) ) )' ) unless exists( $Params{'BeforeToday'} );
    push( @where, 'Public = 1' ) if exists( $Params{'PublicOnly'} ) && $Params{'PublicOnly'} != 0;

    if( exists( $Params{'ForOrgID'} ) )
    {
	my @tmparr = ();

	if( ref( $Params{'ForOrgID'} ) eq 'ARRAY' )
	{
	    @tmparr = @{$Params{'ForOrgID'}};
	}
	else
	{
	    @tmparr = ( $Params{'ForOrgID'} );
	}

	my $tmp = join( ' OR ', map { "OrgID = $_" } @tmparr );
	
	push( @where, "( $tmp )" ) unless( $tmparr[0] == 0 && @tmparr == 1);
    }

    if( exists( $Params{'ID'} ) )
    {
	my @tmparr = ();

	if( ref( $Params{'ID'} ) eq 'ARRAY' )
	{
	    @tmparr = @{$Params{'ID'}};
	}
	else
	{
	    @tmparr = ( $Params{'ID'} );
	}

	my $tmp = join( ' OR ', map { "EntryID = $_" } @tmparr );
	
	push( @where, "( $tmp )" ) unless( scalar(@tmparr) == 0 );
    }

    $where = 'WHERE '.join( ' AND ', @where ) if @where;

    my $sth = SendSQL( "select count(*) from Dates $where;" );
    my $Count = FetchOneColumn($sth);

    my $Pages = 1;
    my $limit = '';

    if( exists( $Params{'PerPage'} ) )
    {
	my $Len = $Params{'PerPage'};
	my $Page = $Params{'Page'} || '1' ;
	$Page -= 1;
	$Page = 0 if $Page < 0;

	$Pages = ceil( $Count / $Len );
	$Page = $Pages - 1 if $Page >= $Pages;
	
	my $From = $Page * $Len;

	$limit = "LIMIT $From, $Len";
    }

    my $sql = "SELECT 'EntryID', EntryID,
	              'Date', Date,
	              'Time', Time,
                      'Place', Place,
	              'Description', Description,
	              'UserID', UserID,
	              'OrgID', OrgID,
	              'Public', Public,
	              'LastChange', LastChange
	       FROM Dates
	       $where
	       ORDER by Dates.Date, Dates.Time
               $limit";

#    print STDERR $sql."\n";

    $sth = SendSQL( $sql );

    while( my %Data = FetchSQLData($sth) )
    {
	push( @Dates, WebEve::cEvent->new( %Data ) )
    }

    return ( 'Pages' => $Pages, 'Dates' => \@Dates );
}


sub getOrgList($;$)
{
    my ($UserID, $SelOrgID) = @_;
    $SelOrgID = -1 unless defined $SelOrgID;

    my $sth = SendSQL("SELECT o.OrgID, o.OrgName
                       FROM Org_User ou, Organization o
                       WHERE ou.UserID = $UserID
                       AND ou.OrgID = o.OrgID
                       ORDER BY o.OrgName");

    my @Data = ();

    while(my ($OrgID, $OrgName) = FetchSQLData($sth))
    {
	my %tmpHash =  ('OrgID' => $OrgID, 'OrgName' => $OrgName);
	$tmpHash{'selected'} = 'selected' if $OrgID == $SelOrgID;

	push( @Data, \%tmpHash);
    }

    return \@Data;
}

sub getOrgListArray($)
{
    my ($UserID) = @_;

    my $sth = SendSQL("SELECT ou.OrgID
                       FROM Org_User ou
                       WHERE ou.UserID = $UserID");

    return FetchOneColumnList($sth)
}

sub getUserListArray($)
{
    my ($OrgID) = @_;

    my $sth = SendSQL("SELECT ou.UserID
                       FROM Org_User ou
                       WHERE ou.OrgID = $OrgID");

    return FetchOneColumnList($sth)
}

sub getOrgName($)
{
    my ( $OrgID ) = @_;

    my $sth = SendSQL("SELECT o.OrgName
                       FROM Organization o
                       WHERE o.OrgID = $OrgID");

    return FetchOneColumn( $sth );
}

sub getAllOrgs
{
    my $sth = SendSQL("SELECT o.OrgID, o.OrgName, o.eMail, o.Website
                       FROM Organization o");

    my %Orgs;

    while(my ($OrgID, $OrgName, $OrgMail, $OrgWebsite) = FetchSQLData($sth))
    {
	$Orgs{$OrgID} = [$OrgName, $OrgMail, $OrgWebsite];
    }

    return %Orgs;
}

sub getUserOrgIDs($)
{
    my ($UserID) = @_;

    my $sth = SendSQL("SELECT ou.OrgID FROM Org_User ou where ou.UserID = $UserID");

    return FetchOneColumnList($sth);
}

sub getUserList()
{
    my %Userlist;

    my $sth = SendSQL("SELECT u.UserID, u.FullName, u.UserName, u.eMail, u.isAdmin, u.LastLogin
                       FROM User u
                       ORDER BY u.UserName");

    while(my ($UserID, $FullName, $LoginName, $eMail, $isAdmin, $LastLogin) = FetchSQLData($sth))
    {
	$Userlist{$LoginName} = [$UserID, $FullName, $eMail, $isAdmin, $LastLogin];
    }

    return %Userlist;
}

sub logger($)
{
    my ($message) = @_;
    my $UserName = ( CheckLogin() )[5] || getRemoteHost();

    open( LOG, ">>$Logfile");

    printf( LOG "%4d-%02d-%02d %02d:%02d:%02d %s: %s\n", Today_and_Now(), $UserName, $message );

    close( LOG );
}

sub getRemoteHost()
{
    return $ENV{'REMOTE_HOST'} if defined( $ENV{'REMOTE_HOST'} );

    my $ip = inet_aton( $ENV{'REMOTE_ADDR'} );
    my ( $HostName ) = gethostbyaddr($ip, AF_INET);

    return $? ? $ENV{'REMOTE_ADDR'} : $HostName;
}


#########################################################################
# sub ArrayDiff($$)
# ----------------------------------------------------------------------
# compares 2 arrays and reports the differences
# expects 2 array-references as parameters for array A and array B
# If the optional 3rd parameter is TRUE the arrays are sorted as strings
# returns 2 array-references:
#    the first contains all elements only found in A
#    the second contains all elements only found in B
#########################################################################

sub ArrayDiff($$;$)
{
        my ($Aref, $Bref, $String) = @_;

        my @A;
        my @B;

        if($String)
        {
                # sort arrays as strings
                @A = sort { $a cmp $b } @$Aref;
                @B = sort { $a cmp $b } @$Bref;
        }
        else
        {
                # sort both arrays numeric ascending
                @A = sort { $a <=> $b } @$Aref;
                @B = sort { $a <=> $b } @$Bref;
        }

        my $ai = 0;
        my $bi = 0;

        my @Aonly;
        my @Bonly;

        while(defined($A[$ai]) || defined($B[$bi]))
        {
                if(!defined($A[$ai])) # A has less elements than B
                {
                        push(@Bonly, $B[$bi]);
                        $bi++;
                }
                elsif(!defined($B[$bi])) # B has less elements than A
                {
                        push(@Aonly, $A[$ai]);
                        $ai++;
                }
                else
                {
                        if($String)
                        {
                                if(($A[$ai] cmp $B[$bi]) == -1)
                                {
                                        push(@Aonly, $A[$ai]);
                                        $ai++;
                                }
                                elsif(($A[$ai] cmp $B[$bi]) == +1)
                                {
                                        push(@Bonly, $B[$bi]);
                                        $bi++;
                                }
                                else
                                {
                                        $ai++;
                                        $bi++;
                                }
                        }
                        else
                        {
                                if($A[$ai] < $B[$bi])
                                {
                                        push(@Aonly, $A[$ai]);
                                        $ai++;
                                }
                                elsif($A[$ai] > $B[$bi])
                                {
                                        push(@Bonly, $B[$bi]);
                                        $bi++;
                                }
                                else
                                {
                                        $ai++;
                                        $bi++;
                                }
                        }
                }
        }

        return \@Aonly, \@Bonly;
}

1;
