# -----5. script for å opprette DFS Replication og linke det til filsystemet----- #
# Kjører på SRV1

#Installerer DFS Replication på dc1 og oppretter selve filstrukturen for kloningen
Invoke-Command -ComputerName dc1 -ScriptBlock {Install-WindowsFeature -name FS-DFS-Replication -IncludeManagementTools -ComputerName dc1}
Invoke-Command -ComputerName dc1 -ScriptBlock {
    $departments = @('HR','IT','Sales','ChiefOfficers')
    $it_departments = @('Security','Operation','Development')
    $sales_departments = @('Finance', 'Accounting')
    $all_departments = $departments + $it_departments + $sales_departments

    foreach ($department in $all_departments) {
        if($it_departments -contains $department){
            mkdir -path "C:\ReplicaIT-SharedFolder\Replica$department-SharedFolder"
        } elseif ($sales_departments -contains $department){
            mkdir -path "C:\ReplicaSales-SharedFolder\Replica$department-SharedFolder"
        } else {
            mkdir -path "C:\Replica$department-SharedFolder"
        }
    }
}

$departments = @('HR','IT','Sales','ChiefOfficers')
$it_departments = @('Security','Operation','Development')
$sales_departments = @('Finance', 'Accounting')  
$all_departments = $departments + $it_departments + $sales_departments

#Oppretter, for hver department og under-department, en replication group og lenker den opp mot riktig filbane fra srv1
foreach ($department in $all_departments) {
    if($it_departments -contains $department){
            New-DfsReplicationGroup -GroupName "RepGrpIT$department-Share" 
            Add-DfsrMember -GroupName "RepGrpIT$department-Share" -ComputerName "srv1","dc1" 
            Add-DfsrConnection -GroupName "RepGrpIT$department-Share" `
                                -SourceComputerName "srv1" `
                                -DestinationComputerName "dc1" 
        
            New-DfsReplicatedFolder -GroupName "RepGrpIT$department-Share"  -FolderName "ReplicaIT$department-SharedFolder" 
        
            Set-DfsrMembership -GroupName "RepGrpIT$department-Share"  `
                                -FolderName "ReplicaIT$department-SharedFolder" `
                                -ContentPath "C:\shares\IT\$department" `
                                -ComputerName "srv1" `
                                -PrimaryMember $True `
                                -Force
        
            Set-DfsrMembership -GroupName "RepGrpIT$department-Share"  `
                                -FolderName "ReplicaIT$department-SharedFolder" `
                                -ContentPath "c:\ReplicaIT-SharedFolder\Replica$department-SharedFolder" `
                                -ComputerName "dc1" `
                                -Force
    } elseif ($sales_departments -contains $department){
            New-DfsReplicationGroup -GroupName "RepGrpSales$department-Share" 
            Add-DfsrMember -GroupName "RepGrpSales$department-Share" -ComputerName "srv1","dc1" 
            Add-DfsrConnection -GroupName "RepGrpSales$department-Share" `
                                -SourceComputerName "srv1" `
                                -DestinationComputerName "dc1" 
        
            New-DfsReplicatedFolder -GroupName "RepGrpSales$department-Share" -FolderName "ReplicaSales$department-SharedFolder" 
        
            Set-DfsrMembership -GroupName "RepGrpSales$department-Share" `
                                -FolderName "ReplicaSales$department-SharedFolder" `
                                -ContentPath "C:\shares\Sales\$department" `
                                -ComputerName "srv1" `
                                -PrimaryMember $True `
                                -Force
        
            Set-DfsrMembership -GroupName "RepGrpSales$department-Share" `
                                -FolderName "ReplicaSales$department-SharedFolder" `
                                -ContentPath "c:\ReplicaSales-SharedFolder\Replica$department-SharedFolder" `
                                -ComputerName "dc1" `
                                -Force
    } else {
        New-DfsReplicationGroup -GroupName "RepGrp$department-Share" 
        Add-DfsrMember -GroupName "RepGrp$department-Share" -ComputerName "srv1","dc1" 
        Add-DfsrConnection -GroupName "RepGrp$department-Share" `
                            -SourceComputerName "srv1" `
                            -DestinationComputerName "dc1" 
    
        New-DfsReplicatedFolder -GroupName "RepGrp$department-Share" -FolderName "Replica$department-SharedFolder" 
    
        Set-DfsrMembership -GroupName "RepGrp$department-Share" `
                            -FolderName "Replica$department-SharedFolder" `
                            -ContentPath "C:\shares\$department" `
                            -ComputerName "srv1" `
                            -PrimaryMember $True `
                            -Force
    
        Set-DfsrMembership -GroupName "RepGrp$department-Share" `
                            -FolderName "Replica$department-SharedFolder" `
                            -ContentPath "c:\Replica$department-SharedFolder" `
                            -ComputerName "dc1" `
                            -Force
    }
}

# Sjekker tilstanden til DFSR-strukturen
Get-DfsrCloneState 