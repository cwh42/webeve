#!/usr/bin/perl

#########################################################################
# kalender.pl                                              22. Apr 2002 #
# (c)1999-2002 C.Hofmann tr1138@bnbt.de                                 #
#########################################################################

use strict;
use CGI;
use HTML::Template;
use Date::Calc qw( Today Language Month_to_Text Day_of_Week_to_Text Day_of_Week );
use WebEve::mysql;
use WebEve::termine;
use WebEve::Config;

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

sub main
{
    my $ContentType = "text/html";
    my $MainTmplName = "kalender.tmpl";
    my $SubTmplName = "kalender-table.tmpl";

    my $query = new CGI;

    my $Intern = $query->param('Intern') || 0; 
    my $Template = $query->param('Ansicht') || ''; 
    my $Organization = $query->param('Verein'); 
    $Organization = $query->param('Org') || '1' if ! $Organization; 
    my $Page = $query->param('Seite') || '1'; 
    
    my $tmp = sprintf("custom/template-%02d-simple.tmpl", $Organization);
    $MainTmplName = $tmp if( -f "$BasePath/$tmp" );

    $tmp = sprintf("custom/template-%02d-advanced.tmpl", $Organization);
    $SubTmplName = $tmp if( -f "$BasePath/$tmp" );

    if( lc($Template) eq 'druck')
    {
	$MainTmplName = "print.tmpl";
    }
    elsif( lc($Template) eq 'wap')
    {
	$ContentType = "text/vnd.wap.wml";
	$MainTmplName = "wap.tmpl";
    }
    elsif( lc($Template) eq 'csv')
    {
	$ContentType = "text/plain";
	$MainTmplName = "csv.tmpl";
    }

    my $MainTmpl = HTML::Template->new(filename => "$BasePath/$MainTmplName",
				       die_on_bad_params => 0);

    my $SubTmpl = HTML::Template->new(filename => "$BasePath/$SubTmplName",
				      die_on_bad_params => 0,
				       loop_context_vars => 1);
    my %OrgList = getAllOrgs();

    my %Dates = getDates( 'PerPage' => 15,
			  'Page' => $Page,
			  'PublicOnly' => !$Intern,
			  'ForOrgID' => $Intern ? $Organization : 0 );

    # Seitenumschalter
    # -----------------------------------------------------------------------
    my @PageSwitch = ();

    my $Format = "kalender.pl?Seite=%d&Verein=$Organization";
    $Format .= "&Intern=Intern" if $Intern;

    for( my $i = 1; $i <= $Dates{'Pages'}; $i++)
    {
	my $HashRef = { 'Page' => $i };
	$HashRef->{'PageURL'} = sprintf($Format, $i) if $i != $Page; 
	$HashRef->{'IsCurrent'} = 1 if $i == $Page; 

	push( @PageSwitch, $HashRef );
    }
    
    $SubTmpl->param( 'Pages' => \@PageSwitch ) if $Dates{'Pages'} > 1;
    $SubTmpl->param( 'NextPage' => $Page + 1 ) if $Page < $Dates{'Pages'};
    $SubTmpl->param( 'NextPageURL' => sprintf($Format, $Page + 1) ) if $Page < $Dates{'Pages'};
    $SubTmpl->param( 'PrevPage' => $Page - 1 ) if $Page > 1;
    $SubTmpl->param( 'PrevPageURL' => sprintf($Format, $Page - 1) ) if $Page > 1;
    $SubTmpl->param( 'PageCount' => $Dates{'Pages'} );
    $SubTmpl->param( 'CurrentPage' => $Page );
    
    # -----------------------------------------------------------------------

    Language(3);
    my ($year, $month, $day) = Today();
    my $Today = sprintf( "%.2s, %02d.%.02d.%d",
			 Day_of_Week_to_Text(Day_of_Week($year,$month,$day)),
			 $day,
			 $month,
			 $year );

    # Terminliste
    # -----------------------------------------------------------------------
    my $LastDate = '';
    my $LastMonth = 0;
    my $LastYear = 0;
    my $LastWasNextWeek = 0;

    my @TodayDates = ( { 'Header' => "Heute - $Today" } );
    my @NextWeekDates = ( { 'Header' => "In den nächsten 7 Tagen" } );
    my @OtherDates = ();

    foreach my $DateObj ( @{$Dates{'Dates'}} )
    {
	my $OrgName = $OrgList{ $DateObj->getOrgID }->[0];
	$OrgName = '' if $OrgName eq '-unbekannt-';

	my $HashRef = { 'Time' => $DateObj->getTime,
			'Place' => HTMLFilter($DateObj->getPlace, $Template),
			'Desc' => HTMLFilter($DateObj->getDesc, $Template),
			'eMail' => $OrgList{ $DateObj->getOrgID }->[1],
			'Website' => $OrgList{ $DateObj->getOrgID }->[2] };

	$HashRef->{'Org'} = $OrgName unless( $Intern );

	if( $DateObj->getDate ne $LastDate )
	{
	    $HashRef->{'Date'} = $DateObj->getDate;
	    $LastDate = $DateObj->getDate;
	}

	if( $DateObj->isToday )
	{
	    push( @TodayDates, $HashRef );
	}
	elsif( $DateObj->isNextWeek )
	{
	    push( @NextWeekDates, $HashRef );
	}
	else
	{
	    if( $DateObj->getMonth != $LastMonth || $DateObj->getYear != $LastYear )
	    {
		my $TextMonth = Month_to_Text( $DateObj->getMonth );
		push( @OtherDates, { 'Header' => "$TextMonth ".$DateObj->getYear } );
		
		$LastMonth = $DateObj->getMonth;
		$LastYear =  $DateObj->getYear;
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
    print "Content-type: $ContentType\n\n";
    print $MainTmpl->output;
}
