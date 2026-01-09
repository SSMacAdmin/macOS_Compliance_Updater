<#
.SYNOPSIS
    Diagnostic script to test Azure Automation configuration for Intune
    
.DESCRIPTION
    This script tests each component separately to identify configuration issues:
    1. Load variables from Azure Automation
    2. Test authentication to Microsoft Graph
    3. Test API permissions
    4. Test policy access
#>

Write-Output "========================================="
Write-Output "Azure Automation Diagnostics"
Write-Output "========================================="
Write-Output ""

# Step 1: Load Variables
Write-Output "[STEP 1] Loading Azure Automation Variables..."
try {
    $tenantId = Get-AutomationVariable -Name "INTUNE_TENANT_ID"
    $clientId = Get-AutomationVariable -Name "INTUNE_CLIENT_ID"
    $clientSecret = Get-AutomationVariable -Name "INTUNE_CLIENT_SECRET"
    $policyId = Get-AutomationVariable -Name "INTUNE_POLICY_ID"
    
    Write-Output "✓ All variables loaded successfully"
    Write-Output "  Tenant ID: $($tenantId.Substring(0,8))..."
    Write-Output "  Client ID: $($clientId.Substring(0,8))..."
    Write-Output "  Secret length: $($clientSecret.Length) chars"
    Write-Output "  Policy ID: $($policyId.Substring(0,8))..."
    Write-Output ""
}
catch {
    Write-Output "✗ Failed to load variables: $($_.Exception.Message)"
    Write-Output ""
    exit 1
}

# Step 2: Test Authentication
Write-Output "[STEP 2] Testing Microsoft Graph Authentication..."
try {
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "https://graph.microsoft.com/.default"
    }
    
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ErrorAction Stop
    
    $accessToken = [string]$response.access_token
    
    Write-Output "✓ Authentication successful"
    Write-Output "  Token type: $($response.token_type)"
    Write-Output "  Token length: $($accessToken.Length) chars"
    Write-Output "  Expires in: $($response.expires_in) seconds"
    Write-Output ""
}
catch {
    Write-Output "✗ Authentication failed"
    Write-Output "  Error: $($_.Exception.Message)"
    
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Output "  Response: $responseBody"
    }
    
    Write-Output ""
    Write-Output "COMMON CAUSES:"
    Write-Output "  - Client secret has expired"
    Write-Output "  - Client ID is incorrect"
    Write-Output "  - Tenant ID is incorrect"
    Write-Output ""
    exit 1
}

# Step 3: Test API Permissions (List all policies)
Write-Output "[STEP 3] Testing Microsoft Graph API Permissions..."
try {
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    
    $apiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies"
    $policies = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -ErrorAction Stop
    
    Write-Output "✓ API access successful"
    Write-Output "  Found $($policies.value.Count) compliance policies"
    Write-Output ""
    
    if ($policies.value.Count -gt 0) {
        Write-Output "Available policies:"
        foreach ($policy in $policies.value) {
            $policyIsMacOS = $policy.'@odata.type' -eq '#microsoft.graph.macOSCompliancePolicy'
            $indicator = if ($policy.id -eq $policyId) { "← TARGET POLICY" } else { "" }
            $osType = if ($policyIsMacOS) { "[macOS]" } else { "[Other]" }
            
            Write-Output "  $osType $($policy.displayName) (ID: $($policy.id)) $indicator"
        }
        Write-Output ""
    }
}
catch {
    Write-Output "✗ API access failed"
    Write-Output "  Error: $($_.Exception.Message)"
    Write-Output "  Status: $($_.Exception.Response.StatusCode.value__) $($_.Exception.Response.StatusCode)"
    
    if ($_.Exception.Response.StatusCode.value__ -eq 403) {
        Write-Output ""
        Write-Output "PERMISSION ISSUE DETECTED:"
        Write-Output "  The app registration doesn't have the required permissions."
        Write-Output ""
        Write-Output "FIX:"
        Write-Output "  1. Go to Azure AD → App Registrations → Your App"
        Write-Output "  2. Click 'API permissions'"
        Write-Output "  3. Verify 'DeviceManagementConfiguration.ReadWrite.All' exists"
        Write-Output "  4. Click 'Grant admin consent for [Your Org]'"
        Write-Output "  5. Wait 5-10 minutes for permissions to propagate"
        Write-Output ""
    }
    
    exit 1
}

# Step 4: Test Specific Policy Access
Write-Output "[STEP 4] Testing Access to Target Policy..."
try {
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    
    $policyUrl = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies/$policyId"
    $policy = Invoke-RestMethod -Uri $policyUrl -Headers $headers -Method Get -ErrorAction Stop
    
    Write-Output "✓ Policy access successful"
    Write-Output "  Policy Name: $($policy.displayName)"
    Write-Output "  Policy Type: $($policy.'@odata.type')"
    Write-Output "  Current Minimum OS: $($policy.osMinimumVersion)"
    Write-Output ""
}
catch {
    Write-Output "✗ Policy access failed"
    Write-Output "  Error: $($_.Exception.Message)"
    Write-Output "  Status: $($_.Exception.Response.StatusCode.value__) $($_.Exception.Response.StatusCode)"
    
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Output ""
        Write-Output "POLICY NOT FOUND:"
        Write-Output "  The Policy ID in your INTUNE_POLICY_ID variable is incorrect."
        Write-Output ""
        Write-Output "FIX:"
        Write-Output "  1. Go to Intune portal (https://intune.microsoft.com)"
        Write-Output "  2. Navigate to: Devices → macOS → Compliance policies"
        Write-Output "  3. Click on your policy"
        Write-Output "  4. Copy the GUID from the URL"
        Write-Output "  5. Update INTUNE_POLICY_ID variable with correct GUID"
        Write-Output ""
    }
    
    exit 1
}

# Step 5: Test AppleDB API
Write-Output "[STEP 5] Testing AppleDB API Access..."
try {
    $appleDBUrl = "https://api.appledb.dev/ios/macOS/main.json"
    $macOSBuilds = Invoke-RestMethod -Uri $appleDBUrl -Method Get -ErrorAction Stop
    
    Write-Output "✓ AppleDB API accessible"
    Write-Output "  Retrieved $($macOSBuilds.Count) macOS builds"
    Write-Output ""
}
catch {
    Write-Output "✗ AppleDB API failed"
    Write-Output "  Error: $($_.Exception.Message)"
    Write-Output ""
    Write-Output "This may be a temporary issue. Check https://appledb.dev"
    Write-Output ""
}

# Summary
Write-Output "========================================="
Write-Output "DIAGNOSTICS COMPLETE"
Write-Output "========================================="
Write-Output ""
Write-Output "If all steps passed, the main script should work."
Write-Output "If any step failed, follow the fix instructions above."
Write-Output ""
