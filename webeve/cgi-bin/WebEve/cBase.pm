
package WebEve::cBase;

use strict;
use vars qw( $LogFileHandle );
use CGI;
use FileHandle;
use Date::Calc qw( Today_and_Now );
use WebEve::Config;

#-----------------------------------------------------------------------

sub BEGIN
{
    $LogFileHandle = new FileHandle ">>$LogFile";
    die("Could not open Logfile <$LogFile>") unless defined( $LogFileHandle );
}

#-----------------------------------------------------------------------

sub END
{
    $LogFileHandle->close if defined( $LogFileHandle );
}

#-----------------------------------------------------------------------

sub logger($)
{
    my $self = shift;
    my ($message) = @_;
    my $UserName = $self->getUser()->{UserName} || $ENV{'REMOTE_HOST'} || $ENV{'REMOTE_ADDR'};

    printf( $LogFileHandle "%4d-%02d-%02d %02d:%02d:%02d %s: %s\n",
	    Today_and_Now(), $UserName, $message );
}

#-----------------------------------------------------------------------

sub getDBH
{
    my $self = shift;

    unless( defined($self->{dbh}) )
    {
	$self->{dbh} = WebEve::cMySQL->connect('default');
    }
    
    return $self->{dbh};
}

#-----------------------------------------------------------------------

sub CheckLogin()
{
    my $self = shift;
    
    if( defined( $self->getUser()->{UserID} ) )
    {
	return 1;
    }
    else
    {
	return 0;
    }
}

#-----------------------------------------------------------------------

sub getUser
{
    my $self = shift;

    unless( defined( $self->{USER_DATA} ) )
    {
	my $query = new CGI;
	my $SessionID = $self->getDBH()->quote($query->cookie('sessionID')||'');
    
	my $sql = "SELECT u.UserID, u.FullName, u.eMail, u.isAdmin, u.LastLogin, u.UserName ".
	    "FROM Logins l LEFT JOIN User u ON u.UserID = l.UserID ".
	    "WHERE SessionID = $SessionID ".
	    "AND Expires > now()";

	$self->{USER_DATA} =  $self->getDBH()->selectrow_hashref($sql);
    }

    $self->{USER_DATA} = {} unless( defined( $self->{USER_DATA} ) );

    return $self->{USER_DATA};
}

#-----------------------------------------------------------------------

sub getConfig
{
    my $self = shift;

    my $Param = shift;

    if( $Param eq 'BasePath' )
    {
	return $BasePath;
    }
    elsif( $Param eq 'TemplatePath' )
    {
	return $TemplatePath;
    }
    elsif( $Param eq 'LogFile' )
    {
	return $LogFile;
    }
    elsif( $Param eq 'LogPath' )
    {
	return $LogPath;
    }
    elsif( $Param eq 'DB' )
    {
	return \%DB;
    }
}

#-----------------------------------------------------------------------

sub _trim($)
{
    my $self = shift;
    my ($string) = @_;

    $string =~ s/^\s+//s;
    $string =~ s/\s+$//s;

    return $string;
}

#-----------------------------------------------------------------------
# sub ArrayDiff($$)
# ----------------------------------------------------------------------
# compares 2 arrays and reports the differences
# expects 2 array-references as parameters for array A and array B
# If the optional 3rd parameter is TRUE the arrays are sorted as strings
# returns 2 array-references:
#    the first contains all elements only found in A
#    the second contains all elements only found in B
#-----------------------------------------------------------------------

sub _ArrayDiff($$;$)
{
    my $self = shift;
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
	if(!defined($A[$ai]))	# A has less elements than B
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

#-----------------------------------------------------------------------

1;
