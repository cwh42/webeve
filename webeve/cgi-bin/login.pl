#!/usr/bin/perl -w

#$Id$

use strict;
use CGI;

# This script has been replaced by 'webeve.pl'.

my $q = new CGI;

print $q->redirect ('webeve.pl');
