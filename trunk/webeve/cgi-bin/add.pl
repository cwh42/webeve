#!/usr/bin/perl

#########################################################################
# add.pl - v0.9                                            19. Apr 2000 #
# (c)2000-2002 C.Hofmann tr1138@bnbt.de                                 #
#########################################################################

use strict;
use CGI;
use HTML::Template;
use Date::Calc qw( Moving_Window check_date This_Year Today Days_in_Month Delta_Days);
use WebEve::mysql;
use WebEve::termine;
use WebEve::Config;

main();


sub ParseDate($)
{
    my ($DateStr) = @_;

    my $Day = 0;
    my $Month = 0;
    my $Year = 0;

    $DateStr =~ s/^\s+//g; 
    $DateStr =~ s/\s+$//g; 

    if( $DateStr =~ /^(\d+)$/ )
    {
	$Day = 0;
	$Month = $DateStr;
	$Year = This_Year();

	return 0 if( $Month < 1 && $Month > 12 );

	$Year++ while( Delta_Days(Today(), $Year, $Month, 1) < 0 );
    }
    elsif( $DateStr =~ /^(\d+)\D(\d+)$/ )
    {
	$Day = 0;
	( $Month, $Year ) = split(/\D/, $DateStr);
	$Year = Moving_Window($Year);

	return 0 if( $Month < 1 && $Month > 12 );
    }
    elsif( $DateStr =~ /^(\d+)\D(\d+)\D(\d*)$/ )
    {
	$Day = $1;
	$Month = $2;
	$Year = Moving_Window($3);

	return 0 unless check_date( $Year, $Month, $Day );
	
	if( $Month == 2 && $Day == 29 && $3 == 0 )
	{
	    $Year++ until( check_date( This_Year(), $Month, $Day ) );
	}
	elsif( $3 == 0 )
	{
	    $Year++ while( Delta_Days(Today(), $Year, $Month, $Day) < 0 );
	}
    }
    else
    {
	return 0;
    }
    
    return $Year, $Month, $Day;
}

sub ParseTime($)
{
    my ($TimeStr) = @_;

    my $Hour = 0;
    my $Minute = 0;

    $TimeStr =~ s/^\s+//g; 
    $TimeStr =~ s/\s+$//g; 

    if( $TimeStr =~ /^(\d+)$/ )
    {
	$Hour = $1;
	$Minute = 0;
    }
    elsif( $TimeStr =~ /^(\d+)\D(\d+).*$/ )
    {
	$Hour = $1;
	$Minute = $2;
    }

    return 0 if( $Hour < 0 || $Hour > 23 || $Minute < 0 || $Minute > 59 );

    return $Hour, $Minute;
}


sub main()
{
    my $query = new CGI;
    my $MainTmpl = HTML::Template->new(filename => "$BasePath/main.tmpl");
    my $SubTmpl = HTML::Template->new(filename => "$BasePath/add.tmpl");
    $MainTmpl->param( 'TITLE' => 'Neuer Termin' );

# -----------------------------------------------------------------------

    my $OrgID = $query->param('OrgID') || '';
    my $Public = $query->param('Public') || 0;
    my $DateStr = $query->param('Date') || '';
    my $TimeStr = $query->param('Time') || '';
    my $Place = $query->param('Place') || '';
    my $Description = $query->param('Description') || '';

    my $Action = $query->param('Action') || '';

    my @UserData = CheckLogin();

    if(@UserData > 0)
    {
	$SubTmpl->param('Orgs' => getOrgList($UserData[0]));
	$SubTmpl->param('Public' => 1);

	if($Action eq 'Save')
	{
	    my @Date = ParseDate($DateStr);
	    my @Time = ParseTime($TimeStr);
	    $Description =~ s/^\s+//g; 
	    $Description =~ s/\s+$//g; 

	    $SubTmpl->param('DateError' => 1) if @Date == 1;
	    $SubTmpl->param('TimeError' => 1) if @Time == 1;
	    $SubTmpl->param('DescError' => 1) if $Description eq '';

	    if( @Date > 1 && @Time > 1 && $Description ne '' )
	    {
		my $DateSQL = "'".join('-', @Date)."'";
		my $TimeSQL = "'".join('-', @Time).":00'";
		
		my $PlaceSQL = sqlQuote($Place);
		my $DescriptionSQL = sqlQuote($Description);
		
		DoSQL("INSERT INTO Dates (Date, Time, Place, Description, OrgID, UserID, Public)
                       VALUES($DateSQL,$TimeSQL,$PlaceSQL,$DescriptionSQL,$OrgID, $UserData[0], $Public)");

		my $LastID = FetchOneColumn(SendSQL("SELECT LAST_INSERT_ID() FROM Dates LIMIT 1"));

		if($LastID)
		{
		    logger("Added date: $LastID");

		    $SubTmpl->param('Saved' => 1);
		    $SubTmpl->param('SvOrgName' => 'XXX');
		    $SubTmpl->param('SvEntryID' => $LastID);
		    $SubTmpl->param('SvDate' => sprintf("%02d.%02d.%d", reverse(@Date)));

		    if( @Time == 1 || ($Time[0] == 0 && $Time[1]) )
		    {
			$TimeStr = '';
		    }
		    else
		    {
			$TimeStr = sprintf("%02d:%02d", @Time);
		    }

		    $SubTmpl->param('SvTime' => $TimeStr);
		    $SubTmpl->param('SvPlace' => $query->param('Place'));
		    $SubTmpl->param('SvDescription' => $query->param('Description'));
		    $SubTmpl->param('SvPublic' => $Public ? 1 : 0);
		}
		else
		{
		    $SubTmpl->param('Saved' => 0);
		    $SubTmpl->param('Error' => 1);
		    logger("ERROR: Could not insert date!");
		}

	    }
	    else
	    {
		$SubTmpl->param('Orgs' => getOrgList($UserData[0], $OrgID));
		$SubTmpl->param('Date' => $query->param('Date'));
		$SubTmpl->param('Time' => $query->param('Time'));
		$SubTmpl->param('Place' => $query->param('Place'));
		$SubTmpl->param('Description' => $query->param('Description'));
		$SubTmpl->param('Public' => $Public ? 1 : 0);
	    }
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
}

