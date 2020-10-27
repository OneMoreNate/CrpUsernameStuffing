# CrpUsernameStuffing
PS Script to stuff usernames into NPS Connection Request Policies

Version 2.5 released 10/25
-Updated user string regex syntax

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
 -The Connection Request Policy name that is used CANNOT have spaces or special characters in the name.  Must be alphanumeric.

<b>How to use:<br></b>
 -Define the name of the Connection Request Policy ($CrpName). This is the name you gave the CRP in NPS.<br>
 -Create the directory C:\NPS (or define another path in the script, $RootFilePath)<br>
 -Define the AD Group(s) ($Groups)<br>
 -Run script manually to test, then it's recommended you set up a scheduled task to run periodically<br>
 
<b>Running:<br></b>
-When the script runs it will create two output files.  One is a backup of the original configuration file (XML), the
other is a text file listing all the members that were exported from the group(s) and added to the condition.<br>
-The script will keep 30 days of backup XML/TXT files AFTER the -WhatIf switch is removed (bottom of script).  You can change this by hanging the $DaysToKeep value.<br>

<b>Known limitations:<br></b>
-The User Name field in the NPS MMC has a 256 character limit.  If this is exceeded, then when the field is opened 
through the GUI it will appear empty.  However, you will still see a partial listing when the CRP is highlighted 
in the MMC.  The only way to see the entire list is through the TXT or XML files this script generates.<br>
-Get-ADGroupMember has a limit of 5000 objects it can return, this includes nested groups.  If that is exceeded 
then the cmdlet fails and no users are returned, clearing out the variable.  This means the policy condition will be empty!  
Ensure no group(s) that total more than 5000 members, all together, are used. If you have larger groups, then the Get-ADGroupMember will 
not work and you will need to use something like a Get-ADUser -LDAPFilter query for the DN of your Group(s).<br>

<b>Errors:<br></b>
-If you see "The property '#text' cannot be found on this object. Verify that the property exists and can be set." then the
policy name you have set does not have a User Name condition added as a condition<br>

<b>REGEX Syntax</b>
-The script was updated to prepend the username with a ^ and append with a $ to ensure exact username matching.  Without these symbols it will perform a lazy match.  So if you just used a pipe symbol (logical OR) between the usernames it would match "smithb" to "smithb" and "smithbob" and "smithbarry".  So the additional REGEX syntax prevents this lazy match.  However you can customize your syntax in the script by following this excellent article on the use of REGEX:
https://medium.com/factory-mind/regex-tutorial-a-simple-cheatsheet-by-examples-649dc1c3f285
