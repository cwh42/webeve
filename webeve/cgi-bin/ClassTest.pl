#!/usr/bin/perl -w

use WebEve::cDate;
use WebEve::cEvent;

$o = WebEve::cDate->new( '12' );

print "STR:".$o->getDateStr."\n";
print "OVR:".$o->isOver."\n";
print "TOD:".$o->isToday."\n";
print "NWK:".$o->isNextWeek."\n";
print "DAY:".$o->getDay."\n";
print "MON:".$o->getMonth."\n";
print "YEA:".$o->getYear."\n";
print "DAT:".join('-', $o->getDate)."\n";


$Event = WebEve::cEvent->newFromDB( 310 );

print "Date:".$Event->getDate->getDateStr."\n";
print "ValidDate:".$Event->getDate->isValid."\n";
print "Time:".$Event->getTime."\n";
print "Place:".$Event->getPlace."\n";
print "Desc:".$Event->getDesc."\n";
print "isPublic:".$Event->isPublic."\n";

print "Org:".$Event->getOrg."\n";
print $Event->setOrgID(14)."\n";
print "Org:".$Event->getOrg."\n";

print "isPublic:".$Event->isPublic."\n";
print $Event->setIsPublic(0)."\n";
print "isPublic:".$Event->isPublic."\n";
