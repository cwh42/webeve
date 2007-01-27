#!/usr/bin/perl -w

# $Id$

use strict;
use WebEve::WebEveApp;
use CGI::Carp qw(fatalsToBrowser set_message);

set_message('<hr><b>Hierbei handelt es sich vermutlich um einen Programmfehler.<br>'.
	    'Bitte schicke die Meldung oberhalb der Linie an mich (<a href="mailto:ch@goessenreuth.de">'.
	    'ch@goessenreuth.de</a>), damit ich den Fehler beheben kann.</b>');

my $app = WebEve::WebEveApp->new();

$app->run();
