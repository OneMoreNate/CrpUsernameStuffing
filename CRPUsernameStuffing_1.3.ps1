###################################################################################################################
# Version 1.3 06/16/2020
# Author: Nate Harris (nathar@microsoft.com)
# 
# What does the script do?
# This is a script used to populate a pre-defined NPS Connection Request Policy(CRP) with the samAccountNames 
# of the members of the specified AD Group. If you wanted to use UPNs instead, you can see the examples below 
# where the UPNs are pulled as well.  So tailor this to your environment.
#
# The purpose of the script is to work around the CRP's inability to inspect group membership as a condition.  
# Also, when the MFA Extension is installed on the NPS server, the NPS is unable to send back user defined attributes
# to the RADIUS clients when the users Auth Method requires the use of a One Time Passcode(OTP), such as  
# SMS, Authenticator App Passcode or Hardware FOB.
# 
# The script will enumerate all the members of the defined Group(s) and populate the defined CRP ($CrpName)
# with those members samAccountNames adding a logical OR (|) value between each.  It is recommended that you setup 
# AD Groups for this purpose, for ease of management.
#
# When the script updates the User Name condition, it will add a timestamp as the first entry so that you can easily
# tell when the last time the script successfully ran.
#
# Prerequisites:
# -Must be run from a machine with the Active Directory cmdlets.  You can get the Active Directory module by installing
# The "AD DS and AD LDS Tools" under the Remote Server Administration Tools/Role Administration Tools feature on the server.
# -The Connection Request Policy name that is used CANNOT have spaces or special characters in the name.  Must be alphanumeric.
# How to use:
# -Define the name of the Connection Request Policy ($CrpName). This is the name you gave the CRP in NPS.
# -Create the directory C:\NPS (or define another path in the script, $RootFilePath)
# -Define the AD Group(s) ($Groups)
# -Run script manually to test, then it's recommended you set up a scheduled task to run periodically
# 
# Running:
# -When the script runs it will create two output files.  One is a backup of the original configuration file (XML), the
# other is a text file listing all the members that were exported from the group(s) and added to the condition.
#  -The script will keep 30 days of backup XML/TXT files AFTER the -WhatIf switch is removed (bottom of script).  You can change this by changing the $DaysToKeep
# value.
#
# Known limitations:
# -The User Name field in the NPS MMC has a 256 character limit.  If this is exceeded, then when the field is opened 
# through the GUI it will appear empty.  However, you will still see a partial listing when the CRP is highlighted 
# in the MMC.  The only way to see the entire list is through the TXT or XML files this script generates.
# -Get-ADGroupMember has a limit of 5000 objects it can return, this includes nested groups.  If that is exceeded 
# then the cmdlet fails and no users are returned, clearing out the variable.  This means the policy condition will be empty!  
# Ensure no group(s) that total more than 5000 members, all together, are used. If you have larger groups, then the Get-ADGroupMember will 
# not work and you will need to use something like a Get-ADUser -LDAPFilter query for the DN of your Group(s).
#
# Errors:
# -If you see "The property '#text' cannot be found on this object. Verify that the property exists and can be set." then the
# policy name you have set does not have a User Name condition added as a condition
#
###################################################################################################################

#Define Connection Request Policy by it's name
$CrpName = "UsernameCRP"

#Define file path where NPS configuration file(s) will be saved and modified
$RootFilePath="c:\NPS\"

#Define name of the AD Group(s), one or more groups here
#$Groups = @("UsernameGroup3", "Domain Admins")
$Groups = @("Domain Admins")

#Define how many days of files to keep (must be shown as negative number)
$DaysToKeep = -7


$NpsCfgFile = [System.Net.Dns]::GetHostName() + "_NpsCfg.xml"
Export-NpsConfiguration -Path "$RootFilePath $NpsCfgFile"
$Timestamp = "$((Get-Date).ToString("yyyyMMdd_HHmmss"))"
$MemberList = $Timestamp
$ExportFilePath = $RootFilePath + $NpsCfgFile
$CfgFileBackup = $RootFilePath + "$((Get-Date).ToString("yyyyMMdd_HHmmss"))_" + $NpsCfgFile
Export-NpsConfiguration -Path $ExportFilePath
Copy-Item $ExportFilePath $CfgFileBackup
$MembersTxtFile = $RootFilePath + $Timestamp + "_CrpUsernames.txt"


foreach ($Group in $Groups){ 
$members = Get-ADGroupMember $Group -Recursive| 
# You can pull and use other attributes, such as UPN as shown in the commented sections below
#    Get-ADUser -Properties displayname, samaccountname, userPrincipalName |
    Get-ADUser -Properties displayname, samaccountname |
    Sort-Object -Property displayname |
#    Select-Object DisplayName, samAccountName, userPrincipalName
    Select-Object DisplayName, samAccountName

$members | foreach{ 
# If you want to use UPN you would need to change this from $_.samAccountName to $_.userPrincipalName
  $member = $_.samaccountname
  $memberlist = $memberlist + "|" + $member
 } 
$Group | Out-File -Append $MembersTxtFile -NoClobber
$members | Out-File -Append $MembersTxtFile -NoClobber
}
$memberlist | Out-File -Append $MembersTxtFile -NoClobber

$NpsXml=[xml](Get-Content $ExportFilePath)
$UsernameNode = $NpsXml.SelectSingleNode("//Root/Children/Microsoft_Internet_Authentication_Service/Children/Proxy_Policies/Children/$CrpName/Properties/msNPConstraint[(contains(text(),'MATCH'))]") 
$UsernameNode.'#text' = 'MATCH("User-Name='+$memberlist+'")'
$NPSxml.Save($ExportFilePath)
Import-NpsConfiguration -Path $ExportFilePath
$limit = (Get-Date).AddDays($DaysToKeep).Date
Get-ChildItem -Path $RootFilePath -Include *.xml -Recurse -Force | Where { $_.CreationTime -lt $limit } | Remove-Item -Force
Get-ChildItem -Path $RootFilePath -Include *.txt -Recurse -Force | Where { $_.CreationTime -lt $limit } | Remove-Item -Force
