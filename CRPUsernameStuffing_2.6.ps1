# Version 2.6 10/25/2022
# Author: Nate Harris (nathar@microsoft.com) with help from Clayton Seymour (clayse@microsoft.com).
# 
# Changelog
# -2.6 adds a second function to set UserPrincipalNames instead of samAccountNames
# -2.5.1 updated known limitations documentation to avoid "User-Name" or "Benutzer-Auth" (or other localized iterations thereof) in the names of the Connection Request Policies as this will prevent the script from being
#  able to update the CRP since this string is part of the name of the condition of the CRP itself
#
# What does the script do?
# This is a script used to populate a pre-defined NPS Connection Request Policy(CRP) with the samAccountNames, or UserPrincipalNames, of the members of the specified AD Group(s).
#
# The purpose of the script is to work around the CRP's inability to inspect group membership as a condition.  Also, when the MFA Extension is installed on the NPS server, the NPS is unable to send back user defined 
# attributes from the Network Policies to the RADIUS clients when the users Authentication Method requires the use of a One Time Passcode(OTP), such as SMS, Authenticator App Passcode or Hardware FOB.
# 
# The script will enumerate all the members of the defined Group(s) and populate the defined CRP ($CrpName) with those members samAccountNames, or UserPrincipalNames, adding RegEx values (^ and $) before and after to insure
# exact matching, and then adding logical OR (|) value between each name.
#
# When the script updates the User Name condition, it will add a timestamp as the first entry so that you can easily tell when the last time the script successfully ran.  The timestamp is in the format of YYYYDDMM_hhmmss.
#
# Prerequisites:
# -Must be run from a machine with the Active Directory cmdlets.  You can get the Active Directory module by installing The Active Directory tools "AD DS and AD LDS Tools" under the Remote Server Administration Tools/Role 
#  Administration Tools feature on the server.
# -The Connection Request Policy name that is used CANNOT have spaces or special characters in the name.  Must be alphanumeric.
# -You must create the "Archive" folder in the path you specify in the first line of the script below.
#
# How to use:
# -Define the name of the Connection Request Policy ($CrpName). This is the name you gave the CRP in NPS.
# -Create the directory C:\NPS (or define another path in the script, $RootFilePath)
# -Define the AD Group(s) ($Groups)
# -Run script manually to test, then it's recommended you set up a scheduled task to run periodically
# 
# Running:
# -When the script runs it will create two output files.  One is a backup of the original configuration file (XML), the other is a text file listing all the members that were exported from the group(s) and added to the condition.
# -The script will keep 30 days of backup XML/TXT files AFTER the -WhatIf switch is removed (bottom of script).  You can change this by changing the $DaysToKeep value.
#
# Known limitations:
# -The User Name field in the NPS MMC has a 256 character limit.  If this is exceeded, then when the field is opened through the GUI it will appear empty.  However, you will still see a partial listing when the CRP is highlighted
#  in the MMC.  The only way to see the entire list is through the TXT or XML files this script generates.
# -Get-ADGroupMember has a limit of 5000 objects it can return, this includes nested groups.  If that is exceeded then the cmdlet fails and no users are returned, clearing out the variable.  This means the policy condition will
#  be empty!  Ensure no group(s) that total more than 5000 members, all together, are used. If you have larger groups, then the Get-ADGroupMember will not work and you will need to use something like a Get-ADUser -LDAPFilter 
#  query for the DN of your Group(s).
# -The name of the Connection Request Policies cannot contain "User-Name" or "Benutzer-Auth", and likely any other localized iteration of "User-Name".  This will cause the script to fail to find the child node with the text 
#  value, and you will the error listed below.
# -The name of the Connection Request Policies or the Network Policies cannot contain special characters as this will cause the NPS Cofiguration export to bloat and grow exponentially.  Characters such as the German umlaut will
#  cause the export function of the PowerShell cmdlet to insert a seemingly random string of characters where the umlaut exists in the name withint the XML file.  As the configuration is imported and re-exported, these characters
#  will still exist in the config, but not be visible in the GUI, and each export will insert more random characters where the special character exists.  The result is an export file that can grow exponentially and consume a drives
#  entire free space.
#
# Errors:
# -If you see "The property '#text' cannot be found on this object. Verify that the property exists and can be set." then the policy name you have set does not have a User Name condition added as a condition

$RootFilePath="c:\NPS\" #You can use any path you prefer here.  Be sure to create the "Archive" folder in this path as well.
$Timestamp = "$((Get-Date).ToString("yyyyMMdd_HHmmss"))"
$MembersTxtFile = $RootFilePath + $Timestamp + "_Usernames.txt"
$NpsCfgFile = [System.Net.Dns]::GetHostName() + "_NpsCfg.xml"
$MemberList = $Timestamp
$ExportFilePath = $RootFilePath + $NpsCfgFile
$CfgFileBackup = $RootFilePath + "$((Get-Date).ToString("yyyyMMdd_HHmmss"))_" + $NpsCfgFile
Export-NpsConfiguration -Path $ExportFilePath
Copy-Item $ExportFilePath $CfgFileBackup

Function Start-GetUsernames {
    foreach ($Group in $Groups){ 
    $members = Get-ADGroupMember -Identity $Group -Server $Domain -Credential $DomainCreds -Recursive|Get-ADUser -Properties displayname, samaccountname|Sort-Object -Property displayname|Select-Object DisplayName, samAccountName
    $members | foreach{ 
      $member = $_.samaccountname
      $memberlist = $memberlist + "|^" + $member + "$"
     }
    "Domain: " + $Domain | Out-File -Append $MembersTxtFile -NoClobber 
    "Group name: " + $Group | Out-File -Append $MembersTxtFile -NoClobber
    $members | Out-File -Append $MembersTxtFile -NoClobber
    }
    "Condition added to CRP named '" + $CrpName + "':" | Out-File -Append $MembersTxtFile -NoClobber
    $memberlist | Out-File -Append $MembersTxtFile -NoClobber
    " " |Out-File -Append $MembersTxtFile -NoClobber
    " " |Out-File -Append $MembersTxtFile -NoClobber
    " " |Out-File -Append $MembersTxtFile -NoClobber

    $NpsXml=[xml](Get-Content $ExportFilePath)
    $UsernameNode = $NpsXml.SelectSingleNode("//Root/Children/Microsoft_Internet_Authentication_Service/Children/Proxy_Policies/Children/$CrpName/Properties/msNPConstraint[(contains(text(),'MATCH'))]") 
    $UsernameNode.'#text' = 'MATCH("User-Name='+$memberlist+'")'
    $NPSxml.Save($ExportFilePath)
    Import-NpsConfiguration -Path $ExportFilePath
$limit = (Get-Date).AddDays($DaysToKeep).Date
}

Function Start-GetUPNs {
    foreach ($Group in $Groups){ 
    $members = Get-ADGroupMember -Identity $Group -Server $Domain -Credential $DomainCreds -Recursive|Get-ADUser -Properties displayname, userPrincipalName|Sort-Object -Property displayname|Select-Object DisplayName, userPrincipalName
    $members | foreach{ 
      $member = $_.userPrincipalName
      $memberlist = $memberlist + "|^" + $member + "$"
     }
    "Domain: " + $Domain | Out-File -Append $MembersTxtFile -NoClobber 
    "Group name: " + $Group | Out-File -Append $MembersTxtFile -NoClobber
    $members | Out-File -Append $MembersTxtFile -NoClobber
    }
    "Condition added to CRP named '" + $CrpName + "':" | Out-File -Append $MembersTxtFile -NoClobber
    $memberlist | Out-File -Append $MembersTxtFile -NoClobber
    " " |Out-File -Append $MembersTxtFile -NoClobber
    " " |Out-File -Append $MembersTxtFile -NoClobber
    " " |Out-File -Append $MembersTxtFile -NoClobber

    $NpsXml=[xml](Get-Content $ExportFilePath)
    $UsernameNode = $NpsXml.SelectSingleNode("//Root/Children/Microsoft_Internet_Authentication_Service/Children/Proxy_Policies/Children/$CrpName/Properties/msNPConstraint[(contains(text(),'MATCH'))]") 
    $UsernameNode.'#text' = 'MATCH("User-Name='+$memberlist+'")'
    $NPSxml.Save($ExportFilePath)
    Import-NpsConfiguration -Path $ExportFilePath
$limit = (Get-Date).AddDays($DaysToKeep).Date
}

#Domain or Policy 1
$CrpName = "Nathar2016Users"
$Domain = "nathar2016.lab"
$DomainUserName = "nathar2016\bob.smith"
$DomainPassword = "ThePassword!"
$EncryptedPassword = ConvertTo-SecureString -String $DomainPassword -AsPlainText -Force
$DomainCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainUserName, $EncryptedPassword
#$Groups = @("UsernameGroup3", "Domain Admins")
$Groups = @("VPN-ElevatedAccess")
Start-GetUsernames

#Domain or Policy 2
$CrpName = "NateHarrisAzureUsers"
$Domain = "nateharris.azure"
$DomainUserName = "nateharrisazure\sally.smith"
$DomainPassword = "ThePassword!"
$EncryptedPassword = ConvertTo-SecureString -String $DomainPassword -AsPlainText -Force
$DomainCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainUserName, $EncryptedPassword
#$Groups = @("UsernameGroup3", "Domain Admins")
$Groups = @("VPN-Users")
Start-GetUPNs

$DaysToKeep = -7 #this will keep 7 days of files.  You may want to consider raising this value, just remember if you run it every hour, that's 48 files created every day, for example.
$ArchiveLogs = $RootFilePath + "Archive\"
$ArchiveTime = (Get-Date).AddMinutes(-1)
$DeleteTime = (Get-Date).AddDays($DaysToKeep)
Get-ChildItem -Path $RootFilePath -Include *.xml -Exclude $NpsCfgFile -Recurse -Force | Where { $_.CreationTime -lt $ArchiveTime } | Move-Item -Destination $ArchiveLogs
Get-ChildItem -Path $RootFilePath -Include *.txt -Recurse -Force | Where { $_.CreationTime -lt $ArchiveTime } | Move-Item -Destination $ArchiveLogs
Get-ChildItem -Path $ArchiveLogs -Include *.xml -Recurse -Force | Where { $_.CreationTime -lt $DeleteTime } | Remove-Item -Force
Get-ChildItem -Path $ArchiveLogs -Include *.txt -Recurse -Force | Where { $_.CreationTime -lt $DeleteTime } | Remove-Item -Force
