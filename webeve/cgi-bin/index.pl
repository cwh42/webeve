#!/usr/bin/perl -w

use strict;
use WebEve::Config;
use WebEve::cBase;
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
    my $webeve = WebEve::cBase->new();
    my $user = $webeve->getUser();

    my $tmpl = HTML::Template->new( filename => "$TemplatePath/main.tmpl" );

    my @Menu = ( { Title => 'Startseite', RunMode => 'start' },
		 { Title => 'Über Webeve', RunMode => 'about' } );
    push( @Menu, { Title => 'Termine verwalten', RunMode => 'manage' } ) if( $user->{UserName} );
    push( @Menu, { Title => 'Impressum & Disclaimer', RunMode => 'contact' } );

    my $mode = $cgi->param('mode');
    $mode = 'start' unless( scalar( grep { $_->{RunMode} eq $mode } @Menu ) );

    my $content = '';

    if( $mode eq 'start' )
    {
	$content = CalendarHTML(basename($0));
    }
    elsif( $mode eq 'manage' )
    {
        print $cgi->redirect( 'webeve.pl' );
        exit(0);
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

    # NavMenuCleanup has to be called as late as possible because it destroys @Menu
    my $menu = NavMenuCleanup( \@Menu);

    $tmpl->param( content => $content,
                  UserName => $user->{UserName},
                  FullName => $user->{FullName},
                  isAdmin => $user->{isAdmin},
                  menu => $menu );

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

