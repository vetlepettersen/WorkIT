# -----4. script for å danne filstrukturen som skal deles på nettverket----- #
# Kjører på SRV1

# Definerer departments, samt underdepartments til IT og Sales
$departments = @('ChiefOfficers','IT','Sales','HR')
$it_departments = @('Security','Operation','Development')
$sales_departments = @('Finance','Accounting')
$all_departments = $departments + $it_departments + $sales_departments


# Installerer riktige features for å støtte DFS (Distributed File System)
Install-WindowsFeature -Name FS-DFS-Namespace,FS-DFS-Replication,RSAT-DFS-Mgmt-Con -IncludeManagementTools

# Oppretter DFS root directory, og 'root' directory shares for alle delte filer
New-Item -Path "C:\" -Name 'dfsroots' -ItemType "directory"
New-Item -Path "C:\" -Name 'shares' -ItemType "directory"
New-Item -path 'C:\dfsroots\' -Name 'files' -ItemType "directory"

# En løkke som går gjennom alle departments og oppretter mapper samt. undermapper for fildeling
foreach($department in $all_departments) {
    if ($it_departments -contains $department) {
        mkdir -path "C:\shares\IT\$department"
    } elseif ($sales_departments -contains $department) {
        mkdir -path "C:\shares\Sales\$department"
    } else {
        mkdir -path "C:\shares\$department"
    }
}

# Definerer variabler for paths til alle soon-to-be delte mapper
$deptfolders = Get-ChildItem -Path "C:\shares" -Recurse -Directory -Force
$deptfolders = $deptfolders | Select-Object -ExpandProperty FullName | ForEach-Object {$_.ToString()}
$folders = $deptfolders + ('C:\shares', 'C:\dfsroots', 'C:\dfsroots\files')

# Gir full tilgang til delte mapper
$folders | ForEach-Object {$sharename = (Get-Item $_).name; New-SMBShare -Name $shareName -Path $_ -FullAccess Everyone}

# Redefinerer root-directory fra srv1 til en generell core.sec
New-DfsnRoot -TargetPath \\srv1\files -Path \\core.sec\files -Type DomainV2

# Lager en funksjon for å kun peke til mappene som er hoved-departments
function AssignFolders {
    Param(
        [string]$departmentName
    )

    $folders | Where-Object {$_ -like "*$departmentName"} | 
        ForEach-Object {
            $name = (Get-Item $_).name
            $dfsPath = ('\\core.sec\files\' + $name)
            $targetPath = ('\\srv1\' + $name)
            New-DfsnFolderTarget -Path $dfsPath -TargetPath $targetPath
        }
}

foreach ($department in $departments) {
    AssignFolders -departmentName $department
}
# Funksjon for å sette Access Control Lists (ACL) til alle departments og subdepartments
function Set-FolderACL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Department,
        [Parameter(Mandatory = $false)]
        [string]$SubDepartmentName
    )
    if ($SubDepartmentName) {$name = $SubDepartmentName} else {$name = $Department}

        $ACL = Get-Acl "\\core\files\$Department\$SubDepartmentName"
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("core\l_fullaccess_$name-share","FullControl","Allow")
        $ACL.SetAccessRule($AccessRule)
        $ACL | Set-Acl -Path "\\core\files\$Department\$SubDepartmentName"
}

foreach ($department in $all_departments) {
    if($it_departments -contains $department) {
            Set-FolderACL -Department "IT" -SubDepartmentName $department
    } elseif ($sales_departments -contains $department)  {
                Set-FolderACL -Department "Sales" -SubDepartmentName $department
    } else {
        Set-FolderACL -Department $department -SubDepartmentName $null
    }
}

# Funksjon for å sette innstillinger for arv, og sletting & endring
function Set-ARProtection {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Department,
        [Parameter(Mandatory = $false)]
        [string[]]$SubDepartment
    )

        $ACL = Get-Acl -Path "\\core\files\$Department\$SubDepartment"
        $ACL.SetAccessRuleProtection($true,$true)
        $ACL | Set-Acl -Path "\\core\files\$Department\$SubDepartment"
}
foreach ($department in $all_departments) {
    if($it_departments -contains $department) {
            Set-ARProtection -Department "IT" -SubDepartment $department
    } elseif ($sales_departments -contains $department) {
            Set-ARProtection -Department "Sales" -SubDepartment $department
    } else {
        Set-ARProtection -Department $department -SubDepartment $null
    }
}

# Funksjon for å ferdiggjøre ACL
function Remove-GeneralAccess {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Department,
        [Parameter(Mandatory = $false)]
        [string]$SubDepartment
    )
    $path = "\\core\files\$Department\$SubDepartment"
    $acl = Get-Acl $path
    $acl.Access | Where-Object { $_.IdentityReference -eq "BUILTIN\Users" } | ForEach-Object { $acl.RemoveAccessRuleSpecific($_) }
    Set-Acl $path $acl
    (Get-ACL -Path $path).Access | 
        Format-Table IdentityReference,FileSystemRights,AccessControlType,IsInherited,InheritanceFlags -AutoSize
}

foreach ($department in $all_departments) {
    if($it_departments -contains $department) {
        Remove-GeneralAccess -Department "IT" -SubDepartment $department
    } elseif ($sales_departments -contains $department) {
        Remove-GeneralAccess -Department "Sales" -SubDepartment $department
    } else {
        Remove-GeneralAccess -Department $department -SubDepartment $null
    }
}