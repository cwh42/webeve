ALTER TABLE `chofmann`.`OrgPrefs` MODIFY COLUMN `PrefType` VARCHAR(20) NOT NULL, MODIFY COLUMN `PrefValue` VARCHAR(10000);

UPDATE OrgPrefs O SET PrefType = (SELECT TypeName FROM OrgPrefTypes WHERE TypeID = O.PrefType);

