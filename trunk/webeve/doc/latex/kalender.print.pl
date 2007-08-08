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
    if( $Type eq 'latex' )
    {
	$String =~ s/<br>/ /isg;
	$String =~ s/\n/ /sg;
	$String =~ s/\r//sg;
	$String =~ s/<.*?>//sg;
	$String =~ s/\"//sg;
    }

    return $String;
}

sub main
{
    my $ContentType = "text/html";
    my $MainTmplName = "kalender2.tex.tmpl";

    my $Intern = 0;
    my $Template = 'latex';
    my $Organization = 1;
    my $Page = 1; 

    my $MainTmpl = HTML::Template->new(filename => "$MainTmplName",
				       die_on_bad_params => 0,
				       loop_context_vars => 1);
    my %OrgList = getAllOrgs();

    my %Dates = getDates( 'PublicOnly' => !$Intern,
			  'ForOrgID' => $Intern ? $Organization : 0 );

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

    my @OtherDates = ();
    my $HeaderCount = 0;

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
	$HashRef->{'Date'} = $DateObj->getDate;

	if( $DateObj->getMonth != $LastMonth || $DateObj->getYear != $LastYear )
	{
	    my $TextMonth = Month_to_Text( $DateObj->getMonth );
	    push( @OtherDates, { 'Header' => "$TextMonth ".$DateObj->getYear,
				 'NewPage' => (($HeaderCount++ % 3) == 0)} );

	    $LastMonth = $DateObj->getMonth;
	    $LastYear =  $DateObj->getYear;
	}
	
	push( @OtherDates, $HashRef );
    }

    my @DateList = ();

    push( @DateList, @OtherDates);

    $MainTmpl->param('Dates' => \@DateList );

    $MainTmpl->param( 'Today' => $Today );
    $MainTmpl->param( 'Intern' => $Intern );
    $MainTmpl->param( 'Vereinsname' => getOrgName($Organization) ) if $Intern;
    $MainTmpl->param( 'VereinsID' => $Organization ) if $Intern;

    print $MainTmpl->output;
}
