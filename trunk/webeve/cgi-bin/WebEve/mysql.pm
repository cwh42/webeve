package WebEve::mysql;

use strict;
use WebEve::Config;
use Exporter;
use Carp;
use DBI;

use vars qw( @ISA @EXPORT %dbIDs );

@ISA	= qw(Exporter);
@EXPORT	= qw(ConnectToDatabase
	     SendSQL
	     getDBH
	     sqlQuote
	     DoSQL
	     FetchSQLData 
	     FetchOneColumn 
	     FetchOneColumnList
	     ExecSQL
	     SQLFinish
	     DBLastInsertID );

# --------------------------------------------------------

sub END
{
    
}

=head1 NAME

pdbsql - pdb sql module

=head1 USAGE

    use DB::pdbsql;

=head1 DESCRIPTION

This module provides routines to access databases with sql. Since it is a PDB
module, it is designed to work with with the pdb database.

The module contains the main functions:

=over 4

=item SendSQL

C<SendSQL> takes a SQL statement and sends it to the database. It returns a 
handle to the SQL statement, which is needed for to fetch the data. Use
L<FetchSQLData> for that.

=item FetchSQLData

C<FetchSQLData> is the main function to retrieve data from the handle which 
is returned by L<SendSQL>.

=back

=head1 MULTIPLE CONNECTIONS

SendSQL and ConnectToDatabase which is automatically called by SendSQL 
supports multiple connections, which means that is can connect to more 
than one databases. 

For that, additional databases to connect to need to be configured in 
Config.pm. A connection needs to be named and the connection parameter
for the database need to be written to an additional data block in Config.pm
like this:

    $AddDB { 'brand' } = {
    'type'	=>  'mysql',
    'host'	=>  'localhost',
    'port'	=>  3306,
    'name'	=>  'brands',
    'user'	=>  'root',
    'pass'	=>  'asdf'
    } ;

This configures a connection named 'brand'. The name needs to be passed
to L<SendSQL> to send a statement to that connection.

Giving no name to SendSQL defaults to the pdb database.

=cut

#############################################################################

=head1 NAME

DBLastInsertID() - retrieves the last insert id.

=head1 SYNOPSIS

    use DB::pdbsql;

    my $last_id = DBLastInsertID();

=head1 DESCRIPTION

does the same as the statement I<SELECT LAST_INSERT_ID()> 
for mysql. Since this statement is not portable, this 
function should be used instead to make it easier to port
an application to another database.

Add an optional connection name to retrieve the last inserted
id for the connection.

=head1 RETURN

returns the last inserted id in skalar context.

=cut

sub DBLastInsertID(;$)
{
    my ($c) = @_;

    return( FetchOneColumn( SendSQL( "SELECT LAST_INSERT_ID()", $c )));
}


=head1 NAME

ConnectToDatabase - establishes a connection to the database

=head1 SYNOPSIS

    use DB::pdbsql;

    ConnectToDatabase();

=head1 DESCRIPTION

Establishes the connection to the database based on the values read from the
configuration file.  If this fails, the program confesses.

ConnectToDatabase takes an optional parameter for the connection name, which 
must be configured in Config.pm

=cut

sub ConnectToDatabase(;$)
{
    my ($c) = @_;
    my $connectTo = $c || 'default';

    my $tmpdb = $dbIDs{ $connectTo };

    if (!defined $tmpdb)
    {
	my $db_type = ${$DB{ $connectTo }}{'type'};
	my $db_name = ${$DB{ $connectTo }}{'name'};
	my $db_host = ${$DB{ $connectTo }}{'host'};
	my $db_port = ${$DB{ $connectTo }}{'port'};
	my $db_user = ${$DB{ $connectTo }}{'user'};
	my $db_pass = ${$DB{ $connectTo }}{'pass'};

	unless( defined $db_name )
	{
	    confess( "Can not connect to database <$connectTo>, no DB name configured.\n" .
		     "Check AddDB-Parameter in Config.pm\n" );
	}

	# print STDERR "ConnectToDatabase: Connect to db name <$db_name>\n";

	if (grep(/$db_type/, DBI->available_drivers))
	{
	    my $data_source = "dbi:$db_type:$db_name;host=$db_host;port=$db_port";

	    $tmpdb = DBI->connect($data_source, $db_user, $db_pass,
				  { RaiseError => 1 })
		|| confess "Cannot connect to package database: " . $DBI::errstr . "\n";

	    $dbIDs{ $connectTo } = $tmpdb;
	} else {
	    confess "No driver available for $db_type. :(\n";
	}
    }
    return( $tmpdb );
}


=head1 NAME

sqlQuote - quotes a String SQL-conform.

=head1 SYNOPSIS

    use DB::pdbsql;

    my $string = sqlQuote( "St. Finnag@n's Delight" );

=head1 DESCRIPTION

The given string is returned in quotes and has all characters quoted,
which could disturb a SQL-Statement. The return string may be used in
String-related SQL-Statements.

=cut

sub sqlQuote( $ )
{
    my ($str) = @_;
    my $db = $dbIDs{ 'default'};

    $db = ConnectToDatabase() unless defined( $db );

    confess( "Could not connect to default db" ) unless( defined $db );

    return( $db->quote( $str ));
}


=head1 NAME

getDBH - returns the package database handle.

=head1 SYNOPSIS

    use DB::pdbsql;

    my $dbh = getDBH();

=head1 DESCRIPTION

getDBH returns the database handle for the package database.
The return value may be used to perform special functions 
on the database.

getDBH takes an optional parameter for the connection name.

=cut

sub getDBH(;$)
{
    my ($c) = @_;
    my $connection = $c || 'default';

    return $dbIDs{ $connection };
}


=head1 NAME

SendSQL - send a sql-statement and prepare its execution.

=head1 SYNOPSIS

    use DB::pdbsql;

    my $sth = SendSQL( "Select * from persons" );
       or
    my $sth = SendSQL( "Select * from persons where name = ?" );


=head1 DESCRIPTION

SendSQL prepares a SQL-Statement for execution. It need to be called 
before any of the FetchSQL-Data Functions may be called.

Two kinds of SQL-Statements are possible: It may be a plain Statement
like 'Select * from persons' or a statement with questionmarks, which
will be replaced by values passed to L<ExecSQL>.

Mind that the prepared Statement must be referenced by the returned
handle, which must be passed with all following function call concerning
that query.

SendSQL takes an optional second parameter with the connection name.

=head1 SEE ALSO

ExecSQL

=cut

sub SendSQL( $;$ )
{
    my ($str, $c) = @_;
    my $connection = $c || 'default';

    my $db = $dbIDs{ $connection };

    unless( defined $db )
    {
	$db = ConnectToDatabase($connection);
	confess ( "unable to connect to database connection <$connection>\n" ) unless( defined $db );
    }

    my $handle = $db->prepare( $str ) || confess $db->errstr;

    # If no spaceholders present, execute now.
    if( $handle->{NUM_OF_PARAMS} == 0 ) {
	$handle->execute;
    } 
    # else {
    # print STDERR "SQL-Statement Waiting for parameter...\n";
    # }
    return( $handle );
}

=head1 NAME

ExecSQL - Execute a prepared query.

=head1 SYNOPSIS

    use DB::pdbsql;

    my $sth = ExecSQL( $sth, ( $string1, $string2 ));

=head1 DESCRIPTION

This function must be called to execute a prepared query with 
replace-values, which is represented by the handle in the first
parameter. The Strings given in array context as second 
parameter are set for the question marks in the fundamental
query string. It is absolutely neccessary to send the same 
amount of replacement strings as the amount of question marks.

After having called ExecSQL, the result can be retrieved 
calling L<FetchSQLData> or one of the other Fetch-functions.

ExecSQL may be called multiple on the same handle, always 
folled by a Fetch-Function.

Example:

    use DB::pdbsql;

    my $sth = SendSQL( "Select * from person where name = ?" );

    ExecSQL( $sth, ("freitag"));
    my ($freitags_name) = FetchSQLData( $sth );

    ExecSQL( $sth, ("Finnigan"));
    my ($finnigans_name) = FetchSQLData( $sth );



=head1 SEE ALSO

ExecSQL, SendSQL

=cut


=head1 NAME

ExecSQL - execute a SQL-Statement with templates.

=head1 SYNOPSIS

    use pdbsql;

    my $sth = SendSQL( "select name from persons where id=?" );

    ExecSQL( $sth, 9 );

    Fetch...

=head1 DESCRIPTION

This function executes the SQL-Statement represented by the handle.
The statement may contain templates (?), for which values can be
passed using ExecSQL as second and following parameters.

The ExecSQL-function can be called multiple for the same statement.
That means, that it is possible to define one search and call it
with a lot of different search data.

=head1 SEE ALSO

SendSQL, Fetch...

=cut


sub ExecSQL( $@ ) 
{
    my ( $sth, @fields) = @_;

    my $num_fields = @fields;

    if( 0+$sth->{NUM_OF_PARAMS} != 0+$num_fields ) {
        confess "Number of Params not equal to required !\n";
    }

    my $res = $sth->execute( @fields ) || confess "Cant exec statement: $DBI::errstr\n";

    return( 0 + $res );
}


=head1 NAME

FetchSQLData( $handle ) - Getting the result of a query.

=head1 SYNOPSIS

    use DB::pdbsql;

    my $sth = SendSQL( "Select * from persons" );

    while( my @result = FetchSQLData( $sth ))
    {
	print join( ", ", @result ) . "\n";
    }

=head1 DESCRIPTION

Fetches the result of a query represented by the handle. This function
returns the contents of one line of the search result per call. It
should be called until the result returns undefined values.

=head1 SEE ALSO

FetchOneColumn, FetchOneColumnList

=cut

sub FetchSQLData( $ ) 
{
    my ($sth) = @_;

    confess "Handle is not connected !\n" unless defined( $sth );

    return( $sth->fetchrow_array );
}

=head1 NAME

FetchOneColumnList( $handle ) - Fetches the result of a query.

=head1 SYNOPSIS

    use DB::pdbsql;

    my $sth = SendSQL( "Select name from persons" );

my @result = FetchOneColumnList( $sth ));
    # result contains all names now.


=head1 DESCRIPTION

FetchOneColumnList fetches the result of a query which has one
result column. All result values are returned in an array context.

=head1 SEE ALSO

FetchSQLData, SendSQL, FetchOneColumn

=cut


sub FetchOneColumnList( $ ) 
{
    my ($sth) = @_;

    confess"Handle is not connected !\n" unless defined( $sth );

    my @result;

    while( my $val = FetchOneColumn( $sth ))
    {
	push  @result, $val;
    }

    return( @result );
}


=head1 NAME

FetchOneColumn( $handle ) - Fetches the result of a query.

=head1 SYNOPSIS

    use DB::pdbsql;

    my $sth = SendSQL( "Select DATE()" );
    
    my $date = FetchOneColumn( $sth ));
    # result contains all names now.


=head1 DESCRIPTION

FetchOneColumn fetches the result of a query which has one
result column in a scalar context. 

=head1 SEE ALSO

FetchSQLData, SendSQL, FetchOneColumnList

=cut

sub FetchOneColumn( $ ) 
{
    my ($sth) = @_;

    confess "Handle is not connected !\n" unless defined( $sth );

    my $ary_ref = $sth->fetchrow_arrayref;

    return( @$ary_ref[0] );
}

=head1 NAME

DoSQL( $statement ) - Perform one single SQL-Statement.

=head1 SYNOPSIS

    use DB::pdbsql;

    my $count = DoSQL( "Delete from persons where login_id=12" );

    print "Affected lines: $count";

=head1 DESCRIPTION

This function performs one sql-Statement and returns immediately.

NOTE: THE RESULT OF THE QUERY CAN NOT BE RETRIEVED !

Thus, this function is usefull for sending Inserts, updates etc.
It returns the amount of rows affected by the statement.

=head1 RETURN VALUES

This function returns two parameters. The first are the affected 
rows and the second one is a flag which indicates the result of
the operation.

=head1 SEE ALSO

SendSQL, ExecSQL

=cut

# Function that executes one SQL-Statement and returns the number of rows
# affected.
sub DoSQL( $;$ )
{
    my ($statement, $c) = @_;
    my $connection = $c || 'default';

    return( 0 ) unless defined( $statement );

    ConnectToDatabase( $connection );
    my $res = 0;
    if( exists $dbIDs{$connection} )
    {
	$res = $dbIDs{$connection}->do( $statement );
    }
    else
    {
#	print STDERR "fatal: do-statement writes to unknown connection!\n" );
    }

    if( !defined $res ) {
	my $err = $dbIDs{$connection}->errstr;
	print STDERR ("error: do-statement returns undef -> $err !\n");
	return( 0 );
    } elsif ( $res eq "0E0" ) {
	return( 1 );
    } else {
	return( $res );
    }
}

=head1 NAME

SQLFinish() - close a SQL handle

=head1 SYNOPSIS

    use DB::pdbsql;

    my $sth = SendSQL( "SELECT * FROM world" );

    if( comes_a_lot ) {
        SQLFinish( $sth );
    }

=head1 DESCRIPTION

closes a open SQL-handle. Normally, that is not really needed.
But if not B<all> data is read from the query object, it can
be closed to free all resources.

=cut

sub SQLFinish( $ )
{
    my ($handle) = @_;

    return unless( defined $handle );

    $handle->finish();
}

1;
