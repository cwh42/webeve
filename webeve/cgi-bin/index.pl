#!/usr/bin/perl -w

use strict;
use WebEve::Config;
use WebEve::View;
use CGI;
use HTML::Template;
use Data::Dumper;
use File::Basename;

main();

sub main
{
    my $include_path = "../include/";

    my $cgi = CGI->new();
    my $tmpl = HTML::Template->new( filename => "$TemplatePath/index.tmpl" );

    my @Menu = ( { Title => 'Startseite', RunMode => 'start' },
		 { Title => 'Über Webeve', RunMode => 'about' },
		 #{ Title => 'Termine verwalten', RunMode => 'manage' },
		 { Title => 'Impressum & Kontakt', RunMode => 'contact' } );

    my $mode = $cgi->param('mode');
    $mode = 'start' unless( scalar( grep { $_->{RunMode} eq $mode } @Menu ) );

    my $content = '';

    if( $mode eq 'start' )
    {
	$content = CalendarHTML(basename($0));
    }
    else
    {
	open( IN, "<$include_path/$mode.inc");
	while( my $ln = <IN> )
	{
	    $content .= $ln;
	}
	close( IN );
    }
    $tmpl->param( content => $content );

    my $menu = NavMenuCleanup( \@Menu);
    $tmpl->param( menu => $menu );

    my $cookie = $cgi->cookie(-name=>'WebEveCookieTest',
                              -value=>'Cookies_enabled');

    print $cgi->header( -charset => 'UTF-8',
                        -cookie => $cookie );
    print $tmpl->output();
}

sub NavMenuCleanup
{
    my $Entries = shift;
    my @Result = ();

    my $FileName = basename( $0 );
    my $rm = '';

    foreach my $Entry (@$Entries)
    {
        my $Admin = delete( $Entry->{'Admin'} );
        my $RunMode = delete( $Entry->{'RunMode'} );

        if( 1 )
        {
            if( exists( $Entry->{'SubLevel'} ) && $Entry->{'SubLevel'} )
            {
                my $tmp = NavMenuCleanup( $Entry->{'SubLevel'} );
                $Entry->{'SubLevel'} = $tmp;
            }

            if( $RunMode && $RunMode eq $rm )
            {
                $Entry->{'Current'} = 1;
            }
            else
            {
                $Entry->{'Current'} = 0;
            }

            $Entry->{'FileName'} = "$FileName?mode=$RunMode" unless( $Entry->{'FileName'} ) ;

            push( @Result, $Entry );
        }
    }

    return \@Result;
}

