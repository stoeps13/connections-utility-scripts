/*
  Script to create a profile for wasadmin in IBM Connections.

  You need to check the fileRepository.xml of your WebSphere Configuration,
  copy the external id of the local wasadmin and change it in this script.

  I needed this script for CCM, because after some hours accessing CCM wasn't
  possible.

  Call this script with "db2 -tvf insertwasadmin.sql"

  This will not work with Connections 5.5! Columns had changed with 5.5!

  --

  Author: Christoph Stoettner
  E-Mail: christoph.stoettner@stoeps.de
  Date: 2016-01-20

  (c)2016 by Christoph Stoettner

  Licence: Apache License 2.0 (http://www.apache.org/licenses/LICENSE-2.0.html)
 */
connect to peopledb;
insert into  empinst.employee VALUES('00000000-0000-0000-0000-000000000000','wasadmin','wasadmin',CURRENT TIMESTAMP,'','','91f7bf55-12f6-421b-b53a-8c2cb0e8ad9b','uid=wasadmin,o=defaultWIMFileBasedRealm','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','uid=wasadmin,o=defaultwimfilebasedrealm','00000000-0000-0000-0000-040508202233',0,0);
connect reset;
