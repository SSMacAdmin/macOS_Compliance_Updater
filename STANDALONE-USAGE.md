# Standalone Usage Guide

## 🎯 Using the All-in-One Script

The `Update-IntuneMacOSCompliance.ps1` script works in **standalone mode** without any external configuration files or wrapper scripts.

---

## 📋 Prerequisites

1. **Azure App Registration** with:
   - `DeviceManagementConfiguration.ReadWrite.All` permission
   - Admin consent granted
   - Client Secret created

2. **PowerShell 5.1 or later**

3. **Your IDs ready**:
   - Tenant ID
   - Client ID (Application ID)
   - Client Secret
   - Compliance Policy ID

---

## 🚀 Quick Start

### Option 1: Pass Parameters Directly

```powershell
.\Update-IntuneMacOSCompliance.ps1 `
    -TenantId "00000000-0000-0000-0000-000000000000" `
    -ClientId "11111111-1111-1111-1111-111111111111" `
    -ClientSecret "your-secret-here" `
    -CompliancePolicyId "22222222-2222-2222-2222-222222222222"
```

### Option 2: Use Environment Variables

```powershell
# Set environment variables (once per session)
$env:INTUNE_TENANT_ID = "00000000-0000-0000-0000-000000000000"
$env:INTUNE_CLIENT_ID = "11111111-1111-1111-1111-111111111111"
$env:INTUNE_CLIENT_SECRET = "your-secret-here"
$env:INTUNE_POLICY_ID = "22222222-2222-2222-2222-222222222222"

# Run the script (no parameters needed)
.\Update-IntuneMacOSCompliance.ps1
```

### Option 3: Persistent Environment Variables (Windows)

```powershell
# Set permanently (survives restarts)
[System.Environment]::SetEnvironmentVariable('INTUNE_TENANT_ID', 'your-tenant-id', 'User')
[System.Environment]::SetEnvironmentVariable('INTUNE_CLIENT_ID', 'your-client-id', 'User')
[System.Environment]::SetEnvironmentVariable('INTUNE_CLIENT_SECRET', 'your-secret', 'User')
[System.Environment]::SetEnvironmentVariable('INTUNE_POLICY_ID', 'your-policy-id', 'User')

# Restart PowerShell, then run
.\Update-IntuneMacOSCompliance.ps1
```

---

## 🧪 Testing

### Test with WhatIf Mode

See what would happen without making changes:

```powershell
.\Update-IntuneMacOSCompliance.ps1 -WhatIf
```

### Run Prerequisites Tests

Validate your setup before running:

```powershell
.\Update-IntuneMacOSCompliance.ps1 -RunTests
```

### Combined Test Mode

```powershell
.\Update-IntuneMacOSCompliance.ps1 -RunTests -WhatIf
```

---

## ⚙️ Configuration Options

### Change Number of Versions Behind

```powershell
# Stay 3 major versions behind instead of 2
.\Update-IntuneMacOSCompliance.ps1 -VersionsBelow 3
```

### Use Minor Versions Instead of Major

```powershell
# Track by minor versions (15.2, 15.1, 15.0) instead of major (15, 14, 13)
.\Update-IntuneMacOSCompliance.ps1 -UseMinorVersions
```

### Pin to Specific Major Version

```powershell
# Stay on macOS 15, ignore macOS 16 completely
# If latest 15.x is 15.7, and VersionsBelow is 2, sets minimum to 15.5
.\Update-IntuneMacOSCompliance.ps1 -PinToMajorVersion 15 -VersionsBelow 2
```

### Combine Options

```powershell
.\Update-IntuneMacOSCompliance.ps1 `
    -PinToMajorVersion 15 `
    -VersionsBelow 1 `
    -WhatIf
```

---

## 📊 Output Examples

### Successful Run (No Update Needed)

```
========================================
Intune macOS Compliance Policy Updater
Version 2.0 (All-in-One)
========================================
Running in standalone mode
Loading credentials from environment variables...
Configuration loaded successfully
Fetching macOS versions from AppleDB API...
Successfully retrieved 487 macOS builds from AppleDB
Latest macOS version: 15.2 (Build: 24C101)
Target minimum version (2 below latest): 13.7
Authenticating to Microsoft Graph...
Successfully authenticated to Microsoft Graph
Retrieving current compliance policy...
Successfully retrieved compliance policy: macOS Compliance - Standard
Current OS minimum version: 13.7

========================================
COMPLIANCE POLICY IS UP TO DATE
========================================
No update needed!
```

### Successful Run (Update Applied)

```
========================================
UPDATE REQUIRED
========================================
Policy: macOS Compliance - Standard
Current minimum version: 13.5
New minimum version: 13.7

Updating compliance policy to minimum version: 13.7...
Successfully updated compliance policy!
New minimum OS version: 13.7

========================================
COMPLIANCE POLICY UPDATE COMPLETE
========================================
```

### WhatIf Mode

```
========================================
UPDATE REQUIRED
========================================
Current minimum version: 13.5
New minimum version: 13.7

[WHATIF] Would update compliance policy to minimum version: 13.7
```

---

## 🔒 Security Best Practices

### DON'T: Hardcode Secrets in Scripts

❌ **Never do this:**
```powershell
# BAD - Don't hardcode secrets!
.\Update-IntuneMacOSCompliance.ps1 `
    -TenantId "xxx" `
    -ClientId "xxx" `
    -ClientSecret "super-secret-password-123"
```

### DO: Use Secure Storage

✅ **Use environment variables:**
```powershell
# Store securely in environment
$env:INTUNE_CLIENT_SECRET = "secret"
```

✅ **Or use Azure Key Vault:**
```powershell
Install-Module -Name Az.KeyVault
Connect-AzAccount

$secret = Get-AzKeyVaultSecret -VaultName "MyVault" -Name "IntuneSecret"
$env:INTUNE_CLIENT_SECRET = $secret.SecretValueText

.\Update-IntuneMacOSCompliance.ps1
```

✅ **Or use Windows Credential Manager:**
```powershell
# Store in Windows Credential Manager
cmdkey /generic:IntuneClientSecret /user:ClientSecret /pass:your-secret

# Retrieve when needed
$cred = Get-StoredCredential -Target "IntuneClientSecret"
$env:INTUNE_CLIENT_SECRET = $cred.GetNetworkCredential().Password
```

---

## 🔍 Troubleshooting

### "Missing required configuration"

Make sure all 4 values are provided:
```powershell
# Check environment variables
Write-Host "Tenant ID: $env:INTUNE_TENANT_ID"
Write-Host "Client ID: $env:INTUNE_CLIENT_ID"
Write-Host "Secret Set: $([bool]$env:INTUNE_CLIENT_SECRET)"
Write-Host "Policy ID: $env:INTUNE_POLICY_ID"
```

### "Failed to authenticate to Microsoft Graph"

1. Verify Tenant ID is correct
2. Verify Client ID is correct
3. Check Client Secret hasn't expired
4. Ensure admin consent was granted for API permissions

### Run Tests to Diagnose

```powershell
.\Update-IntuneMacOSCompliance.ps1 -RunTests
```

This will test:
- ✓ PowerShell version
- ✓ Internet connectivity
- ✓ AppleDB API access
- ✓ Azure authentication
- ✓ Microsoft Graph permissions
- ✓ Compliance policy access

---

## 📝 Common Scenarios

### Scenario 1: Weekly Automated Update

```powershell
# Set environment variables once
$env:INTUNE_TENANT_ID = "xxx"
$env:INTUNE_CLIENT_ID = "xxx"
$env:INTUNE_CLIENT_SECRET = "xxx"
$env:INTUNE_POLICY_ID = "xxx"

# Schedule in Task Scheduler to run weekly
# Script will automatically use environment variables
```

### Scenario 2: Manual Monthly Review

```powershell
# Check what would change
.\Update-IntuneMacOSCompliance.ps1 -WhatIf

# If you approve, run for real
.\Update-IntuneMacOSCompliance.ps1
```

### Scenario 3: Pin to Major Version During Testing

```powershell
# Keep production on macOS 15 while testing 16
$env:INTUNE_POLICY_ID = "prod-policy-id"
.\Update-IntuneMacOSCompliance.ps1 -PinToMajorVersion 15 -VersionsBelow 2

# Test policy can track macOS 16
$env:INTUNE_POLICY_ID = "test-policy-id"
.\Update-IntuneMacOSCompliance.ps1 -PinToMajorVersion 16 -VersionsBelow 1
```

---

## 🎯 Quick Reference

### All Parameters

```powershell
.\Update-IntuneMacOSCompliance.ps1 `
    -TenantId "xxx" `              # Azure AD Tenant ID
    -ClientId "xxx" `              # App Registration Client ID
    -ClientSecret "xxx" `          # App Registration Secret
    -CompliancePolicyId "xxx" `    # Intune Policy ID
    -VersionsBelow 2 `             # How many versions behind (1-10)
    -UseMinorVersions `            # Track minor versions instead of major
    -PinToMajorVersion 15 `        # Pin to specific major version (e.g., 15)
    -WhatIf `                      # Test mode - no changes
    -RunTests                      # Run prerequisite tests
```

### Environment Variables

```powershell
$env:INTUNE_TENANT_ID       # Azure AD Tenant ID
$env:INTUNE_CLIENT_ID       # App Registration Client ID
$env:INTUNE_CLIENT_SECRET   # App Registration Secret
$env:INTUNE_POLICY_ID       # Intune Policy ID
```

---

## 💡 Pro Tips

1. **Always test first**: Use `-WhatIf` before running in production
2. **Use environment variables**: Safer than passing secrets as parameters
3. **Schedule it**: Set up Task Scheduler for hands-off operation
4. **Monitor logs**: Check output regularly for issues
5. **Update before expiry**: Rotate client secrets before they expire
6. **Test after changes**: Run with `-RunTests` after any configuration changes

---

## 🆘 Getting Help

If you encounter issues:

1. Run with `-RunTests` to diagnose
2. Check script output for specific errors
3. Verify all prerequisites are met
4. Ensure API permissions are granted
5. Check Azure AD sign-in logs

For detailed troubleshooting, see the main README.md

---

**Ready to automate? Just set your environment variables and run!** 🚀
