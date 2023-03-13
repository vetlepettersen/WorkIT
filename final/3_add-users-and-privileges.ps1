# -----3. script for å legge til brukere, og tildele privilegium----- #
# Kjører på MGR

$users = Import-Csv -Path 'C:\Users\Administrator\Desktop\Repository\infra-prosjektv23\final\userdata-final.csv' -Delimiter ","
# Importerer våre ferdigstilte og klare brukere fra brukerdataen vår

$departments = @('ChiefOfficers','IT','Sales','HR')
$it_departments = @('Security','Operation','Development')
$sales_departments = @('Finance','Accounting')
$all_departments = $departments + $it_departments + $sales_departments
# Importerer også alle departments, slik at medlemskap kan gis til slutt

# Benytter en funksjon for å begrense antall tegn man kan benytte i samaccountnames
function Get-SamMaxCharacters {
    param (
        [Parameter(Mandatory=$True)][string]$InputString,
        [Parameter(Mandatory=$True)][int]$MaxCharacters
        )
    if ($InputString.Length -gt $MaxCharacters) {
        $InputString.Substring(0, $MaxCharacters)
    } else {
        $InputString
    }
}

foreach($user in $users) {
    $sam = $user.UserPrincipalName.Split('@')
    $samaccountname = Get-SamMaxCharacters -InputString $sam[0] -MaxCharacters 19
    # Deler opp brukernavnet ved alfakrøllen, og benytter funksjonen som definert tidligere for å begrense lengden på navnet

        [string]$department = $user.Department
        [string]$searchdn = "OU=$department*OU=WorkIT_Users,*"
        $path = Get-ADOrganizationalUnit -Filter * | Where-Object {($_.name -eq $user.Department) -and ($_.DistinguishedName -like $searchdn)}
        # Tilrettelegger for å finne alle departments, uavhengig av om det er underdepartments, eksempelvis Security under IT, etc.

    if (!(Get-ADUser -Filter * | Where-Object {($_.SamAccountName -eq $samaccountname) -and ($_.UserPrincipalName -eq $user.UserPrincipalName)})) {
        New-ADUser `
            -SamAccountName $samaccountname `
            -UserPrincipalName $user.UserPrincipalName `
            -Name $samaccountname `
            -GivenName $user.GivenName `
            -Surname $user.SurName `
            -Enabled $True `
            -ChangePasswordAtLogon $false `
            -DisplayName $user.DisplayName `
            -Department $user.Department `
            -Path $path.DistinguishedName `
            -AccountPassword (ConvertTo-SecureString $user.Password -AsPlainText -Force)
    } else {
        Write-Host "Brukeren med Sam $samaccountname og ${$user.UserPrincipalName} eksisterer allerede! Legg til et tall bak! "
    }
}

$ADUsers = @()

foreach ($department in $all_departments) {
    # Kjører gjennom absolutt alle departments, og for hver bruker i det vilkårlige departmentet, legges til i $ADUsers arrayet
    $ADUsers = Get-ADUser -Filter {Department -eq $department} -Properties Department
    Write-Host "$ADUsers er funnet under $department"

    foreach ($ADUser in $ADUsers) {
        # Deretter kan vi trygt legge til riktig bruker til departmentet sitt
        Add-ADPrincipalGroupMembership -Identity $ADUser.SamAccountName -MemberOf "g_$department"
        # if-setningene nedenfor sørger for å legge brukere til i gruppen, ett nivå høyere
        if ($it_departments -contains $department) {
            Add-ADPrincipalGroupMembership -Identity $ADUser.SamAccountName -MemberOf "g_IT"
        }
        if ($sales_departments -contains $department) {
            Add-ADPrincipalGroupMembership -Identity $ADUser.SamAccountName -MemberOf "g_Sales"
        }
    }
}

# Oppretter grupper for Remote Desktop
foreach ($department in $departments) {
    New-ADGroup `
    -GroupCategory Security `
    -GroupScope DomainLocal `
    -Name "l_remotedesktop_$department" `
    -Path "OU=WorkIT_Groups,DC=core,DC=sec" `
    -SamAccountName "l_remotedesktop_$department"
}

# Oppretter GPOs for å tillate Remote Desktop Protocols, for hver avdeling
foreach ($department in $departments) {
    New-GPO -Name "Allow Remote Desktop for $department"
    New-GPLink -Name "Allow Remote Desktop for $department" -Target "OU=$department,OU=WorkIT_Computers,DC=core,DC=sec"
}

# Kobler sammen hver globale gruppe med sin lokale Remote Desktop gruppe
foreach ($department in $departments) {
            Add-ADPrincipalGroupMembership `
            -Identity "g_$department" `
            -MemberOf "l_remotedesktop_$department"
}

# Lager en enkel løkke for å oppdatere Group Policies på klienter og server
$vms = @('cl1','srv1')
foreach ($vm in $vms) {
    Invoke-GPUpdate -Computer "$vm.core.sec" -RandomDelayInMinutes 0 -Force
}

# Lager fildelingsgrupper og tildeler medlemskap til alle globale grupper
foreach ($department in $all_departments) {
    if ($it_departments -contains $department) {
            $path = Get-ADOrganizationalUnit -Filter * | 
            Where-Object {($_.name -eq "$department") `
            -and ($_.DistinguishedName -like "OU=$department,OU=IT,OU=WorkIT_Groups,*")}
            New-ADGroup -Name "l_fullaccess_$department-share" `
            -SamAccountName "l_fullaccess_$department-share" `
            -GroupCategory Security `
            -GroupScope Global `
            -DisplayName "l_fullaccess_$department-share" `
            -Path $path.DistinguishedName `
            -Description "$department FILE SHARE group"     
    } elseif ($sales_departments -contains $department) {
                $path = Get-ADOrganizationalUnit -Filter * | 
                Where-Object {($_.name -eq "$department") `
                -and ($_.DistinguishedName -like "OU=$department,OU=Sales,OU=WorkIT_Groups,*")}
                New-ADGroup -Name "l_fullaccess_$department-share" `
                -SamAccountName "l_fullaccess_$department-share" `
                -GroupCategory Security `
                -GroupScope Global `
                -DisplayName "l_fullaccess_$department-share" `
                -Path $path.DistinguishedName `
                -Description "$department FILE SHARE group"     
    } else {
        $path = Get-ADOrganizationalUnit -Filter * | 
                Where-Object {($_.name -eq "$department") `
                -and ($_.DistinguishedName -like "OU=$department,OU=WorkIT_Groups,*")}
                New-ADGroup -Name "l_fullaccess_$department-share" `
                -SamAccountName "l_fullaccess_$department-share" `
                -GroupCategory Security `
                -GroupScope Global `
                -DisplayName "l_fullaccess_$department-share" `
                -Path $path.DistinguishedName `
                -Description "$department FILE SHARE group"
    }
}

# Legger alle globale grupper til sine respektive lokale ressursgrupper
foreach ($department in $all_departments) {
    Add-ADPrincipalGroupMembership -Identity "g_$department" -MemberOf "l_fullaccess_$department-share"
}