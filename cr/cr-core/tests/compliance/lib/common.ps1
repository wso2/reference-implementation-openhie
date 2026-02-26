Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-SimulatedToken {
    param(
        [Parameter(Mandatory = $true)][string]$Role,
        [string]$Subject = "compliance.tester@openhie.local",
        [int]$HoursValid = 2
    )

    $expiry = [DateTimeOffset]::UtcNow.AddHours($HoursValid).ToUnixTimeMilliseconds()
    $payload = @{
        sub = $Subject
        role = $Role
        exp = $expiry
    } | ConvertTo-Json -Compress

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    return [Convert]::ToBase64String($bytes)
}

function New-AuthHeader {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("admin", "viewer")][string]$Role,
        [string]$Subject = "compliance.tester@openhie.local"
    )

    $token = New-SimulatedToken -Role $Role -Subject $Subject
    return @{ Authorization = "Bearer $token" }
}

function Convert-RawToString {
    param([AllowNull()]$Raw)

    if ($null -eq $Raw) {
        return $null
    }

    if ($Raw -is [byte[]]) {
        return [System.Text.Encoding]::UTF8.GetString($Raw)
    }

    if ($Raw -is [string]) {
        return $Raw
    }

    return $Raw.ToString()
}

function Convert-JsonSafe {
    param([AllowNull()]$Raw)

    $rawText = Convert-RawToString -Raw $Raw

    if ([string]::IsNullOrWhiteSpace($rawText)) {
        return $null
    }

    try {
        return $rawText | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Invoke-FhirRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Url,
        [hashtable]$Headers = @{},
        [AllowNull()]$Body = $null
    )

    $invokeArgs = @{
        Method      = $Method
        Uri         = $Url
        Headers     = $Headers
        ContentType = "application/fhir+json"
    }

    if ($null -ne $Body) {
        if ($Body -is [string]) {
            $invokeArgs.Body = $Body
        }
        else {
            $invokeArgs.Body = $Body | ConvertTo-Json -Depth 100 -Compress
        }
    }

    try {
        $response = Invoke-WebRequest @invokeArgs
        $rawText = Convert-RawToString -Raw $response.Content
        return @{
            StatusCode = [int]$response.StatusCode
            Headers    = $response.Headers
            Raw        = $rawText
            Body       = Convert-JsonSafe -Raw $rawText
        }
    }
    catch {
        if ($null -eq $_.Exception.Response) {
            throw
        }

        $httpResponse = $_.Exception.Response
        $stream = $httpResponse.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $raw = $reader.ReadToEnd()
        $reader.Dispose()

        return @{
            StatusCode = [int]$httpResponse.StatusCode
            Headers    = $httpResponse.Headers
            Raw        = $raw
            Body       = Convert-JsonSafe -Raw $raw
        }
    }
}

function New-PatientPayload {
    param(
        [Parameter(Mandatory = $true)][string]$System,
        [Parameter(Mandatory = $true)][string]$IdentifierValue,
        [Parameter(Mandatory = $true)][string]$Family,
        [Parameter(Mandatory = $true)][string]$Given,
        [Parameter(Mandatory = $true)][ValidateSet("male", "female", "other", "unknown")][string]$Gender,
        [Parameter(Mandatory = $true)][string]$BirthDate,
        [string]$Phone = "555-0100",
        [string]$City = "Colombo",
        [string]$PostalCode = "00100",
        [string]$Country = "LK"
    )

    return @{
        resourceType = "Patient"
        identifier   = @(
            @{
                system = $System
                value  = $IdentifierValue
            }
        )
        name         = @(
            @{
                family = $Family
                given  = @($Given)
            }
        )
        gender       = $Gender
        birthDate    = $BirthDate
        telecom      = @(
            @{
                system = "phone"
                value  = $Phone
            }
        )
        address      = @(
            @{
                city       = $City
                postalCode = $PostalCode
                country    = $Country
            }
        )
    }
}

function New-TestIdentifier {
    param([string]$Prefix = "compliance")

    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $random = Get-Random -Minimum 1000 -Maximum 9999
    return "$Prefix-$stamp-$random"
}

function Get-JsonProperty {
    param([AllowNull()]$Object, [Parameter(Mandatory = $true)][string]$Name)

    if ($null -eq $Object) { return $null }
    $match = $Object.PSObject.Properties.Match($Name)
    if ($match.Count -eq 0) { return $null }
    return $Object.$Name
}

function Write-ResponseDetail {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Response,
        [string]$Label = "Response"
    )

    Write-Host "  [$Label] StatusCode=$($Response.StatusCode)" -ForegroundColor Yellow
    if ($null -ne $Response.Raw) {
        $preview = if ($Response.Raw.Length -gt 400) { $Response.Raw.Substring(0, 400) + "..." } else { $Response.Raw }
        Write-Host "  [$Label] Body=$preview" -ForegroundColor Yellow
    }
}

$script:AssertTotal = 0
$script:AssertFailed = 0

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:AssertTotal++
    if ($Actual -ne $Expected) {
        $script:AssertFailed++
        Write-Host "[FAIL] $Message (expected=$Expected, actual=$Actual)" -ForegroundColor Red
        return
    }

    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:AssertTotal++
    if (-not $Condition) {
        $script:AssertFailed++
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        return
    }

    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Assert-GreaterOrEqual {
    param(
        [Parameter(Mandatory = $true)][int]$Actual,
        [Parameter(Mandatory = $true)][int]$ExpectedMin,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $script:AssertTotal++
    if ($Actual -lt $ExpectedMin) {
        $script:AssertFailed++
        Write-Host "[FAIL] $Message (min=$ExpectedMin, actual=$Actual)" -ForegroundColor Red
        return
    }

    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Complete-TestRun {
    param([string]$Profile)

    Write-Host ""
    if ($script:AssertFailed -gt 0) {
        Write-Host "[$Profile] Completed with failures: $script:AssertFailed / $script:AssertTotal" -ForegroundColor Red
        exit 1
    }

    Write-Host "[$Profile] All assertions passed: $script:AssertTotal" -ForegroundColor Green
    exit 0
}
