# ===============================================================================
# The Class 'cMySQL'
# ===============================================================================

package WebEve::cMySQL;

use strict;
use vars qw( @ISA );
use DBI;
use WebEve::Config;

@ISA = qw( DBI );

# --------------------------------------------------------------------------------
# The Constructor
# --------------------------------------------------------------------------------

sub connect
{
    my $class = shift;

    die "Constructor has to be used as instance method!" if ref($class);

    my $connectTo = shift || 'default';

    my $db_type = ${$DB{ $connectTo }}{'type'};
    my $db_name = ${$DB{ $connectTo }}{'name'};
    my $db_host = ${$DB{ $connectTo }}{'host'};
    my $db_port = ${$DB{ $connectTo }}{'port'};
    my $db_user = ${$DB{ $connectTo }}{'user'};
    my $db_pass = ${$DB{ $connectTo }}{'pass'};
    
    unless( defined $db_name )
    {
	die( "Can not connect to database <$connectTo>, no DB name configured.\n" .
	     "Check AddDB-Parameter in Config.pm\n" );
    }
    
    my $data_source = "dbi:$db_type:$db_name;host=$db_host;port=$db_port";

    my $self = $class->SUPER::connect( $data_source,
				       $db_user,
				       $db_pass,
				       { RaiseError => 1,
					 dbi_connect_method => 'connect_cached' } ) or die $DBI::errstr;
    return $self;	
}

sub connect_cached()
{
    my $class = shift;
    return  $class->connect( @_ );
}

# ===============================================================================
# The Class 'cMySQL::db'
# ===============================================================================

package WebEve::cMySQL::db;
use vars qw( @ISA );

@ISA = qw( DBI::db );


# ===============================================================================
# The Class 'cMySQL::st'
# ===============================================================================

package WebEve::cMySQL::st;
use vars qw( @ISA );

@ISA = qw( DBI::st );

1;
