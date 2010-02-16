#!/usr/bin/perl

#########################################################################
# $Id$
# (c)1999-2010 C.Hofmann cwh@webeve.de                                  #
#########################################################################

use warnings;
use strict;
use Encode qw(from_to);
use CGI;
use HTML::Template;
use WebEve::View;
use WebEve::Config;

main();

sub HTMLify($)
{
    my ( $string ) = @_;

    $string =~ s/\n/<br>/g;

    return $string;
}

sub main
{
    my $MainTmplName = "kalender.tmpl";

    my $query = new CGI;
    my $Template = $query->param('Ansicht') || ''; 
    my $OrgID = $query->param('Verein') || $query->param('Org') || 0;
    my $Org = WebEve::cOrg->new(OrgID => $OrgID);
    my $Intern = $query->param('Intern') || 0; 
    $Intern = 0 if !$OrgID; 

    my $Url = $Intern ?
	getOrgPref($Org, 'script-url-int') || '' :
	$Org->getPref('script-url') || '';

    my $MainTmpl = HTML::Template->new(filename => "$TemplatePath/$MainTmplName",
				       die_on_bad_params => 0);

    my $title = $Org->getPref('title');
    $title = $Org unless(defined($title));
    $title = 'WebEve Eventkalender' if($Intern);
    my $css = $Org->getPref('css');
    my $charset = $Org->getPref('charset') || 'UTF-8';

    $MainTmpl->param( 'title' => $title );
    $MainTmpl->param( 'css' => $css );
    $MainTmpl->param( 'eventlist' => CalendarHTML($Url) );

    my $output = $MainTmpl->output;

    unless( $charset =~ /utf(-*)8/i )
    {
	#print STDERR "recoding output to $charset\n";
	from_to($output, "utf8", $charset);
    }

    print $query->header( -charset => $charset );
    print $output;
}
