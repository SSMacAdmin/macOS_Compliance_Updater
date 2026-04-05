# Standalone Usage Guide

Run the macOS compliance updater script locally or in any PowerShell environment outside of Azure Automation.

---

## 📋 Prerequisites

### Required

1. **PowerShell 5.1 or later**
   - Windows: Built-in
   - macOS/Linux: Install PowerShell Core

2. **Azure App Registration** with:
   - **Permission**: `DeviceManagementConfiguration.ReadWrite.All` (Application permission)
   - **Admin consent**: Granted
   - **Client Secret**: Created and not expired

3. **Your Configuration Values**:
   - Tenant ID (Azure AD → Overview)
   - Client ID (App Registration → Overview → Application ID)
   - Client Secret (Value from Certificates & secrets)
   - Compliance Policy ID (From Intune portal URL)

### Optional

- **Scheduled Task** (Windows) or **cron** (macOS/Linux) for automation
- **Secure credential storage** (e.g., Azure Key Vault, LastPass)

---

## 🚀 Quick Start

### Method 1: Pass Parameters Directly

```powershell
.\Update-IntuneMacOSCompliance.ps1 `
    -TenantId "00000000-0000-0000-0000-000000000000" `
    -ClientId "11111111-1111-1111-1111-111111111111" `
    -ClientSecret "your-secret-value-here" `
    -CompliancePolicyId "22222222-2222-2222-2222-222222222222"
```

**⚠️ Security Note:** Passing secrets as parameters may expose them in command history. Use environment variables for better security.

### Method 2: Environment Variables (Recommended)

**Set variables (current session only):**

```powershell
$env:INTUNE_TENANT_ID = "00000000-0000-0000-0000-000000000000"
$env:INTUNE_CLIENT_ID = "11111111-1111-1111-1111-111111111111"
$env:INTUNE_CLIENT_SECRET = "your-secret-value-here"
$env:INTUNE_POLICY_ID = "22222222-2222-2222-2222-222222222222"

# Run the script (no parameters needed)
.\Update-IntuneMacOSCompliance.ps1
```

### Method 3: Persistent Environment Variables

**Windows (PowerShell):**

```powershell
# Set permanently (survives restarts)
[System.Environment]::SetEnvironmentVariable('INTUNE_TENANT_ID', 'your-tenant-id', 'User')
[System.Environment]::SetEnvironmentVariable('INTUNE_CLIENT_ID', 'your-client-id', 'User')
[System.Environment]::SetEnvironmentVariable('INTUNE_CLIENT_SECRET', 'your-secret', 'User')
[System.Environment]::SetEnvironmentVariable('INTUNE_POLICY_ID', 'your-policy-id', 'User')

# Restart PowerShell, then run
.\Update-IntuneMacOSCompliance.ps1
```

**macOS/Linux (bash):**

```bash
# Add to ~/.bashrc or ~/.zshrc
export INTUNE_TENANT_ID="00000000-0000-0000-0000-000000000000"
export INTUNE_CLIENT_ID="11111111-1111-1111-1111-111111111111"
export INTUNE_CLIENT_SECRET="your-secret-value"
export INTUNE_POLICY_ID="22222222-2222-2222-2222-222222222222"

# Reload shell, then run
pwsh -File ./Update-IntuneMacOSCompliance.ps1
```

---

## ⚙️ Configuration Options

### Version Tracking Strategies

**Pin to Major Version** (Recommended for Phased Rollouts)

```powershell
# Stay on macOS 26.x, track minor versions, ignore macOS 27.x
.\Update-IntuneMacOSCompliance.ps1 -PinToMajorVersion 26 -VersionsBelow 2

# If latest macOS 26.x is 26.7:
# → Sets minimum to 26.5 (2 versions behind)
# → Completely ignores macOS 27.x
```

**Use Case:** Testing macOS 27 on pilot group while keeping production on macOS 26.

**Track Minor Versions** (Aggressive Updates)

```powershell
# Track by minor versions across all major versions
.\Update-IntuneMacOSCompliance.ps1 -UseMinorVersions -VersionsBelow 2

# If versions available: 26.7, 26.6, 26.5, 15.7, 15.6, 14.8
# → Sets minimum to 26.5 (includes latest from each major)
```

**Track Major Versions** (Conservative)

```powershell
# Stay N major versions behind latest (default behavior)
.\Update-IntuneMacOSCompliance.ps1 -VersionsBelow 3

# If latest is macOS 26:
# → Sets minimum to macOS 13 (3 major versions behind)
```

### Custom Version Strategy

```powershell
# Stay 1 minor version behind within macOS 26
.\Update-IntuneMacOSCompliance.ps1 `
    -PinToMajorVersion 26 `
    -VersionsBelow 1

# If latest 26.x is 26.7:
# → Sets minimum to 26.6 (very current)
```

---

## 🧪 Testing and Validation

### Test Mode (WhatIf)

See what would change without making updates:

```powershell
.\Update-IntuneMacOSCompliance.ps1 -WhatIf
```

**Example output:**
```
========================================
UPDATE REQUIRED
========================================
Policy: macOS Compliance - Standard
Current minimum version: 26.1.0
New minimum version: 26.3.2

[WHATIF] Would update compliance policy to minimum version: 26.3.2
```

### Run Pre-flight Tests

Validate your setup before execution:

```powershell
.\Update-IntuneMacOSCompliance.ps1 -RunTests
```

**Tests performed:**
- ✓ PowerShell version compatibility
- ✓ Internet connectivity
- ✓ SOFA API accessibility
- ✓ Azure authentication
- ✓ Microsoft Graph permissions
- ✓ Compliance policy access

### Combined Test Mode

```powershell
.\Update-IntuneMacOSCompliance.ps1 -RunTests -WhatIf
```

---

## 📊 Output Examples

### Successful Run (No Update Needed)

```
========================================
Intune macOS Compliance Policy Updater
Version 3.0
========================================
Running in standalone mode
Loading credentials from environment variables...
Configuration loaded successfully
  Authentication: Service Principal
  Policy ID: 36b9b86c...
  Pin to Major Version: 26
  Versions Below: 2

Fetching macOS versions from SOFA (MacAdmins feed)...
Successfully retrieved data from SOFA
Parsed 118 macOS versions from SOFA feed

Filtering to only macOS 26.x versions...
Found 8 versions for macOS 26
Latest macOS version: 26.7 (Build: 26G200)
Target minimum version (2 below latest): 26.5

Authenticating to Microsoft Graph...
Using Service Principal (App Registration) authentication
Successfully authenticated to Microsoft Graph
Authentication method: Service Principal with client secret

Retrieving current compliance policy...
Successfully retrieved compliance policy: macOS Compliance - Standard
Current OS minimum version: 26.5

========================================
COMPLIANCE POLICY IS UP TO DATE
========================================
No update needed!
Policy is already set to: 26.5
```

### Successful Run (Update Applied)

```
========================================
UPDATE REQUIRED
========================================
Policy: macOS Compliance - Production
Current minimum version: 26.1.0
New minimum version: 26.5.0

Updating compliance policy to minimum version: 26.5.0...
Successfully updated compliance policy!
New minimum OS version: 26.5.0

========================================
COMPLIANCE POLICY UPDATE COMPLETE
========================================

Script completed successfully
Duration: 6.2 seconds

{
  "Success": true,
  "PolicyId": "36b9b86c-2297-4c2c-9b25-8c023f9d4d57",
  "PreviousVersion": "26.1.0",
  "NewVersion": "26.5.0",
  "Updated": true,
  "AuthMethod": "Service Principal",
  "Duration": 6.2,
  "Timestamp": "2026-04-05T14:30:00Z"
}
```

### WhatIf Mode Output

```
[WHATIF] Would update compliance policy to minimum version: 26.5.0

Note: Running in WhatIf mode - no changes were made
To apply changes, run without -WhatIf parameter
```

---

## 🔍 Troubleshooting

### "Missing required configuration"

**Cause:** Not all required values provided.

**Fix:** Verify all 4 values are set:

```powershell
# Check environment variables
Write-Host "Tenant ID set: $([bool]$env:INTUNE_TENANT_ID)"
Write-Host "Client ID set: $([bool]$env:INTUNE_CLIENT_ID)"
Write-Host "Secret set: $([bool]$env:INTUNE_CLIENT_SECRET)"
Write-Host "Policy ID set: $([bool]$env:INTUNE_POLICY_ID)"
```

### "Failed to authenticate to Microsoft Graph"

**Possible causes:**
1. Tenant ID incorrect
2. Client ID incorrect
3. Client Secret expired or wrong
4. Admin consent not granted

**Debugging:**

```powershell
# Run with -RunTests to diagnose
.\Update-IntuneMacOSCompliance.ps1 -RunTests

# Check App Registration
# 1. Go to Azure AD → App registrations → Your app
# 2. Verify Application ID matches CLIENT_ID
# 3. Check Certificates & secrets - ensure secret not expired
# 4. Check API permissions - ensure green checkmark for admin consent
```

### "Failed to retrieve macOS versions from SOFA"

**Cause:** Network connectivity or SOFA temporary issue.

**Fix:**
1. Test SOFA URL manually:
   ```powershell
   Invoke-RestMethod -Uri "https://sofa.macadmins.io/v2/macos_data_feed.json"
   ```
2. Check internet connectivity
3. Verify firewall/proxy settings
4. Wait 10 minutes and retry (SOFA updates every 6 hours)

### "No versions found for macOS [X]"

**Cause:** Pinned to a major version that doesn't exist yet.

**Example:** Set `PIN_TO_MAJOR_VERSION = 27` but macOS 27 not released.

**Fix:**
- Check available versions: https://sofa.macadmins.io
- Adjust `PIN_TO_MAJOR_VERSION` to current version
- Or remove pinning to track all versions

### Script runs but policy not updating

**Possible causes:**
1. Policy already at target version (check output)
2. Insufficient permissions (check `DeviceManagementConfiguration.ReadWrite.All`)
3. Wrong Policy ID

**Debugging:**
```powershell
# Check current policy version in Intune
# Compare with script's "Target minimum version" output
# Run with -WhatIf to see what would change
.\Update-IntuneMacOSCompliance-AllInOne.ps1 -WhatIf
```

---

## 💼 Common Scenarios

### Scenario 1: Weekly Automated Update

**Goal:** Automatically keep compliance policy current.

**Setup (Windows Task Scheduler):**

1. Open Task Scheduler
2. Create Task:
   - **Name**: Intune macOS Compliance Update
   - **Trigger**: Weekly, Tuesday 2:00 AM
   - **Action**: Start a program
   - **Program**: `powershell.exe`
   - **Arguments**: `-File "C:\Scripts\Update-IntuneMacOSCompliance.ps1"`
   - **Conditions**: Start only if network available
3. Set environment variables as User-level (Method 3 above)

**Setup (macOS/Linux cron):**

```bash
# Edit crontab
crontab -e

# Add line (runs Tuesdays at 2 AM)
0 2 * * 2 /usr/local/bin/pwsh -File /path/to/Update-IntuneMacOSCompliance.ps1
```

### Scenario 2: Manual Monthly Review

**Goal:** Review changes before applying.

**Workflow:**

```powershell
# Check what would change
.\Update-IntuneMacOSCompliance.ps1 -WhatIf

# Review the proposed version
# If approved, apply the change
.\Update-IntuneMacOSCompliance.ps1

# Or reject and wait until next month
```

### Scenario 3: Phased OS Rollout

**Goal:** Test new macOS on pilot group, keep production stable.

**Production policy (macOS 26 only):**

```powershell
$env:INTUNE_POLICY_ID = "prod-policy-guid-here"

.\Update-IntuneMacOSCompliance.ps1 `
    -PinToMajorVersion 26 `
    -VersionsBelow 2

# Result: Requires macOS 26.5 (if latest 26.x is 26.7)
# Ignores macOS 27.x completely
```

**Pilot policy (macOS 27):**

```powershell
$env:INTUNE_POLICY_ID = "pilot-policy-guid-here"

.\Update-IntuneMacOSCompliance.ps1 `
    -PinToMajorVersion 27 `
    -VersionsBelow 1

# Result: Requires macOS 27.2 (if latest 27.x is 27.3)
# Always tracking latest macOS
```

### Scenario 4: CI/CD Pipeline Integration

**Goal:** Automatically update policy when new versions release.

**Azure DevOps Pipeline:**

```yaml
trigger:
  schedules:
  - cron: "0 2 * * 2"  # Tuesdays at 2 AM
    branches:
      include:
      - main

pool:
  vmImage: 'windows-latest'

steps:
- task: PowerShell@2
  inputs:
    filePath: 'Update-IntuneMacOSCompliance.ps1'
  env:
    INTUNE_TENANT_ID: $(TenantId)
    INTUNE_CLIENT_ID: $(ClientId)
    INTUNE_CLIENT_SECRET: $(ClientSecret)
    INTUNE_POLICY_ID: $(PolicyId)
```

**GitHub Actions:**

```yaml
name: Update Intune Compliance
on:
  schedule:
    - cron: '0 2 * * 2'  # Tuesdays at 2 AM UTC

jobs:
  update-compliance:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run compliance update
        run: ./Update-IntuneMacOSCompliance.ps1
        env:
          INTUNE_TENANT_ID: ${{ secrets.INTUNE_TENANT_ID }}
          INTUNE_CLIENT_ID: ${{ secrets.INTUNE_CLIENT_ID }}
          INTUNE_CLIENT_SECRET: ${{ secrets.INTUNE_CLIENT_SECRET }}
          INTUNE_POLICY_ID: ${{ secrets.INTUNE_POLICY_ID }}
```

---

## 🎯 All Parameters Reference

```powershell
.\Update-IntuneMacOSCompliance.ps1 `
    -TenantId "xxx" `              # Azure AD Tenant ID
    -ClientId "xxx" `              # App Registration Client ID
    -ClientSecret "xxx" `          # App Registration Secret
    -CompliancePolicyId "xxx" `    # Intune Policy ID (GUID)
    -PinToMajorVersion 26 `        # Pin to specific major version (0 = disabled)
    -VersionsBelow 2 `             # How many versions behind (1-10, default: 2)
    -UseMinorVersions `            # Track minor versions instead of major
    -WhatIf `                      # Test mode - show changes without applying
    -RunTests                      # Run prerequisite tests before execution
```

### Environment Variables

```powershell
$env:INTUNE_TENANT_ID       # Azure AD Tenant ID
$env:INTUNE_CLIENT_ID       # App Registration Client ID
$env:INTUNE_CLIENT_SECRET   # App Registration Secret
$env:INTUNE_POLICY_ID       # Intune Policy ID (GUID)
```

---

## 💡 Pro Tips

### Security Best Practices

1. **Use environment variables** instead of parameters (avoids command history)
2. **Rotate client secrets** before they expire (24 months max)
3. **Use Azure Key Vault** for production deployments
4. **Set calendar reminders** for secret expiration (30 days before)
5. **Store secrets securely** (never commit to source control)

### Operational Best Practices

1. **Test with -WhatIf first** before production runs
2. **Run -RunTests** after any configuration changes
3. **Pin to major version** for controlled OS rollouts
4. **Schedule during off-hours** (low user impact)
5. **Monitor execution output** regularly
6. **Keep client secret current** (rotate before expiration)

### Version Strategy Tips

**Conservative (Large Enterprise):**
```powershell
-VersionsBelow 3  # Stay 3 major versions behind
```

**Moderate (Standard):**
```powershell
-PinToMajorVersion 26 -VersionsBelow 2  # Stay current within pinned version
```

**Aggressive (Early Adopter):**
```powershell
-PinToMajorVersion 27 -VersionsBelow 1  # Track latest OS closely
```

---

## 📚 Additional Resources

- [Azure Automation Setup Guide](AZURE-AUTOMATION-SETUP.md) - For serverless deployment
- [Version Strategies Guide](VERSION-STRATEGIES.md) - Detailed versioning explanation
- [SOFA Feed](https://sofa.macadmins.io) - Data source for macOS versions
- [Microsoft Graph API Docs](https://docs.microsoft.com/graph/)
- [Intune Compliance Policies](https://docs.microsoft.com/mem/intune/protect/)

---

## 🆘 Getting Help

**Debugging workflow:**

1. **Run prerequisite tests**:
   ```powershell
   .\Update-IntuneMacOSCompliance.ps1 -RunTests
   ```

2. **Test with WhatIf**:
   ```powershell
   .\Update-IntuneMacOSCompliance.ps1 -WhatIf
   ```

3. **Check authentication**:
   - Verify all 4 environment variables/parameters
   - Confirm App Registration has correct permissions
   - Ensure admin consent granted (green checkmark)

4. **Verify Policy ID**:
   - Go to Intune portal
   - Open your compliance policy
   - Copy GUID from URL

5. **Test SOFA connectivity**:
   ```powershell
   Invoke-RestMethod -Uri "https://sofa.macadmins.io/v2/macos_data_feed.json"
   ```

**Still having issues?** Open a GitHub issue with:
- Full error message
- PowerShell version (`$PSVersionTable.PSVersion`)
- Output from `-RunTests`
- Redacted configuration (show variable names, not values)

---

## 🔄 Migrating to Azure Automation

For zero-maintenance deployment, consider Azure Automation with Managed Identity:

**Benefits:**
- ✅ No credential management
- ✅ Automatic scheduling
- ✅ Built-in monitoring
- ✅ No infrastructure needed
- ✅ ~$2.60/month cost

See **[AZURE-AUTOMATION-SETUP.md](AZURE-AUTOMATION-SETUP.md)** for complete instructions.

---

**Ready to automate? Set your environment variables and run!** 