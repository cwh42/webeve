#!/usr/bin/perl

#########################################################################
# $Id$
# (c)1999-2002 C.Hofmann tr1138@bnbt.de                                 #
#########################################################################

use strict;
use CGI;
use HTML::Template;
use WebEve::Config;
use WebEve::cEventList;

main();


sub HTMLFilter($$)
{
    my ($String, $Type) = @_;

    if( $Type eq 'wap' )
    {
	$String =~ s/<.*?>//sg;
    }
    if( $Type eq 'csv' )
    {
	$String =~ s/<br>/ /isg;
	$String =~ s/\n/ /sg;
	$String =~ s/\r//sg;
	$String =~ s/<.*?>//sg;
    }

    return $String;
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
    
    my $Format = "kalender.pl?Seite=%d&Verein=%s";
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
    $Result{'NextPageURL'} = sprintf($Format, $Page + 1) if $Page < $Pages;
    $Result{'PrevPage'} = $Page - 1 if $Page > 1;
    $Result{'PrevPageURL'} = sprintf($Format, $Page - 1) if $Page > 1;
    $Result{'PageCount'} = $Pages;
    $Result{'CurrentPage'} = $Page;

    return %Result;
}

sub main
{
    my $MainTmplName = "kalender.tmpl";
    my $SubTmplName = "kalender-table.tmpl";
    #WAP: "text/vnd.wap.wml"

    my $query = new CGI;

    my $Intern = $query->param('Intern') || 0; 
    my $Template = $query->param('Ansicht') || ''; 
    my $Organization = $query->param('Verein'); 
    $Organization = $query->param('Org') || '1' if ! $Organization; 
    my $Page = $query->param('Seite') || '1'; 
    
    my $tmp = sprintf("custom/template-%02d-simple.tmpl", $Organization);
    $MainTmplName = $tmp if( -f "$TemplatePath/$tmp" );

    $tmp = sprintf("custom/template-%02d-advanced.tmpl", $Organization);
    $SubTmplName = $tmp if( -f "$TemplatePath/$tmp" );

    if( lc($Template) eq 'druck')
    {
	$MainTmplName = "print.tmpl";
    }

    my $MainTmpl = HTML::Template->new(filename => "$TemplatePath/$MainTmplName",
				       die_on_bad_params => 0);

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
			'Place' => HTMLFilter($DateObj->getPlace, $Template),
			'Desc' => HTMLFilter($DateObj->getDesc, $Template) }; #,
#			'eMail' => $OrgList{ $DateObj->getOrgID }->[1],
#			'Website' => $OrgList{ $DateObj->getOrgID }->[2] };

	$HashRef->{'Org'} = $OrgName unless( $Intern );

	if( $DateObj->getDate ne $LastDate )
	{
	    $HashRef->{'Date'} = $DateObj->getDate->getDateStr;
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

    $MainTmpl->param( 'Intern' => $Intern );
    $MainTmpl->param( 'Vereinsname' => getOrgName($Organization) ) if $Intern;
    $MainTmpl->param( 'VereinsID' => $Organization ) if $Intern;
    $MainTmpl->param( 'Terminliste' => $SubTmpl->output );

# Ausgabe
    print "Content-type: text/html\n\n";
    print $MainTmpl->output;
}
