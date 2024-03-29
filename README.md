# CrpUsernameStuffing
<b>PS Script to stuff usernames into NPS Connection Request Policies</b>

<b>Version 2.8 release 07/27/23</b><br>
- added comments on line 68 and 96 of the script on how to run this script without embedding credentials in the script<br>
Version 2.7 release 11/2/22<br>
- adds function to stuffs both UPNs and samAccountNames<br>
Version 2.6 released 10/25/2022<br>
- Added a second function used to pull and populate UserPrincipalNames<br>
Version 2.5.1 released 10/23/2022<br>
- Added documentation on Connection Request Policy names and the use of special characters, such as the umlaut.<br>
Version 2.5 released 10/22/2020<br>
- Updated user string regex syntax (see bottom for details)<br>

<b>Tutorial: https://youtu.be/7be2yuOwUHs</b><br>

<b>What does the script do?</b><br>
This is a script used to populate a pre-defined NPS Connection Request Policy(CRP) with the samAccountNames 
of the members of the specified AD Group. If you wanted to use UPNs instead, you can see the examples below 
where the UPNs are pulled as well.  So tailor this to your environment.

The purpose of the script is to work around the CRP's inability to inspect group membership as a condition.  Also, 
when the MFA Extension is installed on the NPS server, the NPS is unable to send back user defined attributes
to the RADIUS clients when the users Auth Method requires the use of a One Time Passcode(OTP), such as SMS, 
Authenticator App Passcode or Hardware FOB.
 
The script will enumerate all the members of the defined Active Directory Groups from the defined Domains and 
populate the defined CRPs ($CrpName) with those members samAccountNames.  Each samaccountname is separated with a 
logical OR (|) value between each, allowing for the inspection of multiple usernames.  It is recommended that you 
setup AD Groups for this specific purpose, for ease of management.

When the script updates the User Name condition, it will add a timestamp as the first entry so that you can easily
tell, by looking at the CRP summary, when the last time the script successfully ran.

<b>Prerequisites:<br></b>
 -Must be run from a machine with the Active Directory cmdlets.  You can get the Active Directory module by installing
The "AD DS and AD LDS Tools" under the Remote Server Administration Tools/Role Administration Tools feature on the server.<br>
 -The Connection Request Policy name that is used CANNOT have spaces or special characters in the name.  Must be alphanumeric.<br>
 -A folder called "Archive" must be in the path you define in the first line of the script.<br>

<b>How to use:<br></b>
 -Define the name of the Connection Request Policy ($CrpName). This is the name you gave the CRP in NPS.<br>
 -Create the directory C:\NPS (or define another path in the script, $RootFilePath)<br>
 -Define the AD Group(s) ($Groups)<br>
 -Run script manually to test, then it's recommended you set up a scheduled task to run periodically<br>
 
<b>Running:<br></b>
-When the script runs it will create two output files.  One is a backup of the original configuration file (XML), the
other is a text file listing all the members that were exported from the group(s) and added to the condition.<br>
-The script will keep 30 days of backup XML/TXT files AFTER the -WhatIf switch is removed (bottom of script).  You can change this by changing the $DaysToKeep value.<br>

<b>Known limitations:<br></b>
-The User Name field in the NPS MMC has a 256 character limit.  If this is exceeded, then when the field is opened 
through the GUI it will appear empty.  However, you will still see a partial listing when the CRP is highlighted 
in the MMC.  The only way to see the entire list is through the TXT or XML files this script generates.<br>
-Get-ADGroupMember has a limit of 5000 objects it can return, this includes nested groups.  If that is exceeded 
then the cmdlet fails and no users are returned, clearing out the variable.  This means the policy condition will be empty!  
Ensure no group(s) that total more than 5000 members, all together, are used. If you have larger groups, then the Get-ADGroupMember will 
not work and you will need to use something like a Get-ADUser -LDAPFilter query for the DN of your Group(s).<br>
-The name of the Connection Request Policies cannot contain "User-Name" or "Benutzer-Auth"(German), and likely any other 
localized iteration of "User-Name".  This will cause the script to fail to find the child node with the text value, 
and you will the error listed below.<br>
-The use of special characters, such as ones with an umlaut, can result in exports that grow exponentially in size.  It appears that the programmatic export
process doesn't handle these characters well and you end up with long strings of strange characters that get imported and added to upon the next export.  So avoid special
characters in the names of the policies.  This includes the Network Policies as they are exported at the same time. <br>

<b>Errors:<br></b>
-If you see "The property '#text' cannot be found on this object. Verify that the property exists and can be set." then the
policy name you have set does not have a UserName condition added as a condition.  You must add the UserName condition with any string initially (IE: test) before the script can update the condition with the user names.<br>

<b>REGEX Syntax</b><br>
-The script was updated to prepend the username with a ^ and append with a $ to ensure exact username matching.  Without these symbols it will perform a "begins with" match.  So if you just used a pipe symbol (logical OR) between the usernames it would match "smithb" to "smithb" and "smithbob" and "smithbarry".  So the additional REGEX syntax prevents this type of matching.  However you can customize your syntax in the script by following this excellent article on the use of REGEX:<br>
https://medium.com/factory-mind/regex-tutorial-a-simple-cheatsheet-by-examples-649dc1c3f285

Tracking hits as of 4/6/21<br>
[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2FOneMoreNate%2FCrpUsernameStuffing&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)
