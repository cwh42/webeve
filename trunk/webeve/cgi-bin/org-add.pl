#!/usr/bin/perl

#########################################################################
# org-add.pl - v0.9                                        19. Apr 2002 #
# (c)2000-2002 C.Hofmann tr1138@bnbt.de                                 #
#########################################################################

use strict;
use HTML::Template;
use WebEve::mysql;
use WebEve::termine;
use WebEve::Config;
use CGI;

sub ArrayDiff($$;$);
# Settings

my $query = new CGI;
my $MainTmpl = HTML::Template->new(filename => "$BasePath/main.tmpl");
my $SubTmpl = HTML::Template->new(filename => "$BasePath/org-add.tmpl");
$MainTmpl->param( 'TITLE' => 'Neuer Verein' );

# -----------------------------------------------------------------------

my $Action = $query->param('Action') || '';

my $Name = $query->param('Name') || '';
my $eMail = $query->param('eMail') || '';
my $Website = $query->param('Website') || '';
my @Users =  $query->param('Users');   

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
    if($Action eq 'Save')
    {
	my @Message = CheckValues();

	if( @Message == 0 )
	{
	    my $NameSQL = sqlQuote($Name);
	    my $eMailSQL = sqlQuote($eMail);
	    my $WebsiteSQL = sqlQuote($Website);

	    DoSQL("INSERT INTO Organization
                   (OrgName, eMail, Website)
                   VALUES ($NameSQL, $eMailSQL, $WebsiteSQL)");

	    # Update relations Orgs->Users
	    my $sth = SendSQL("SELECT last_insert_id() FROM Organization LIMIT 1");
	    my $OrgID = FetchOneColumn($sth);

	    if(@Users)
	    {
		my $sql = "INSERT INTO Org_User (OrgID, UserID) VALUES ";
		$sql .=  join( ', ', map { "($OrgID, $_)" } @Users );

		DoSQL($sql);
	    }

	    logger("Added Organization: '$Name'; Users: ".join( ', ', @Users ));

	    print "Location: $BaseURL/user-list.pl\n";
	    print "Content-type: text/html\n\n";
	    print "empty";
	}
	else # @Message != 0
	{
	    $SubTmpl->param('Name' => $query->param('Name'));
	    $SubTmpl->param('eMail' => $query->param('eMail'));
	    $SubTmpl->param('Website' => $query->param('Website'));

	    my %AllUsers = getUserList();
	    my @LoopData = ();

	    foreach my $UserName ( keys( %AllUsers ) )
	    {
		my $selected;

		foreach(@Users)
		{
		    $selected = 'checked' if($_ == $AllUsers{$UserName}->[0]);
  		}

		push( @LoopData, { 'UserID' => $AllUsers{$UserName}->[0],
				   'UserName' => $UserName,
				   'FullName' => $AllUsers{$UserName}->[1],
				   'Selected' => $selected } );
	    }

	    $SubTmpl->param('Users' => \@LoopData);

	    my $Message = join(', ', @Message);
	    $SubTmpl->param('Message' => "<font color=\"#ff0000\">Fehler in $Message</font>");
	}
    }
    else
    {
	my %AllUsers = getUserList();
	my @LoopData = ();

	foreach my $UserName ( keys( %AllUsers ) )
	{
	    push( @LoopData, { 'UserID' => $AllUsers{$UserName}->[0],
			       'UserName' => $UserName,
			       'FullName' => $AllUsers{$UserName}->[1] } );
	}

	$SubTmpl->param('Users' => \@LoopData);
    }

    $MainTmpl->param('NavMenu' => getNavMenu( $UserData[3] ) ) ;
    $MainTmpl->param( 'CONTENT' => $SubTmpl->output() );

    print "Content-type: text/html\n\n";
    print $MainTmpl->output();
}
else # @UserData = 0;
{
    print "Location: $BaseURL/login.pl\n";
    print "Content-type: text/html\n\n";
    print "empty";
}


sub CheckValues
{
    my @EmptyFields;

    if( $Name eq '' )
    {
	push(@EmptyFields, 'Name');
    }

    if( $eMail ne '' && !($eMail =~ /\@/) )
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
