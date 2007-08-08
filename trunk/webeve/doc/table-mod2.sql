-- MySQL dump 8.22
--
-- Host: localhost    Database: chofmann
---------------------------------------------------------
-- Server version	3.23.55-log

-- Additional changes

ALTER TABLE Dates ADD CatID INT(10) UNSIGNED NOT NULL AFTER Public;

--
-- Table structure for table 'Categories'
--

CREATE TABLE Categories (
  CatID int(10) unsigned NOT NULL auto_increment,
  CatName varchar(30) NOT NULL default '',
  PRIMARY KEY  (CatID)
) TYPE=MyISAM;

--
-- Dumping data for table 'Categories'
--


INSERT INTO Categories VALUES (1,'Fest/Party');
INSERT INTO Categories VALUES (2,'Sport');
INSERT INTO Categories VALUES (3,'Bildung');
INSERT INTO Categories VALUES (4,'Wettbewerb');
INSERT INTO Categories VALUES (5,'Theater');
INSERT INTO Categories VALUES (6,'Versammlung');
INSERT INTO Categories VALUES (7,'Sonstiges');

