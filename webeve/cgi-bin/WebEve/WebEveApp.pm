package WebEve::WebEveApp;

use strict;

use base qw( WebEve::cBase CGI::Application );

use File::Basename;
use CGI::Carp;
use Socket;

# -------------------------------------------------------------------------
# The init-Method
#
sub cgiapp_init
{
    my $self = shift;

    # Prepare some stuff
    # --------------------------------
    $self->tmpl_path( $self->getConfig('TemplatePath') );

    my $MainTmpl = $self->param('MainTmpl');
    $self->{MainTmpl} = $self->load_tmpl( $MainTmpl ? $MainTmpl : 'main.tmpl' );    

    print STDERR $self->dump() if $self->param('debug');

    $self->{'Logfile'} = $self->param('Logfile') || $self->getConfig( 'LogFile' );

    $self->_getRemoteHost();

    if(exists $ENV{MOD_PERL})
    { 
	print STDERR "\n-----------------------------------------\n";
	print STDERR "-----------------------------------------\n";
	print STDERR " WARNING:\n";
	print STDERR " Running under ".$ENV{MOD_PERL}."!\n";
	print STDERR " This script is not tested with mod_perl!\n";
	print STDERR "-----------------------------------------\n";
	print STDERR "-----------------------------------------\n";
    }
    else
    {
#	print STDERR "\nOK, NOT running under mod-perl.\n";
    }
}

# -----------------------------------------------------------------------------

sub _getRemoteHost()
{
    my $self = shift;

    $self->{'REMOTE_HOST'} = $ENV{'REMOTE_HOST'} if defined( $ENV{'REMOTE_HOST'} );

    my $ip = inet_aton( $ENV{'REMOTE_ADDR'} );
    my ( $HostName ) = gethostbyaddr($ip, AF_INET);

    $self->{'REMOTE_HOST'} = $? ? $ENV{'REMOTE_ADDR'} : $HostName;

    return 1;
}

# -----------------------------------------------------------------------------

sub cgiapp_prerun
{
    my $self = shift;

    # Check whether user is logged in
    # --------------------------------
    if( $self->CheckLogin() )
    {
	# Check users permissions
	# --------------------------------
	if( ( !$self->{USER_DATA}->{isAdmin} ) && $self->_getPermission() )
	{
	    $self->logger('User is not Admin.');
	    $self->prerun_mode('list');
	    $self->_FillMenu('list');
	}
	else
	{
	    $self->_FillMenu();
	}
    }
    else
    {
	$self->logger('User not logged in.');
	$self->prerun_mode('login');
    }
}

# -----------------------------------------------------------------------------

sub cgiapp_postrun
{
    my $self = shift;
    my $out_ref = shift;

    $self->{MainTmpl}->param('CONTENT' => $$out_ref);

    $$out_ref = $self->{MainTmpl}->output();
}

# -----------------------------------------------------------------------------

sub teardown
{
    my $self = shift;

    $self->getDBH()->disconnect;    
}

# -----------------------------------------------------------------------------

sub _CheckUser($$)
{
    my $self = shift;

    my $User_sql = $self->getDBH()->quote($_[0]);
    my $Password_sql = $self->getDBH()->quote($_[1]);

    my $sql = "SELECT UserID, FullName, eMail, isAdmin, LastLogin, UserName ".
	"FROM User ".
	"WHERE UserName = $User_sql ".
	"AND Password = password($Password_sql)";

    my $UserData = $self->getDBH()->selectrow_hashref($sql);

    if( defined($UserData) )
    {
	$self->{USER_DATA} = $UserData;

	return 1;
    }
    else
    {
	return 0;
    }
}

# -----------------------------------------------------------------------------

sub _getPermission
{
    my $self = shift;

    my @Entries = @{$self->{ALL_MENU_ENTRIES}};
    my $rm = $self->get_current_runmode();
    my $MustBeAdmin = 0;

    foreach my $Entry ( @Entries )
    {
	if( $Entry->{'RunMode'} && $Entry->{'RunMode'} eq $rm )
	{
	    $MustBeAdmin = $Entry->{'Admin'};
	    last;
	}
	elsif( exists( $Entry->{'SubLevel'} ) && $Entry->{'SubLevel'} )
	{
	    push( @Entries, @{$Entry->{'SubLevel'}} );
	}
    }
    
    return $MustBeAdmin;
}

# -----------------------------------------------------------------------------

sub _MakeSessionID($)
{
    my $self = shift;

    my $i;
    my $SID = crypt($_[0], 'SI');
    my @Chars = split(//, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890');
    
    for($i = 0; $i < 37; $i++)
    {
	$SID .= @Chars[rand(@Chars)];
    }
    
    return $SID;
}

# -----------------------------------------------------------------------------

sub _FillMenu(;$)
{
    my $self = shift;
    $self->{'RunMode'} = shift;

    my $data = $self->_NavMenuCleanup();
    
    $self->{MainTmpl}->param( 'NavMenu' => $data ) if $self->getUser()->{UserID};

    return 1;
}

# -----------------------------------------------------------------------------

sub _NavMenuCleanup(;$)
{
    my $self = shift;

    my $Entries = shift || $self->{ALL_MENU_ENTRIES};
    my @Result = ();

    my $FileName = basename( $0 );    
    my $rm = $self->{'RunMode'} || $self->get_current_runmode();

    foreach my $Entry (@$Entries)
    {
	my $Admin = delete( $Entry->{'Admin'} );

	if( !( $Admin ) || $self->getUser()->{isAdmin} )
	{
	    if( exists( $Entry->{'SubLevel'} ) && $Entry->{'SubLevel'} ) 
	    {
		my $tmp = $self->_NavMenuCleanup( $Entry->{'SubLevel'} );
		$Entry->{'SubLevel'} = $tmp;
	    }

	    if( $Entry->{'RunMode'} eq $rm )
	    {
		$Entry->{'Current'} = 1;
	    }

	    $Entry->{'FileName'} = "$FileName?mode=".$Entry->{'RunMode'};

	    push( @Result, $Entry );
	}
    }

    return \@Result;
}
 
1;
