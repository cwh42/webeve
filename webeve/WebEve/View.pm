package WebEve::View;

use strict;
use WebEve::Config;
use WebEve::cEventList;
use HTML::Template;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = qw(Exporter);
@EXPORT = qw( CalendarHTML ); 

sub CalendarHTML
{
    my $Url = shift || '';
    my $SubTmplName = "kalender-table.tmpl";

    my $query = new CGI;

    my $Organization = $query->param('Verein') || $query->param('Org') || 0; 
    my $Intern = $query->param('Intern') || 0; 
    $Intern = 0 if ! $Organization; 

    my $Page = $query->param('Seite') || '1'; 

    my $tmp = sprintf("custom/template-%02d-advanced.tmpl", $Organization);
    $SubTmplName = $tmp if( -f "$TemplatePath/$tmp" );

    my $SubTmpl = HTML::Template->new(filename => "$TemplatePath/$SubTmplName",
				      die_on_bad_params => 0,
				      loop_context_vars => 1);

    # -----------------------------------------------------------------------

    my $EventList = WebEve::cEventList->new( 'PerPage' => 15,
					     'Page' => $Page,
					     'PublicOnly' => !$Intern,
					     'ForOrgID' => $Intern ? $Organization : 0 );
    $EventList->readData();

    $SubTmpl->param( PageSwitch( Org => $Organization,
				 ScriptURL => $Url,
				 Page => $Page,
				 Pages => $EventList->getPageCount(),
				 Internal => $Intern ) );
    
    # -----------------------------------------------------------------------

    my $Today = WebEve::cDate->new('today');

    # Terminliste
    # -----------------------------------------------------------------------
    my $LastDate = '';
    my $LastMonth = 0;
    my $LastYear = 0;
    my $LastWasNextWeek = 0;

    my @TodayDates = ( { 'Header' => "Heute - ".$Today->getDateStr } );
    my @NextWeekDates = ( { 'Header' => "In den nächsten 7 Tagen" } );
    my @OtherDates = ();

    foreach my $DateObj ( $EventList->getDateList() )
    {
	my $OrgName = $DateObj->getOrg;

	my $HashRef = { 'Time' => $DateObj->getTime,
			'Place' => $DateObj->getPlace,
			'Title' => $DateObj->getTitle,
			'Desc' => $DateObj->getDesc }; #,
#			'eMail' => $query->escapeHTML($OrgList{ $DateObj->getOrgID }->[1]),
#			'Website' => $query->escapeHTML($OrgList{ $DateObj->getOrgID }->[2]) };

	$HashRef->{'Org'} = $OrgName unless( $Intern );

	if( $DateObj->getDate->getDateStr ne $LastDate )
	{
	    $HashRef->{'Date'} = $query->escapeHTML($DateObj->getDate->getDateStr);
	    $LastDate = $DateObj->getDate->getDateStr;
	}

	if( $DateObj->getDate->isToday )
	{
	    push( @TodayDates, $HashRef );
	}
	elsif( $DateObj->getDate->isNextWeek )
	{
	    push( @NextWeekDates, $HashRef );
	}
	else
	{
	    if( $DateObj->getDate->getMonth != $LastMonth || $DateObj->getDate->getYear != $LastYear )
	    {
		my $TextMonth = $DateObj->getDate->getMonthText;
		$TextMonth =~ s/(\W)/'&#'.ord($1).';'/ge;
		push( @OtherDates, { 'Header' => "$TextMonth ".$DateObj->getDate->getYear } );
		
		$LastMonth = $DateObj->getDate->getMonth;
		$LastYear =  $DateObj->getDate->getYear;
	    }

	    push( @OtherDates, $HashRef );	
	}
    }

    my @DateList = ();

    push( @DateList, @TodayDates ) if @TodayDates > 1;
    push( @DateList, @NextWeekDates ) if @NextWeekDates > 1;
    push( @DateList, @OtherDates);

    $SubTmpl->param('Dates' => \@DateList );

    return $SubTmpl->output();
}

# -----------------------------------------------------------------------
# Page Switch
# Param-Hash: Org, Page, Pages, Internal
# -----------------------------------------------------------------------
sub PageSwitch(%)
{
    my %Param = @_;
    my $Pages = $Param{Pages};
    my $Page = $Param{Page};

    my @Switch = ();
    my %Result;
    
    my $Format = $Param{'ScriptURL'} || 'kalender.pl';

    $Format .= ( index( $Format, '?' ) == -1 ) ? '?' : '&';
    $Format .= "Seite=%d&Verein=%s";
    $Format .= "&Intern=Intern" if $Param{Internal};
    
    for( my $i = 1; $i <= $Pages; $i++)
    {
	my $HashRef = { 'Page' => $i };
	$HashRef->{'PageURL'} = sprintf($Format, $i, $Param{Org}) if $i != $Page;
	$HashRef->{'IsCurrent'} = 1 if $i == $Page; 
	
	push( @Switch, $HashRef );
    }

    $Result{'Pages'} = \@Switch if $Pages > 1;
    $Result{'NextPage'} = $Page + 1 if $Page < $Pages;
    $Result{'NextPageURL'} = sprintf($Format, $Page + 1, $Param{Org}) if $Page < $Pages;
    $Result{'PrevPage'} = $Page - 1 if $Page > 1;
    $Result{'PrevPageURL'} = sprintf($Format, $Page - 1, $Param{Org}) if $Page > 1;
    $Result{'PageCount'} = $Pages;
    $Result{'CurrentPage'} = $Page;

    return %Result;
}

1;
