#!/usr/bin/perl

#########################################################################
# edit.pl - v0.9                                         19. April 2002 #
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
my $SubTmpl = HTML::Template->new(filename => "$BasePath/edit.tmpl");
$MainTmpl->param( 'TITLE' => 'Termin bearbeiten' );

# -----------------------------------------------------------------------

my $EntryID = $query->param('EntryID') || 0;

my $Day = $query->param('Day') || 0;
my $Month = $query->param('Month') || 0;
my $Year = $query->param('Year') || 'x';

my $Hour = $query->param('Hour') || 0;
my $Minute = $query->param('Minute') || 0;
my $Place = $query->param('Place') || '';

my $Description = $query->param('Description') || '';
my $OrgID = $query->param('OrgID') || 0;
my $Public = $query->param('Public') || 0;

my $Action = $query->param('Action') || '';

my @UserData = CheckLogin();

if(@UserData > 0)
{
    if($Action eq 'Save')
    {
	my @Message = CheckValues();
	my $Place_sql = sqlQuote($Place);
	my $Description_sql = sqlQuote($Description);

	if(@Message == 0)
	{
	    DoSQL("UPDATE Dates SET Date='$Year-$Month-$Day', Time='$Hour:$Minute:00',
                   Place=$Place_sql, Description=$Description_sql, OrgID=$OrgID,
                   UserID=$UserData[0], Public=$Public
                   WHERE EntryID = $EntryID");

	    logger("Changed date: $EntryID");

	    print "Location: $BaseURL/edit-list.pl\n";
	    print "Content-type: text/html\n\n";
	    print "empty";
	}
	else
	{
	    my $Message = join(', ', @Message);
	    $SubTmpl->param('Message' => "<font color=\"#ff0000\"><b>Fehler in $Message</b></font>");

	    $SubTmpl->param('EntryID' => $EntryID);
	    $SubTmpl->param('Day' => $query->param('Day'));
	    $SubTmpl->param('Month' => $query->param('Month'));
	    $SubTmpl->param('Year' => $query->param('Year'));

	    $SubTmpl->param('Hour' => $query->param('Hour'));
	    $SubTmpl->param('Minute' => $query->param('Minute'));
	    $SubTmpl->param('Place' => $query->param('Place'));

	    $SubTmpl->param('Description' => $query->param('Description'));
	    $SubTmpl->param('Public' => 'checked') if $Public;

	    my @Orgs = @{getOrgList($UserData[0])};

	    foreach my $OrgRef (@Orgs)
	    {
		$OrgRef->{'Selected'} = 'selected' if( $OrgRef->{'OrgID'} == $OrgID );
	    }

	    $SubTmpl->param('Orgs' => \@Orgs);

	    $MainTmpl->param('CONTENT' => $SubTmpl->output());

	    print "Content-type: text/html\n\n";
	    print $MainTmpl->output();
	}
    }
    else
    {
	my $sth = SendSQL("SELECT
                           lpad(dayofmonth(d.Date), 2, '0'),
                           lpad(month(d.Date), 2, '0'),
                           year(d.Date),
                           lpad(hour(d.Time), 2, '0'),
                           lpad(minute(d.Time), 2, '0'),
                           d.Place,
                           d.Description,
                           d.Public,
                           d.OrgID,
                           d.UserID
                           FROM Dates d
                           WHERE d.EntryID=$EntryID");

	my @Data = FetchSQLData($sth);

#	print STDERR Dumper(@Data);

	$SubTmpl->param('EntryID' => $EntryID);

	$SubTmpl->param('Day' => $Data[0]);
	$SubTmpl->param('Month' => $Data[1]);
	$SubTmpl->param('Year' => $Data[2]);

	$SubTmpl->param('Hour' => $Data[3]);
	$SubTmpl->param('Minute' => $Data[4]);
	$SubTmpl->param('Place' => $Data[5]);

	$SubTmpl->param('Description' => $Data[6]);
	$SubTmpl->param('Public' => 'checked') if $Data[7];

	my @Orgs = @{getOrgList($UserData[0])};

	foreach my $OrgRef (@Orgs)
	{
	    $OrgRef->{'Selected'} = 'selected' if( $OrgRef->{'OrgID'} == $Data[8] );
	}

	$SubTmpl->param('Orgs' => \@Orgs);

	$MainTmpl->param('NavMenu' => getNavMenu( $UserData[3] ) ) ;
	$MainTmpl->param('CONTENT' => $SubTmpl->output());

	print "Content-type: text/html\n\n";
	print $MainTmpl->output();

    }
}
else
{
        print "Location: $BaseURL/login.pl\n";
        print "Content-type: text/html\n\n";
        print "empty";
}



sub CheckValues
{
        my @EmptyFields;

        if($Day =~ /\D/ || $Day < 0 || $Day > 31)
        {
                push(@EmptyFields, 'Tag');
        }

        if($Month =~ /\D/ || $Month < 1 || $Month > 12)
        {
                push(@EmptyFields, 'Monat');
        }

        if($Year =~ /\D/)
        {
                push(@EmptyFields, 'Jahr');
        }

        if($Hour =~ /\D/)
        {
                push(@EmptyFields, 'Stunde');
        }

        if($Minute =~ /\D/)
        {
                push(@EmptyFields, 'Minute');
        }

        if(($Hour > 0 || $Minute > 0) && $Place eq '')
        {
                push(@EmptyFields, 'Ort');
        }

        if($Description eq '')
        {
                push(@EmptyFields, 'Beschreibung');
        }

        return @EmptyFields;
}
