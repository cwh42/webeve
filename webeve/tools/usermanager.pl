#!/usr/bin/perl -w

use strict;
use WebEve::cMySQL;

my %fields = ( 'Dates' => { fields => ['UserID'],
                            timestamps => ['LastChange'] },
               'Logins' => { fields => ['UserID'] },
               'Org_User' => { fields => ['UserID'],
                               on_merge => \&org_user_merge },
               'UserPrefs' => { fields => ['UserID'] } );

#	       'ChangeLog' => { 'fields' => ['who', 'ApprovedBy'],
#				'timestamps' => ['changeTS'],
#				'on_merge' => \&changelog_merge,
#				'on_show' => \&changelog_show },

my $defaultmerge = 1;
my $printonly = 1;

my $action = shift @ARGV;

if( lc($action) eq 'merge' )
{
    my ($oldid, $oldlogin, $oldfullname) = getUserInfo( shift @ARGV );
    my ($newid, $newlogin, $newfullname) = getUserInfo( shift @ARGV );
    
    unless( $oldid && $newid )
    {
	print "merge needs oldid and newid\n";
	exit(1);
    }
    
    print "# Merging $oldfullname <$oldlogin> ($oldid) and $newfullname <$newlogin> ($newid);".
	" Last one will survive. - ";

    exit(1) unless( confirm() );

    merge( $oldid, $newid );
}
elsif( lc($action) eq 'show' )
{
    my ($userid, $login, $fullname, $tmp, $ll, $lc) = getUserInfo( shift @ARGV );

    unless( $userid )
    {
	print "show needs a userid\n";
	exit(1);
    }

    print "Show DB info about $fullname <$login> ($userid) [$ll, $lc]:\n\n";
    show( $userid, 1 );
}
elsif( lc($action) eq 'delete' )
{
    my ($userid, $login, $fullname, $tmp, $ll, $lc) = getUserInfo( shift @ARGV );

    unless( $userid )
    {
	print "delete needs a userid\n";
	exit(1);
    }

    print "Delete $fullname <$login> ($userid) [$ll, $lc] - ";
    exit(1) unless( confirm() );

    if( is_deletable( $userid , 1 ) )
    {
        merge( $userid, $defaultmerge );
    }
    else
    {
        print "Can not delete. Too many important entries in DB.\n";
        exit(1);
    }
}
elsif( lc($action) eq 'findunused' )
{
    my $delete = shift( @ARGV ) || '';

    my $showinfo = 0;

    print "Find unused accounts:\n";

    my $sql = "SELECT * FROM User;";

    my $dbh = WebEve::cMySQL->connect('default');
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $count = 0;
    
    while( my $user = $sth->fetchrow_hashref() )
    {
        if( is_deletable( $user->{UserID}, $showinfo ) )
        {
            print $user->{UserName}."\n";
            $count++;

            merge( $user->{UserID}, $defaultmerge ) if( $delete eq 'delete' );
        }
    }

    if( $delete eq 'delete' )
    {
        print "Deleted $count unused accounts.\n";
    }
    else
    {
        print "Found $count deletable accounts.\n";
    }
}
else
{
    print "No valid action specified.\n";
    print "\n";
    print "Valid actions:\n";
    print " show <userid|login_name> - show the number of entries for the account per table\n";
    print " merge <userid|login_name> <userid|login_name> - merge the given accounts into the last one\n";
    print " delete <userid|login_name> - delete the account if possible; does a check first.\n";
    print " findunused [delete] - find and list unused accounts; when 'delete' is given the found accounts woll be deleted\n";
    exit(1);
}

sub getUserInfo
{
    my ($id) = @_;

    return unless( defined $id );

    my $dbh = WebEve::cMySQL->connect('default');

    my $sql = "SELECT UserID, eMail, FullName, UserName, LastLogin, LoginCount FROM User WHERE ";

    if( $id =~ /^\d+$/ )
    {
	$sql .= "UserID = " . $id ;
    }
    elsif( $id =~ /@/ )
    {
	$sql .= "eMail = " . $dbh->quote( $id );
    }
    else
    {
	$sql .= "UserName = " . $dbh->quote( $id );
    }

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my $row = $sth->fetchrow_arrayref();

    return( @$row );
}

sub is_deletable
{
    my $person_id = shift;
    my $print = shift;

    my $userstats = show($person_id, $print);

    # Whether a DBentry is a delete-blocker or not should be stored in the table hash above.
    return( $userstats->{'Dates.UserID'} == 0 );
}

sub confirm
{
    print "(y/N)?";
    my $response = <STDIN>;
    chomp($response);
    return lc($response) eq 'y';
}

sub show
{
    my $person_id = shift;
    my $print = shift;
    my $summary_count = 0;

    my %userstats;

    foreach my $table ( sort { $a cmp $b } keys( %fields ) )
    {
	my $helper = $fields{$table}->{'on_show'};

	if( $helper && ref($helper) eq 'CODE' )
	{
	    my ($field, $count) = &$helper($person_id);
	    printf( "%-29s %6d\n", $field, $count ) if($print);
	}

        my $dbh = WebEve::cMySQL->connect('default');

	foreach my $field ( @{$fields{$table}->{'fields'}} )
	{
            my $sql = "SELECT count(*) FROM $table WHERE $field = $person_id;";
            my $sth = $dbh->prepare($sql);
            $sth->execute();

            my $row = $sth->fetchrow_arrayref();
	    my $count = $row->[0]||0;
	    
	    $summary_count += $count;
	    
            $userstats{"$table.$field"} = $count;
	    printf( "%-29s %6d\n", "$table.$field:", $count ) if($print);
	}
    }

    $userstats{"sum"} = $summary_count;
    print '-' x 36 if($print);
    printf( "\n%-29s %6d\n", "Summary count:", $summary_count ) if($print);

    return \%userstats;
}

sub merge
{
    my ( $oldid, $newid ) = @_;

    my @tables = sort { $a cmp $b } keys( %fields );

    my $locksql = "LOCK TABLES ".join(' WRITE, ', @tables)." WRITE, User WRITE;";
    dbdispatcher( $locksql );

    foreach my $table ( @tables )
    {
	my $helper = $fields{$table}->{'on_merge'};

	if( $helper && ref($helper) eq 'CODE' )
	{
	    &$helper($oldid, $newid);
	}

	foreach my $field ( @{$fields{$table}->{'fields'}} )
	{
	    # timestamps need a special treatment
	    my $timestamp = '';
	    
	    if( $fields{$table}->{'timestamps'} && ref($fields{$table}->{'timestamps'}) eq 'ARRAY' )
	    {
		$timestamp = ', '.join( ', ', map { "$_ = $_" } @{$fields{$table}->{'timestamps'}} );
	    }

	    my $sql = "UPDATE $table SET $field = ${newid}${timestamp} WHERE $field = $oldid;";
            dbdispatcher( $sql );
	}
    }

    my $sql = "DELETE FROM User WHERE UserID = $oldid;";
    dbdispatcher( $sql );

    my $unlocksql =  "UNLOCK TABLES;";
    dbdispatcher( $unlocksql );
}

sub dbdispatcher
{
    my $sql = shift;

    if( $printonly )
    {
        print STDERR "$sql\n";
    }
    else
    {
        my $dbh = WebEve::cMySQL->connect('default');
        $dbh->do( $sql );
    }
}

sub org_user_merge
{
    my $oldid = shift;
    my $newid = shift;

    my $dbh = WebEve::cMySQL->connect('default');

    my $sql = "SELECT OrgID FROM Org_User WHERE UserID = $newid;";
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @msgids = ();

    while( my $val = $sth->fetchrow_hashref() )
    {
	push  @msgids, $val->{OrgID};
    }

    if( @msgids )
    {
        my $sql2 = "DELETE FROM Org_User WHERE UserID = $oldid AND OrgID IN(".join(',', @msgids).');';
        dbdispatcher( $sql2 );
    }
}
