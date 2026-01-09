<#
.SYNOPSIS
    All-in-one script to automatically update Intune macOS Compliance Policy based on AppleDB
    
.DESCRIPTION
    This script fetches the latest macOS versions from AppleDB API, calculates the version
    that is 2 releases behind the latest, and updates the specified Intune compliance policy.
    
    Works in two modes:
    1. Standalone: Pass parameters directly or use environment variables
    2. Azure Automation: Automatically loads credentials from Azure Automation variables
    
.PARAMETER TenantId
    Your Azure AD Tenant ID (not needed in Azure Automation if using variables)
    
.PARAMETER ClientId
    Azure App Registration Client ID (not needed in Azure Automation if using variables)
    
.PARAMETER ClientSecret
    Azure App Registration Client Secret (not needed in Azure Automation if using variables)
    
.PARAMETER CompliancePolicyId
    The ID of the Intune macOS compliance policy to update
    
.PARAMETER VersionsBelow
    Number of major versions below latest to set as minimum (default: 2)
    
.PARAMETER UseMinorVersions
    If specified, calculates based on minor versions instead of major versions
    
.PARAMETER PinToMajorVersion
    Pin to a specific major version and track minor versions within that version
    Example: -PinToMajorVersion 15 -VersionsBelow 2
    If latest is 15.7, sets minimum to 15.5 (ignoring macOS 16.x)
    
.PARAMETER WhatIf
    Shows what changes would be made without actually making them
    
.PARAMETER RunTests
    Run configuration tests before executing the main script
    
.EXAMPLE
    # Standalone execution with parameters
    .\Update-IntuneMacOSCompliance.ps1 -TenantId "xxx" -ClientId "xxx" -ClientSecret "xxx" -CompliancePolicyId "xxx"
    
.EXAMPLE
    # Standalone with environment variables
    $env:INTUNE_TENANT_ID = "xxx"
    $env:INTUNE_CLIENT_ID = "xxx"
    $env:INTUNE_CLIENT_SECRET = "xxx"
    $env:INTUNE_POLICY_ID = "xxx"
    .\Update-IntuneMacOSCompliance.ps1
    
.EXAMPLE
    # Azure Automation (credentials stored as Azure Automation variables)
    .\Update-IntuneMacOSCompliance.ps1 -CompliancePolicyId "xxx"
    
.EXAMPLE
    # Pin to macOS 15 and stay 2 minor versions behind
    # If latest is 15.7, sets minimum to 15.5 (ignores macOS 16.x)
    .\Update-IntuneMacOSCompliance.ps1 -PinToMajorVersion 15 -VersionsBelow 2
    
.EXAMPLE
    # Test mode
    .\Update-IntuneMacOSCompliance.ps1 -WhatIf -RunTests
    
.NOTES
    Author: SSMacAdmin
    Version: 2.0 
    
    Azure Automation Setup:
    1. Create Azure Automation Account
    2. Add these variables to your Automation Account:
       - INTUNE_TENANT_ID
       - INTUNE_CLIENT_ID
       - INTUNE_CLIENT_SECRET (encrypted)
       - INTUNE_POLICY_ID
    3. Upload this script as a Runbook
    4. Schedule it to run weekly
    
    Standalone Setup:
    1. Create Azure App Registration with DeviceManagementConfiguration.ReadWrite.All
    2. Either pass parameters or set environment variables
    3. Run the script
    
    Required Permissions for Azure App Registration:
    - DeviceManagementConfiguration.ReadWrite.All
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $false)]
    [string]$ClientId,
    
    [Parameter(Mandatory = $false)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory = $false)]
    [string]$CompliancePolicyId,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$VersionsBelow = 2,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseMinorVersions,
    
    [Parameter(Mandatory = $false)]
    [int]$PinToMajorVersion,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$RunTests
)

#Requires -Version 5.1

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================
$script:testMode = $RunTests
$script:isAzureAutomation = $false
$script:logEntries = @()

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Store in array for later output
    $script:logEntries += $logMessage
    
    # Console output with colors (if not in Azure Automation)
    if (-not $script:isAzureAutomation) {
        switch ($Level) {
            'INFO'    { Write-Host $logMessage -ForegroundColor Cyan }
            'WARNING' { Write-Host $logMessage -ForegroundColor Yellow }
            'ERROR'   { Write-Host $logMessage -ForegroundColor Red }
            'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
            'DEBUG'   { Write-Host $logMessage -ForegroundColor Gray }
        }
    }
    else {
        # Azure Automation output - use Write-Verbose to avoid pipeline pollution
        Write-Verbose $logMessage
    }
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================
function Get-Configuration {
    Write-Log "Loading configuration..." -Level INFO
    
    $config = @{
        TenantId           = $null
        ClientId           = $null
        ClientSecret       = $null
        CompliancePolicyId = $null
        VersionsBelow      = $VersionsBelow
        UseMinorVersions   = $UseMinorVersions
        PinToMajorVersion  = $PinToMajorVersion
        WhatIf             = $WhatIf
    }
    
    # Check if running in Azure Automation
    try {
        $null = Get-AutomationVariable -Name "INTUNE_TENANT_ID" -ErrorAction Stop
        $script:isAzureAutomation = $true
        Write-Log "Detected Azure Automation environment" -Level INFO
    }
    catch {
        $script:isAzureAutomation = $false
        Write-Log "Running in standalone mode" -Level INFO
    }
    
    # Load credentials based on environment
    if ($script:isAzureAutomation) {
        Write-Log "Loading credentials from Azure Automation variables..." -Level INFO
        try {
            $config.TenantId = Get-AutomationVariable -Name "INTUNE_TENANT_ID"
            $config.ClientId = Get-AutomationVariable -Name "INTUNE_CLIENT_ID"
            $config.ClientSecret = Get-AutomationVariable -Name "INTUNE_CLIENT_SECRET"
            $config.CompliancePolicyId = Get-AutomationVariable -Name "INTUNE_POLICY_ID"
            
            # Load optional configuration variables
            try {
                $versionsBelow = Get-AutomationVariable -Name "VERSIONS_BELOW" -ErrorAction SilentlyContinue
                if ($versionsBelow) { $config.VersionsBelow = [int]$versionsBelow }
            } catch { }
            
            try {
                $useMinorVersions = Get-AutomationVariable -Name "USE_MINOR_VERSIONS" -ErrorAction SilentlyContinue
                if ($null -ne $useMinorVersions) { $config.UseMinorVersions = [bool]$useMinorVersions }
            } catch { }
            
            try {
                $pinToMajor = Get-AutomationVariable -Name "PIN_TO_MAJOR_VERSION" -ErrorAction SilentlyContinue
                if ($pinToMajor -and $pinToMajor -gt 0) { $config.PinToMajorVersion = [int]$pinToMajor }
            } catch { }
            
            # Allow parameter overrides
            if ($CompliancePolicyId) { $config.CompliancePolicyId = $CompliancePolicyId }
            if ($PinToMajorVersion) { $config.PinToMajorVersion = $PinToMajorVersion }
            
            Write-Log "Successfully loaded credentials from Azure Automation" -Level SUCCESS
        }
        catch {
            Write-Log "Failed to load Azure Automation variables: $($_.Exception.Message)" -Level ERROR
            Write-Log "Make sure you've created these variables in your Automation Account:" -Level ERROR
            Write-Log "  - INTUNE_TENANT_ID" -Level ERROR
            Write-Log "  - INTUNE_CLIENT_ID" -Level ERROR
            Write-Log "  - INTUNE_CLIENT_SECRET (encrypted)" -Level ERROR
            Write-Log "  - INTUNE_POLICY_ID" -Level ERROR
            throw
        }
    }
    else {
        Write-Log "Loading credentials from parameters or environment variables..." -Level INFO
        
        # Try parameters first, then environment variables
        $config.TenantId = if ($TenantId) { $TenantId } else { $env:INTUNE_TENANT_ID }
        $config.ClientId = if ($ClientId) { $ClientId } else { $env:INTUNE_CLIENT_ID }
        $config.ClientSecret = if ($ClientSecret) { $ClientSecret } else { $env:INTUNE_CLIENT_SECRET }
        $config.CompliancePolicyId = if ($CompliancePolicyId) { $CompliancePolicyId } else { $env:INTUNE_POLICY_ID }
    }
    
    # Validate configuration
    $missingConfig = @()
    if ([string]::IsNullOrWhiteSpace($config.TenantId)) { $missingConfig += "TenantId" }
    if ([string]::IsNullOrWhiteSpace($config.ClientId)) { $missingConfig += "ClientId" }
    if ([string]::IsNullOrWhiteSpace($config.ClientSecret)) { $missingConfig += "ClientSecret" }
    if ([string]::IsNullOrWhiteSpace($config.CompliancePolicyId)) { $missingConfig += "CompliancePolicyId" }
    
    if ($missingConfig.Count -gt 0) {
        Write-Log "Missing required configuration: $($missingConfig -join ', ')" -Level ERROR
        
        if ($script:isAzureAutomation) {
            Write-Log "Create these variables in your Azure Automation Account" -Level ERROR
        }
        else {
            Write-Log "Provide them as parameters or set environment variables:" -Level ERROR
            Write-Log "  `$env:INTUNE_TENANT_ID = 'your-tenant-id'" -Level ERROR
            Write-Log "  `$env:INTUNE_CLIENT_ID = 'your-client-id'" -Level ERROR
            Write-Log "  `$env:INTUNE_CLIENT_SECRET = 'your-secret'" -Level ERROR
            Write-Log "  `$env:INTUNE_POLICY_ID = 'your-policy-id'" -Level ERROR
        }
        throw "Configuration incomplete"
    }
    
    Write-Log "Configuration loaded successfully" -Level SUCCESS
    Write-Log "  Tenant ID: $($config.TenantId.Substring(0,8))..." -Level DEBUG
    Write-Log "  Policy ID: $($config.CompliancePolicyId.Substring(0,8))..." -Level DEBUG
    Write-Log "  Versions Below: $($config.VersionsBelow)" -Level DEBUG
    Write-Log "  Use Minor Versions: $($config.UseMinorVersions)" -Level DEBUG
    if ($config.PinToMajorVersion) {
        Write-Log "  Pin to Major Version: $($config.PinToMajorVersion)" -Level DEBUG
    }
    Write-Log "  WhatIf Mode: $($config.WhatIf)" -Level DEBUG
    
    return $config
}

# ============================================================================
# TESTING FUNCTIONS
# ============================================================================
function Test-Prerequisites {
    Write-Log "========================================" -Level INFO
    Write-Log "Running Prerequisites Tests" -Level INFO
    Write-Log "========================================" -Level INFO
    
    $allTestsPassed = $true
    
    # Test 1: PowerShell Version
    Write-Log "Testing PowerShell version..." -Level INFO
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 5) {
        Write-Log "✓ PowerShell $($psVersion.Major).$($psVersion.Minor) detected" -Level SUCCESS
    }
    else {
        Write-Log "✗ PowerShell $($psVersion.Major).$($psVersion.Minor) is too old (need 5.1+)" -Level ERROR
        $allTestsPassed = $false
    }
    
    # Test 2: Internet Connectivity
    Write-Log "Testing internet connectivity..." -Level INFO
    try {
        $testConnection = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction Stop
        if ($testConnection) {
            Write-Log "✓ Internet connection available" -Level SUCCESS
        }
        else {
            Write-Log "✗ Cannot reach internet" -Level ERROR
            $allTestsPassed = $false
        }
    }
    catch {
        Write-Log "⚠ Cannot test internet connectivity (might be restricted environment)" -Level WARNING
    }
    
    # Test 3: AppleDB API Access
    Write-Log "Testing AppleDB API access..." -Level INFO
    try {
        $appleDBUrl = "https://api.appledb.dev/ios/macOS/main.json"
        $appleDBTest = Invoke-RestMethod -Uri $appleDBUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
        
        if ($appleDBTest -and $appleDBTest.Count -gt 0) {
            Write-Log "✓ AppleDB API is accessible ($($appleDBTest.Count) builds found)" -Level SUCCESS
        }
        else {
            Write-Log "✗ AppleDB API returned no data" -Level ERROR
            $allTestsPassed = $false
        }
    }
    catch {
        Write-Log "✗ Cannot reach AppleDB API: $($_.Exception.Message)" -Level ERROR
        $allTestsPassed = $false
    }
    
    Write-Log "" -Level INFO
    return $allTestsPassed
}

# ============================================================================
# GET MACOS VERSIONS FROM APPLEDB
# ============================================================================
function Get-MacOSVersionsFromAppleDB {
    Write-Log "Fetching macOS versions from AppleDB API..." -Level INFO
    
    try {
        $apiUrl = "https://api.appledb.dev/ios/macOS/main.json"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
        
        if ($null -eq $response -or $response.Count -eq 0) {
            throw "No data returned from AppleDB API"
        }
        
        Write-Log "Successfully retrieved $($response.Count) macOS builds from AppleDB" -Level SUCCESS
        return $response
    }
    catch {
        Write-Log "Failed to fetch macOS versions from AppleDB: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

# ============================================================================
# PARSE AND SORT MACOS VERSIONS
# ============================================================================
function Get-LatestMacOSVersions {
    param(
        [Parameter(Mandatory = $true)]
        [array]$MacOSBuilds,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseMinorVersions,
        
        [Parameter(Mandatory = $false)]
        [int]$PinToMajorVersion
    )
    
    Write-Log "Parsing macOS versions..." -Level INFO
    
    # Filter for released versions only (not beta/RC)
    $releasedVersions = $MacOSBuilds | Where-Object {
        $_.released -and 
        $_.version -match '^\d+\.\d+' -and
        -not ($_.beta -or $_.rc -or $_.version -match 'beta|rc|preview|seed')
    }
    
    Write-Log "Found $($releasedVersions.Count) released macOS versions" -Level INFO
    
    # Parse versions and create custom objects
    $parsedVersions = @()
    
    foreach ($build in $releasedVersions) {
        if ($build.version -match '^(\d+)\.(\d+)(?:\.(\d+))?') {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            $patch = if ($Matches[3]) { [int]$Matches[3] } else { 0 }
            
            $parsedVersions += [PSCustomObject]@{
                Version      = $build.version
                Build        = $build.build
                MajorVersion = $major
                MinorVersion = $minor
                PatchVersion = $patch
                Released     = $build.released
                ReleaseDate  = if ($build.releaseDate) { $build.releaseDate } else { "Unknown" }
                FullVersion  = "$major.$minor.$patch"
            }
        }
    }
    
    # Sort by version (descending)
    $sortedVersions = $parsedVersions | Sort-Object MajorVersion, MinorVersion, PatchVersion -Descending
    
    # Filter by major version if pinned
    if ($PinToMajorVersion) {
        Write-Log "Filtering to only macOS $PinToMajorVersion.x versions..." -Level INFO
        $sortedVersions = $sortedVersions | Where-Object { $_.MajorVersion -eq $PinToMajorVersion }
        
        if ($sortedVersions.Count -eq 0) {
            throw "No versions found for macOS $PinToMajorVersion. Check that this major version exists in AppleDB."
        }
        
        Write-Log "Found $($sortedVersions.Count) versions for macOS $PinToMajorVersion" -Level INFO
    }
    
    if ($UseMinorVersions -or $PinToMajorVersion) {
        # Group by major.minor and get the latest patch for each
        $uniqueVersions = $sortedVersions | 
            Group-Object { "$($_.MajorVersion).$($_.MinorVersion)" } |
            ForEach-Object { $_.Group | Select-Object -First 1 }
    }
    else {
        # Group by major version and get the latest minor.patch for each
        $uniqueVersions = $sortedVersions | 
            Group-Object MajorVersion |
            ForEach-Object { $_.Group | Select-Object -First 1 }
    }
    
    # Sort again after grouping
    $uniqueVersions = $uniqueVersions | Sort-Object MajorVersion, MinorVersion, PatchVersion -Descending
    
    Write-Log "Unique versions identified: $($uniqueVersions.Count)" -Level INFO
    
    return $uniqueVersions
}

# ============================================================================
# CALCULATE TARGET VERSION
# ============================================================================
function Get-TargetMacOSVersion {
    param(
        [Parameter(Mandatory = $true)]
        [array]$SortedVersions,
        
        [Parameter(Mandatory = $true)]
        [int]$VersionsBelow
    )
    
    if ($SortedVersions.Count -eq 0) {
        throw "No macOS versions found to calculate target version"
    }
    
    $latestVersion = $SortedVersions[0]
    Write-Log "Latest macOS version: $($latestVersion.Version) (Build: $($latestVersion.Build))" -Level INFO
    
    # Display top versions
    Write-Log "Top available versions:" -Level DEBUG
    $SortedVersions | Select-Object -First ([Math]::Min(5, $SortedVersions.Count)) | ForEach-Object {
        Write-Log "  - macOS $($_.Version) (Build: $($_.Build))" -Level DEBUG
    }
    
    if ($SortedVersions.Count -le $VersionsBelow) {
        Write-Log "Not enough version history. Using oldest available version." -Level WARNING
        $targetVersion = $SortedVersions[-1]
    }
    else {
        $targetVersion = $SortedVersions[$VersionsBelow]
    }
    
    Write-Log "Target minimum version (${VersionsBelow} below latest): $($targetVersion.Version)" -Level SUCCESS
    
    return $targetVersion
}

# ============================================================================
# GET MICROSOFT GRAPH ACCESS TOKEN
# ============================================================================
function Get-GraphAccessToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $true)]
        [string]$ClientSecret
    )
    
    Write-Log "Authenticating to Microsoft Graph..." -Level INFO
    
    try {
        $body = @{
            grant_type    = "client_credentials"
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = "https://graph.microsoft.com/.default"
        }
        
        $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ErrorAction Stop
        
        Write-Log "Successfully authenticated to Microsoft Graph" -Level SUCCESS
        
        # Return the access_token directly - let PowerShell handle type conversion
        return $response.access_token
    }
    catch {
        Write-Log "Failed to authenticate to Microsoft Graph: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

# ============================================================================
# GET CURRENT COMPLIANCE POLICY
# ============================================================================
function Get-IntuneCompliancePolicy {
    param(
        [Parameter(Mandatory = $true)]
        $AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$PolicyId
    )
    
    Write-Log "Retrieving current compliance policy..." -Level INFO
    
    try {
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Content-Type"  = "application/json"
        }
        
        $policyUrl = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies/$PolicyId"
        $policy = Invoke-RestMethod -Uri $policyUrl -Headers $headers -Method Get -ErrorAction Stop
        
        Write-Log "Successfully retrieved compliance policy: $($policy.displayName)" -Level SUCCESS
        Write-Log "Current OS minimum version: $($policy.osMinimumVersion)" -Level INFO
        
        return $policy
    }
    catch {
        Write-Log "Failed to retrieve compliance policy: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

# ============================================================================
# UPDATE COMPLIANCE POLICY
# ============================================================================
function Update-IntuneCompliancePolicy {
    param(
        [Parameter(Mandatory = $true)]
        $AccessToken,
        
        [Parameter(Mandatory = $true)]
        [string]$PolicyId,
        
        [Parameter(Mandatory = $true)]
        [string]$NewMinimumVersion,
        
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )
    
    if ($WhatIf) {
        Write-Log "[WHATIF] Would update compliance policy to minimum version: $NewMinimumVersion" -Level WARNING
        return $true
    }
    
    Write-Log "Updating compliance policy to minimum version: $NewMinimumVersion..." -Level INFO
    
    try {
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Content-Type"  = "application/json"
        }
        
        # Prepare update body
        $updateBody = @{
            "@odata.type"    = "#microsoft.graph.macOSCompliancePolicy"
            osMinimumVersion = $NewMinimumVersion
        } | ConvertTo-Json
        
        $policyUrl = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies/$PolicyId"
        $result = Invoke-RestMethod -Uri $policyUrl -Headers $headers -Method Patch -Body $updateBody -ErrorAction Stop
        
        Write-Log "Successfully updated compliance policy!" -Level SUCCESS
        Write-Log "New minimum OS version: $NewMinimumVersion" -Level SUCCESS
        
        return $true
    }
    catch {
        Write-Log "Failed to update compliance policy: $($_.Exception.Message)" -Level ERROR
        
        if ($_.Exception.Response) {
            try {
                $responseStream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($responseStream)
                $responseBody = $reader.ReadToEnd()
                Write-Log "Response details: $responseBody" -Level ERROR
            }
            catch {
                Write-Log "Could not read error response details" -Level ERROR
            }
        }
        
        throw
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
function Main {
    $startTime = Get-Date
    
    try {
        Write-Log "========================================" -Level INFO
        Write-Log "Intune macOS Compliance Policy Updater" -Level INFO
        Write-Log "Version 2.0 (All-in-One)" -Level INFO
        Write-Log "========================================" -Level INFO
        Write-Log "Start time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level INFO
        Write-Log "" -Level INFO
        
        # Load configuration
        $config = Get-Configuration
        
        # Run tests if requested
        if ($script:testMode) {
            $testsPass = Test-Prerequisites
            if (-not $testsPass) {
                Write-Log "Prerequisites tests failed. Please fix issues before continuing." -Level ERROR
                throw "Prerequisites check failed"
            }
            Write-Log "All prerequisites tests passed!" -Level SUCCESS
            Write-Log "" -Level INFO
        }
        
        # Step 1: Get macOS versions from AppleDB
        $macOSBuilds = Get-MacOSVersionsFromAppleDB
        
        # Step 2: Parse and sort versions
        $sortedVersions = Get-LatestMacOSVersions -MacOSBuilds $macOSBuilds -UseMinorVersions:$config.UseMinorVersions -PinToMajorVersion $config.PinToMajorVersion
        
        # Step 3: Calculate target version
        $targetVersion = Get-TargetMacOSVersion -SortedVersions $sortedVersions -VersionsBelow $config.VersionsBelow
        
        Write-Log "" -Level INFO
        
        # Step 4: Authenticate to Microsoft Graph
        $accessToken = Get-GraphAccessToken -TenantId $config.TenantId -ClientId $config.ClientId -ClientSecret $config.ClientSecret
        
        # Step 5: Get current compliance policy
        $currentPolicy = Get-IntuneCompliancePolicy -AccessToken $accessToken -PolicyId $config.CompliancePolicyId
        
        # Step 6: Check if update is needed
        Write-Log "" -Level INFO
        if ($currentPolicy.osMinimumVersion -eq $targetVersion.FullVersion) {
            Write-Log "========================================" -Level SUCCESS
            Write-Log "COMPLIANCE POLICY IS UP TO DATE" -Level SUCCESS
            Write-Log "========================================" -Level SUCCESS
            Write-Log "Policy: $($currentPolicy.displayName)" -Level INFO
            Write-Log "Current minimum version: $($currentPolicy.osMinimumVersion)" -Level INFO
            Write-Log "Target minimum version: $($targetVersion.FullVersion)" -Level INFO
            Write-Log "No update needed!" -Level SUCCESS
        }
        else {
            Write-Log "========================================" -Level WARNING
            Write-Log "UPDATE REQUIRED" -Level WARNING
            Write-Log "========================================" -Level WARNING
            Write-Log "Policy: $($currentPolicy.displayName)" -Level INFO
            Write-Log "Current minimum version: $($currentPolicy.osMinimumVersion)" -Level WARNING
            Write-Log "New minimum version: $($targetVersion.FullVersion)" -Level WARNING
            Write-Log "" -Level INFO
            
            # Step 7: Update compliance policy
            $success = Update-IntuneCompliancePolicy -AccessToken $accessToken -PolicyId $config.CompliancePolicyId -NewMinimumVersion $targetVersion.FullVersion -WhatIf:$config.WhatIf
            
            if ($success) {
                Write-Log "" -Level INFO
                Write-Log "========================================" -Level SUCCESS
                Write-Log "COMPLIANCE POLICY UPDATE COMPLETE" -Level SUCCESS
                Write-Log "========================================" -Level SUCCESS
            }
        }
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Log "" -Level INFO
        Write-Log "Script completed successfully" -Level SUCCESS
        Write-Log "Duration: $($duration.TotalSeconds) seconds" -Level INFO
        Write-Log "End time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level INFO
        
        # Return success object for Azure Automation
        return @{
            Success            = $true
            PolicyId           = $config.CompliancePolicyId
            PreviousVersion    = $currentPolicy.osMinimumVersion
            NewVersion         = $targetVersion.FullVersion
            Updated            = ($currentPolicy.osMinimumVersion -ne $targetVersion.FullVersion)
            Duration           = $duration.TotalSeconds
            Timestamp          = Get-Date -Format 'o'
        }
    }
    catch {
        Write-Log "" -Level ERROR
        Write-Log "========================================" -Level ERROR
        Write-Log "SCRIPT FAILED" -Level ERROR
        Write-Log "========================================" -Level ERROR
        Write-Log "Error: $($_.Exception.Message)" -Level ERROR
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level ERROR
        
        # Return failure object for Azure Automation
        return @{
            Success   = $false
            Error     = $_.Exception.Message
            Timestamp = Get-Date -Format 'o'
        }
    }
}

# ============================================================================
# EXECUTE MAIN
# ============================================================================
$result = Main

# Output result object for Azure Automation
if ($script:isAzureAutomation) {
    Write-Output ""
    Write-Output "========================================="
    Write-Output "EXECUTION SUMMARY"
    Write-Output "========================================="
    Write-Output ($result | ConvertTo-Json -Depth 3)
}

# Exit with appropriate code
if ($result.Success) {
    exit 0
}
else {
    exit 1
}
