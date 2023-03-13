# -----2. script for opprettelse av passord & vasking av brukere----- #
# Kjører på MGR

# Importerer brukerne våres, og definerer paths til den ferdigstilte dataen
$users = Import-Csv -Path 'C:\Users\Administrator\Desktop\Repository\infra-prosjektv23\final\userdata.csv' -Delimiter ","
$exportuserspath = 'C:\Users\Administrator\Desktop\Repository\infra-prosjektv23\final\userdata-crunched.csv'
$exportpathfinal = 'C:\Users\Administrator\Desktop\Repository\infra-prosjektv23\final\userdata-final.csv'
$csvfile = @()

# Funksjon som lager en array av characters, og til slutt joiner tegnene
function New-UserPassword {
    $chars = [char[]](
        (33..43 | ForEach-Object {[char]$_}) +
        (61..64 | ForEach-Object {[char]$_}) +
        (91..96 | ForEach-Object {[char]$_}) +
        (123..126 | ForEach-Object {[char]$_}) +
        (48..57 | ForEach-Object {[char]$_}) +
        (65..90 | ForEach-Object {[char]$_}) +
        (97..122 | ForEach-Object {[char]$_})
    )

    -join (0..14 | ForEach-Object { $chars | Get-Random })
}

# Funksjon for å vaske gjennom brukerinformasjon
function New-UserInfo {
    param (
        [Parameter(Mandatory=$true)][string] $fornavn,
        [Parameter(Mandatory=$true)][string] $etternavn
    )

    # Hvis fornavnet har et mellomrom, dvs. man har et mellomnavn, deles opp navnet til brukeren
    if ($fornavn -match $([char]32)) {
        $oppdelt = $fornavn.Split($([char]32))
        $fornavn = $oppdelt[0]

        # Setter punktum foran fornavnet, for å skille fornavn og mellomnavn
        for ($index = 1; $index -lt $oppdelt.length; $index ++) {
            $fornavn += ".$($oppdelt[$index][0])"
        } 
    }

    # Til slutt dannes brukernavnet med format 'fornavn.m.etternavn', og erstatter norske spesialtegn
    $UserPrincipalName = $("$($fornavn).$($etternavn)").ToLower()
    $UserPrincipalName = $UserPrincipalName.Replace('æ','e')
    $UserPrincipalName = $UserPrincipalName.Replace('ø','o')
    $UserPrincipalName = $UserPrincipalName.Replace('å','a')
    $UserPrincipalName = $UserPrincipalName.Replace('é','e')

    return $UserPrincipalName
}

foreach ($user in $users) {
    $password = New-UserPassword
    $line = New-Object -TypeName psobject

    Add-Member -InputObject $line -MemberType NoteProperty -Name GivenName -Value $user.GivenName
    Add-Member -InputObject $line -MemberType NoteProperty -Name SurName -Value $user.SurName
    Add-Member -InputObject $line -MemberType NoteProperty -Name UserPrincipalName -Value "$(New-UserInfo -Fornavn $user.GivenName -Etternavn $user.SurName)@core.sec"
    Add-Member -InputObject $line -MemberType NoteProperty -Name DisplayName -Value "$($user.GivenName) $($user.SurName)"
    Add-Member -InputObject $line -MemberType NoteProperty -Name Department -Value $user.Department
    Add-Member -InputObject $line -MemberType NoteProperty -Name Password -Value $password
    $csvfile += $line
}

$csvfile | Export-Csv -Path $exportuserspath -NoTypeInformation -Encoding 'UTF8'
Import-Csv -Path $exportuserspath | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -Replace '"', ""} | Out-File $exportpathfinal -Encoding 'UTF8'