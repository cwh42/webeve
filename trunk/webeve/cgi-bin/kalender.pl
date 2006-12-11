#!/usr/bin/perl -w

#########################################################################
# $Id$
# (c)1999-2002 C.Hofmann tr1138@bnbt.de                                 #
#########################################################################

use strict;
use CGI;
use HTML::Template;
use WebEve::View;
use WebEve::Config;
use WebEve::cEventList;
use WebEve::cMySQL;

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
    #WAP: "text/vnd.wap.wml"

    my $query = new CGI;

    my $Template = $query->param('Ansicht') || ''; 
    my $Organization = $query->param('Verein') || $query->param('Org') || 0; 
    my $Intern = $query->param('Intern') || 0; 
    $Intern = 0 if ! $Organization; 

    # my $Embedded = $query->param('Embed') || '0';
    my $Url = $Intern ? (getOrgPref($Organization, 'script-url-int'))[0] || '' :
	(getOrgPref($Organization, 'script-url'))[0] || '';

    # if( $Url && !$Embedded)
    # {
    # 	print $query->redirect($Url);
    # 	exit(0);
    # }
     
    my $tmp = sprintf("custom/template-%02d-simple.tmpl", $Organization);
    $MainTmplName = $tmp if( -f "$TemplatePath/$tmp" );

    if( lc($Template) eq 'druck')
    {
	$MainTmplName = "print.tmpl";
    }

    my $MainTmpl = HTML::Template->new(filename => "$TemplatePath/$MainTmplName",
				       die_on_bad_params => 0);

    $MainTmpl->param( 'Intern' => $Intern );
    $MainTmpl->param( 'Vereinsname' => getOrgName($Organization) ) if $Intern;
    $MainTmpl->param( 'VereinsID' => $Organization ) if $Intern;
    $MainTmpl->param( 'Terminliste' => CalendarHTML($Url) );

    $MainTmpl->param('bgcolor' => getOrgPref($Organization, 'bgcolor'));
    $MainTmpl->param('bgimage' => getOrgPref($Organization, 'bgimage'));
    $MainTmpl->param('textcolor' => getOrgPref($Organization, 'textcolor'));
    $MainTmpl->param('linkcolor' => getOrgPref($Organization, 'linkcolor'));
    $MainTmpl->param('font' => getOrgPref($Organization, 'font'));
    $MainTmpl->param('tl-bgcolor' => getOrgPref($Organization, 'tl-bgcolor'));
    $MainTmpl->param('tl-textcolor' => getOrgPref($Organization, 'tl-textcolor'));

    # Ausgabe
    print "Content-type: text/html\n\n";
    print $MainTmpl->output;
}


# Temporäre Behelfsfunktionen. Müssen durch eine Org-Objetzt erschlagen werden.

sub getOrgPref($$)
{
    my ($OrgID, $PrefType) = @_;

    my $dbh = WebEve::cMySQL->connect('default');
    my $sql = sprintf("SELECT PrefValue FROM OrgPrefs up ".
		      "LEFT JOIN OrgPrefTypes pt ON up.PrefType = pt.TypeID ".
		      "WHERE OrgID = %d AND TypeName = %s",
		      $OrgID || 0,
		      $dbh->quote($PrefType));

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @result = ();

    while( my $row = $sth->fetchrow_arrayref() )
    {
	push( @result, $row->[0] );
    }

    return @result;
}

sub getOrgName($)
{
    my ( $OrgID ) = @_;

    my $dbh = WebEve::cMySQL->connect('default');

    my $sql = "SELECT o.OrgName
                       FROM Organization o
                       WHERE o.OrgID = $OrgID";

    my ($OrgName) = $dbh->selectrow_array($sql);

    return $OrgName;
}
