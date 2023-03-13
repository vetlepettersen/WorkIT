# -----1. script for organizational units and groups----- #
# Kjører på MGR

# Definerer hoved-OUs
$workit_users = "WorkIT_Users"
$workit_groups = "WorkIT_Groups"
$workit_computers = "WorkIT_Computers"
$topOUs = @($workit_users,$workit_groups,$workit_computers)

# Definerer departments, samt underdepartments til IT og Sales
$departments = @('ChiefOfficers','IT','Sales','HR')
$it_departments = @('Security','Operation','Development')
$sales_departments = @('Finance','Accounting')

foreach ($ou in $topOUs) {
        # Oppretter hoved-OUs "topOUs" og definerer $topOU for å lette dannelse av path til senere
        New-ADOrganizationalUnit $ou -Description "One of main OU for WorkIT" -ProtectedFromAccidentalDeletion:$false
        $topOU = Get-ADOrganizationalUnit -Filter * | Where-Object {$_.name -eq "$ou"}
                foreach ($department in $departments) {
                        New-ADOrganizationalUnit $department `
                        -Path $topOU.DistinguishedName `
                        -Description "Department OU for $department in topOU $topOU"
                        # Hvert department underlegges hoved-OUene
                        # Bruker if statements, fordi vi må opprette OUs $it_departments, under IT-department
                        if ($department -contains "IT") {
                                $pathvar = "OU=$department," + $topOU.DistinguishedName
                                $this_department = $department
                                foreach ($it_department in $it_departments) {
                                        New-ADOrganizationalUnit $it_department `
                                        -DisplayName "$this_department $it_department" `
                                        -Path "$pathvar" `
                                        -Description "Department under IT, in charge of $it_department"
                                }
                        }
                        # Gjør samme prosess for under-OUene til Sales department
                        if ($department -contains "Sales") {
                                $pathvar = "OU=$department," + $topOU.DistinguishedName
                                $this_department = $department
                                foreach ($sales_department in $sales_departments) {
                                        New-ADOrganizationalUnit $sales_department `
                                        -DisplayName "$this_department $sales_department" `
                                        -Path "$pathvar" `
                                        -Description "Department under Sales, in charge of $sales_department"
                                }
                        }
                }
        # Hvis topOU-en "WorkIT_Groups" matcher topOUene vi looper gjennom, opprettes de fysiske gruppene under hver eneste OU
        if ($ou -eq "WorkIT_Groups") {
                foreach ($department in $departments) {
                        # Opprettelse av grupper til hvert department
                        New-ADGroup `
                        -Name "g_$department" `
                        -SamAccountName "g_$department" `
                        -GroupCategory "Security" `
                        -GroupScope "Global" `
                        -DisplayName "Group $department" `
                        -Path "OU=$department,OU=$ou,DC=core,DC=sec" `
                        -Description "Group containing $department-related matters"
                        # Må ikke glemme under-OUene til IT og Sales :)
                        if ($department -contains "IT") {
                               foreach ($it_department in $it_departments) {
                                        New-ADGroup `
                                        -Name "g_$it_department" `
                                        -SamAccountName "g_$it_department" `
                                        -GroupCategory "Security" `
                                        -GroupScope "Global" `
                                        -DisplayName "Group $it_department" `
                                        -Path "OU=$it_department,OU=$department,OU=$ou,DC=core,DC=sec"
                               }
                        }
                        if ($department -contains "Sales") {
                                foreach ($sales_department in $sales_departments) {
                                        New-ADGroup `
                                        -Name "g_$sales_department" `
                                        -SamAccountName "g_$sales_department" `
                                        -GroupCategory "Security" `
                                        -GroupScope "Global" `
                                        -DisplayName "Group $sales_department" `
                                        -Path "OU=$sales_department,OU=$department,OU=$ou,DC=core,DC=sec"
                                }
                        }
                }
        }
}

# Flytter datamaskinene våre til riktige steder i AD, cl1 går til HR for demostrative årsaker
Move-ADObject `
-Identity "CN=mgr,CN=Computers,DC=core,DC=sec" `
-TargetPath "OU=Operation, OU=IT, OU=WorkIT_Computers,DC=core,DC=sec"

Move-ADObject `
-Identity "CN=srv1,CN=Computers,DC=core,DC=sec" `
-TargetPath "OU=Security, OU=IT, OU=WorkIT_Computers,DC=core,DC=sec"

Move-ADObject `
-Identity "CN=cl1,CN=Computers,DC=core,DC=sec" `
-TargetPath "OU=HR,OU=WorkIT_Computers,DC=core,DC=sec"

# Endrer brannmurinnstillinger på cl1 og srv1 for å tillatte PSSession
 Invoke-Command -ComputerName "srv1" `
     -ScriptBlock {Enable-NetFirewallRule -Name "RemoteTask-In-TCP", "WMI-WINMGMT-In-TCP", "RemoteTask-RPCSS-In-TCP"}

 Invoke-Command -ComputerName "cl1" `
     -ScriptBlock {Enable-NetFirewallRule -Name "RemoteTask-In-TCP-NoScope", "WMI-WINMGMT-In-TCP-NoScope", "RemoteTask-RPCSS-In-TCP-NoScope"}

 Invoke-Command -ComputerName "srv1", "cl1", "mgr" `
     -ScriptBlock {gpupdate /force}