-- $Id$
--
-- MySQL dump 8.22
--
-- Host: venus.bnbt.de    Database: chofmann
---------------------------------------------------------
-- Server version	3.23.54

--
-- Table structure for table 'Dates'
--

CREATE TABLE Dates (
  EntryID int(10) unsigned NOT NULL auto_increment,
  Date date NOT NULL default '0000-00-00',
  Time time default NULL,
  Place varchar(127) default NULL,
  Description text NOT NULL,
  UserID int(10) unsigned NOT NULL default '0',
  OrgID int(10) unsigned NOT NULL default '0',
  Public tinyint(1) unsigned default '0',
  LastChange timestamp(14) NOT NULL,
  PRIMARY KEY  (EntryID)
) TYPE=MyISAM;

--
-- Dumping data for table 'Dates'
--


INSERT INTO Dates VALUES (1,'2010-01-01','00:00:00','At home','A first Date',1,1,1,20030101000000);

--
-- Table structure for table 'Logins'
--

CREATE TABLE Logins (
  SessionID char(50) NOT NULL default '',
  UserID int(10) unsigned NOT NULL default '0',
  Expires timestamp(14) NOT NULL,
  PRIMARY KEY  (SessionID)
) TYPE=MyISAM;

--
-- Table structure for table 'Org_User'
--

CREATE TABLE Org_User (
  OrgID int(10) unsigned NOT NULL default '0',
  UserID int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (OrgID,UserID)
) TYPE=MyISAM;

--
-- Dumping data for table 'Org_User'
--


INSERT INTO Org_User VALUES (1,1);

--
-- Table structure for table 'Organization'
--

CREATE TABLE Organization (
  OrgID int(10) unsigned NOT NULL auto_increment,
  OrgName varchar(127) NOT NULL default '',
  eMail varchar(127) default NULL,
  Website varchar(127) NOT NULL default '',
  PRIMARY KEY  (OrgID)
) TYPE=MyISAM;

--
-- Dumping data for table 'Organization'
--


INSERT INTO Organization VALUES (1,'-unbekannt-','','');

--
-- Table structure for table 'User'
--

CREATE TABLE User (
  UserID int(10) unsigned NOT NULL auto_increment,
  FullName varchar(127) NOT NULL default '',
  eMail varchar(127) default NULL,
  UserName varchar(24) NOT NULL default '',
  Password varchar(16) default NULL,
  isAdmin tinyint(1) unsigned NOT NULL default '0',
  LastLogin datetime default NULL,
  PRIMARY KEY  (UserID)
) TYPE=MyISAM;

--
-- Dumping data for table 'User'
--
-- password is 'default'


INSERT INTO User VALUES (1,'Administrator','admin@host.org','admin','0a1838273cbc9961',1,NULL);
