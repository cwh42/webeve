--
-- Table structure for table 'OrgPrefTypes'
--

CREATE TABLE OrgPrefTypes (
  TypeID int(10) unsigned NOT NULL auto_increment,
  TypeName varchar(30) NOT NULL default '',
  PRIMARY KEY  (TypeID)
) TYPE=MyISAM;

--
-- Table structure for table 'OrgPrefs'
--

CREATE TABLE OrgPrefs (
  PrefID int(10) unsigned NOT NULL auto_increment,
  OrgID int(10) unsigned NOT NULL default '0',
  PrefType int(10) unsigned NOT NULL default '0',
  PrefValue varchar(100) NOT NULL default '',
  PRIMARY KEY  (PrefID)
) TYPE=MyISAM;

--
-- Table structure for table 'UserPrefTypes'
--

CREATE TABLE UserPrefTypes (
  TypeID int(10) unsigned NOT NULL auto_increment,
  TypeName varchar(30) NOT NULL default '',
  PRIMARY KEY  (TypeID)
) TYPE=MyISAM;

--
-- Table structure for table 'UserPrefs'
--

CREATE TABLE UserPrefs (
  PrefID int(10) unsigned NOT NULL auto_increment,
  UserID int(10) unsigned NOT NULL default '0',
  PrefType int(10) unsigned NOT NULL default '0',
  PrefValue varchar(100) NOT NULL default '',
  PRIMARY KEY  (PrefID)
) TYPE=MyISAM;

