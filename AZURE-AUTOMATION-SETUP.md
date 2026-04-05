# Azure Automation Setup Guide

Complete step-by-step guide to set up automated macOS compliance policy management in Azure Automation.

---

## 🎯 Overview

This guide covers:
- ✅ Creating Azure Automation Account
- ✅ Choosing authentication method (Managed Identity vs Service Principal)
- ✅ Configuring permissions and variables
- ✅ Uploading and testing the runbook
- ✅ Scheduling automated execution
- ✅ Monitoring and troubleshooting

**Time required:** 15-20 minutes

---

## 🔐 Choose Your Authentication Method

The script supports two authentication methods:

### Option A: Managed Identity ⭐ RECOMMENDED

**Advantages:**
- ✅ **Zero maintenance** - No credential rotation ever
- ✅ **No secrets** - Nothing to expire or manage
- ✅ **More secure** - No credentials stored anywhere
- ✅ **Azure best practice** - Microsoft's recommended approach

**Requirements:**
- PowerShell/Cloud Shell access to grant permissions (one-time)

### Option B: Service Principal

**Advantages:**
- ✅ **Portal-only setup** - No PowerShell required
- ✅ **Works everywhere** - Azure, local, CI/CD pipelines

**Drawbacks:**
- ⚠️ **Requires maintenance** - Client secret expires (24 months max)
- ⚠️ **Manual rotation** - Must update secret before expiration
- ⚠️ **Stored credential** - Secret saved in Automation variables

---

**💡 Recommendation:** Use **Managed Identity** for production Azure Automation deployments. It's more secure and requires zero ongoing maintenance.

Both methods are fully supported, and you can migrate from Service Principal to Managed Identity later (see `MANAGED-IDENTITY-MIGRATION.md`).

---

## Part 1: Create Azure Automation Account

### Step 1.1: Create the Account

1. Go to [Azure Portal](https://portal.azure.com)
2. Search for **"Automation Accounts"** and select it
3. Click **+ Create**
4. Configure:
   - **Subscription**: Your subscription
   - **Resource group**: Create new or select existing (e.g., `rg-automation`)
   - **Name**: `intune-macos-automation`
   - **Region**: Choose region closest to you
5. Click **Review + Create** → **Create**
6. Wait ~1 minute for deployment

---

## Part 2A: Set Up Managed Identity (RECOMMENDED)

Follow this section if you chose **Managed Identity** authentication.

### Step 2A.1: Enable System-Assigned Managed Identity

1. Navigate to your **Automation Account**
2. Go to **Identity** (under Account Settings)
3. On the **System assigned** tab:
   - Toggle **Status** to **On**
   - Click **Save** → **Yes**
4. **Copy the Object (principal) ID** - you'll need this next


### Step 2A.2: Grant Microsoft Graph Permissions

You need to grant the managed identity permission to read/write Intune compliance policies.

**Using Azure Cloud Shell (PowerShell):**

1. In Azure Portal, click the **Cloud Shell** icon (>_) in the top toolbar
2. Select **PowerShell** environment
3. Run the following commands:

```powershell
# Install Microsoft Graph PowerShell module (if not already installed)
if (!(Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.Read.All","AppRoleAssignment.ReadWrite.All"

# Replace with your managed identity's Object ID from Step 2A.1
$managedIdentityId = "PASTE-YOUR-OBJECT-ID-HERE"

# Microsoft Graph application ID (always the same)
$graphAppId = "00000003-0000-0000-c000-000000000000"

# Get the Microsoft Graph service principal
$graphSP = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'"

# Get the permission ID for DeviceManagementConfiguration.ReadWrite.All
$permission = $graphSP.AppRoles | Where-Object {
    $_.Value -eq "DeviceManagementConfiguration.ReadWrite.All"
}

# Grant the permission to the managed identity
New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $managedIdentityId `
    -PrincipalId $managedIdentityId `
    -ResourceId $graphSP.Id `
    -AppRoleId $permission.Id

Write-Host "✓ Permission granted successfully!" -ForegroundColor Green
```

**Expected output:**
```
✓ Permission granted successfully!
```

### Step 2A.3: Verify the Permission

Confirm the permission was granted:

```powershell
# Verify the assignment
$assignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId

# Display the permission
$assignments | Select-Object -First 1 | ForEach-Object {
    $role = (Get-MgServicePrincipal -ServicePrincipalId $_.ResourceId).AppRoles | 
            Where-Object Id -eq $_.AppRoleId
    [PSCustomObject]@{
        Permission = $role.Value
        ResourceName = (Get-MgServicePrincipal -ServicePrincipalId $_.ResourceId).DisplayName
    }
}
```

**Expected output:**
```
Permission                                      ResourceName
----------                                      ------------
DeviceManagementConfiguration.ReadWrite.All     Microsoft Graph
```

✅ **You're done with authentication setup! Skip to Part 3.**

---

## Part 2B: Set Up Service Principal (ALTERNATIVE)

Follow this section if you chose **Service Principal** authentication.

### Step 2B.1: Create App Registration

1. Go to **Azure Active Directory**
2. Navigate to **App registrations** → **New registration**
3. Configure:
   - **Name**: `Intune-macOS-Compliance-Automation`
   - **Supported account types**: Accounts in this organizational directory only
   - **Redirect URI**: Leave blank
4. Click **Register**

### Step 2B.2: Grant API Permissions

1. In your new app registration, go to **API permissions**
2. Click **Add a permission**
3. Select **Microsoft Graph** → **Application permissions**
4. Search for and check: **`DeviceManagementConfiguration.ReadWrite.All`**
5. Click **Add permissions**
6. Click **Grant admin consent for [Your Organization]**
7. Confirm by clicking **Yes**

**Verify:** You should see a green checkmark in the "Status" column.

### Step 2B.3: Create Client Secret

1. Go to **Certificates & secrets** → **Client secrets** tab
2. Click **New client secret**
3. Configure:
   - **Description**: `Intune Compliance Automation`
   - **Expires**: 24 months (or your preference)
4. Click **Add**
5. **⚠️ CRITICAL**: Immediately copy the **Value** (you can't see it again!)

### Step 2B.4: Collect Required IDs

You'll need these three values:

1. **Tenant ID**:
   - Go to **Azure Active Directory** → **Overview**
   - Copy the **Tenant ID**

2. **Client ID**:
   - Go to your **App Registration** → **Overview**
   - Copy the **Application (client) ID**

3. **Client Secret**:
   - The value you copied in Step 2B.3

**📝 Save these securely** - you'll need them in Part 3.

---

## Part 3: Configure Automation Variables

### Step 3.1: Get Your Compliance Policy ID

Before creating variables, get your policy ID:

1. Go to [Intune Portal](https://intune.microsoft.com)
2. Navigate to: **Devices** → **Compliance** → **Policies**
3. Click on your macOS compliance policy
4. Copy the **GUID** from the URL bar

Example URL:
```
https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DeviceCompliancePolicyMenuBlade/.../policyId/36b9b86c-2297-4c2c-9b25-8c023f9d4d57
                                                                                                          ↑ This is your Policy ID
```

### Step 3.2: Create Variables

Navigate to your **Automation Account** → **Variables** (under Shared Resources).

---

#### For ALL Users (Required)

**Variable 1: INTUNE_POLICY_ID**
- Click **+ Add a variable**
- **Name**: `INTUNE_POLICY_ID`
- **Description**: `Intune macOS Compliance Policy ID`
- **Type**: String
- **Value**: Your policy GUID (from Step 3.1)
- **Encrypted**: No
- Click **Create**

**Variable 2: USE_MANAGED_IDENTITY**
- Click **+ Add a variable**
- **Name**: `USE_MANAGED_IDENTITY`
- **Description**: `Use managed identity for authentication`
- **Type**: Boolean
- **Value**: 
  - `True` if using Managed Identity (Part 2A)
  - `False` if using Service Principal (Part 2B)
- **Encrypted**: No
- Click **Create**

---

#### For Service Principal Users ONLY

If you set `USE_MANAGED_IDENTITY = False`, also create these:

**Variable 3: INTUNE_TENANT_ID**
- **Name**: `INTUNE_TENANT_ID`
- **Type**: String
- **Value**: Your Azure AD Tenant ID
- **Encrypted**: No

**Variable 4: INTUNE_CLIENT_ID**
- **Name**: `INTUNE_CLIENT_ID`
- **Type**: String
- **Value**: Your App Registration Client ID
- **Encrypted**: No

**Variable 5: INTUNE_CLIENT_SECRET**
- **Name**: `INTUNE_CLIENT_SECRET`
- **Type**: String
- **Value**: Your Client Secret
- **Encrypted**: **Yes** ⚠️ **IMPORTANT: Check this box!**

---

#### Optional Configuration (All Users)

These variables customize the version tracking behavior:

**Variable 6: PIN_TO_MAJOR_VERSION** ⭐ RECOMMENDED
- **Name**: `PIN_TO_MAJOR_VERSION`
- **Type**: Integer
- **Value**: `26` (or your target major version)
- **Encrypted**: No
- **Description**: Pin to specific macOS major version

**Why pin?** Controls OS rollout. Set to `26` to track only macOS 26.x versions and ignore macOS 27.x. Perfect for testing new OS on pilot group while keeping production stable.

**Variable 7: VERSIONS_BELOW**
- **Name**: `VERSIONS_BELOW`
- **Type**: Integer
- **Value**: `2` (how many versions behind latest)
- **Encrypted**: No
- **Default**: 2 if not specified

**Variable 8: USE_MINOR_VERSIONS**
- **Name**: `USE_MINOR_VERSIONS`
- **Type**: Boolean
- **Value**: `False`
- **Encrypted**: No
- **Default**: False if not specified

---

### Step 3.3: Variable Summary

**Managed Identity setup:**
- `INTUNE_POLICY_ID` ✅ Required
- `USE_MANAGED_IDENTITY = True` ✅ Required
- `PIN_TO_MAJOR_VERSION` ⭐ Recommended
- `VERSIONS_BELOW` (optional)

**Service Principal setup:**
- `INTUNE_POLICY_ID` ✅ Required
- `USE_MANAGED_IDENTITY = False` ✅ Required
- `INTUNE_TENANT_ID` ✅ Required
- `INTUNE_CLIENT_ID` ✅ Required
- `INTUNE_CLIENT_SECRET` ✅ Required (encrypted!)
- `PIN_TO_MAJOR_VERSION` ⭐ Recommended
- `VERSIONS_BELOW` (optional)

---

## Part 4: Upload the Runbooks

### Step 4.1: Create Main Runbook

1. In your Automation Account, go to **Runbooks** (under Process Automation)
2. Click **+ Create a runbook**
3. Configure:
   - **Name**: `Update-macOS-Compliance-Policy`
   - **Runbook type**: PowerShell
   - **Runtime version**: **7.2** (or 5.1 if unavailable)
   - **Description**: `Automatically updates Intune macOS compliance policy based on SOFA feed`
4. Click **Create**

### Step 4.2: Upload Main Script

1. The editor opens automatically
2. Copy the entire contents of **`Update-IntuneMacOSCompliance.ps1`**
3. Paste into the editor
4. Click **Save**
5. Click **Publish** → **Yes**

### Step 4.3: Create Diagnostics Runbook (Recommended)

1. Click **+ Create a runbook** again
2. Configure:
   - **Name**: `Diagnostics-macOS-Compliance`
   - **Runbook type**: PowerShell
   - **Runtime version**: 7.2 (or 5.1)
   - **Description**: `Pre-flight diagnostics for compliance automation`
3. Click **Create**
4. Copy contents of **`Diagnostics-Runbook.ps1`**
5. Paste, **Save**, **Publish**

---

## Part 5: Test the Setup

### Step 5.1: Run Diagnostics First

Before testing the main script, verify your configuration:

1. Go to **Runbooks** → **Diagnostics-macOS-Compliance**
2. Click **Start**
3. Watch the output - all 5 steps should pass:

**Expected output (Managed Identity):**
```
[STEP 1] Loading Azure Automation Variables...
✓ Managed Identity mode detected
  Authentication: System-assigned managed identity
  No credentials needed
  Policy ID: 36b9b86c...

[STEP 2] Testing Microsoft Graph Authentication...
Using Managed Identity authentication...
✓ Authentication successful (Managed Identity)
  Token type: Bearer
  Token length: 2016 chars

[STEP 3] Testing Microsoft Graph API Permissions...
✓ API access successful
  Found 3 compliance policies

[STEP 4] Testing Access to Target Policy...
✓ Policy access successful
  Policy Name: macOS Compliance OS Version
  Current Minimum OS: 26.3.2

[STEP 5] Testing SOFA API Access...
✓ SOFA API accessible
  Retrieved 118 macOS versions

=========================================
DIAGNOSTICS COMPLETE
=========================================
```

**If any step fails:** See Troubleshooting section below.

### Step 5.2: Run Main Script

1. Go to **Runbooks** → **Update-macOS-Compliance-Policy**
2. Click **Start**
3. Leave parameters empty (uses variables)
4. Click **OK**
5. Monitor the job output

### Step 5.3: Verify Execution Summary

At the end, you should see:

**Managed Identity:**
```json
{
  "Success": true,
  "PolicyId": "36b9b86c-2297-4c2c-9b25-8c023f9d4d57",
  "PreviousVersion": "26.3.2",
  "NewVersion": "26.3.2",
  "Updated": false,
  "AuthMethod": "Managed Identity",
  "Duration": 4.5,
  "Timestamp": "2026-04-05T11:00:39Z"
}
```

**Service Principal:**
```json
{
  "Success": true,
  "PolicyId": "36b9b86c-...",
  "PreviousVersion": "26.3.2",
  "NewVersion": "26.4.0",
  "Updated": true,
  "AuthMethod": "Service Principal",
  "Duration": 6.2,
  "Timestamp": "2026-04-05T11:00:39Z"
}
```

**Key field:** `AuthMethod` confirms which authentication was used.

### Step 5.4: Enable Verbose Logging (Optional)

To see detailed execution flow:

1. Go to your runbook → **Settings**
2. Set **Log verbose records** to **On**
3. Click **Save**

Next run will show detailed authentication and processing logs.

---

## Part 6: Schedule Automated Execution

### Step 6.1: Create a Schedule

1. In your Automation Account, go to **Schedules** (under Shared Resources)
2. Click **+ Add a schedule**
3. Click **Create a new schedule**
4. Configure:
   - **Name**: `Weekly-Tuesday-2AM`
   - **Description**: `Weekly check for macOS version updates`
   - **Starts**: Next Tuesday
   - **Time**: `02:00`
   - **Time zone**: Your time zone
   - **Recurrence**: Recurring
   - **Recur every**: 1 Week
   - **On these days**: Tuesday only
   - **Set expiration**: No
5. Click **Create**

### Step 6.2: Link Schedule to Runbook

1. Go to your runbook → **Schedules** (under Resources)
2. Click **+ Add a schedule**
3. Select **Weekly-Tuesday-2AM**
4. Leave parameters empty
5. Click **OK**

✅ The runbook will now run automatically every Tuesday at 2 AM.

---

## Part 7: Set Up Monitoring (Optional)

### Step 7.1: Configure Failure Alerts

Get notified if the automation fails:

1. In your Automation Account, go to **Alerts** (under Monitoring)
2. Click **+ New alert rule**
3. **Condition**: Select "Job failed"
4. **Actions**: 
   - Create new action group
   - Add email notification or Teams webhook
5. **Alert rule name**: `macOS Compliance Update Failed`
6. Click **Create**

### Step 7.2: View Job History

Monitor past executions:

1. Go to **Automation Account** → **Jobs**
2. See all runs with status (Completed, Failed, etc.)
3. Click any job to see:
   - Execution summary (JSON output)
   - Full logs
   - Error details (if failed)

### Step 7.3: Query Logs (Advanced)

If you enabled Log Analytics:

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.AUTOMATION"
| where Category == "JobLogs"
| where RunbookName_s == "Update-macOS-Compliance-Policy"
| project TimeGenerated, ResultType, RunbookName_s
| order by TimeGenerated desc
| take 10
```

---

## 🔧 Troubleshooting

### Diagnostics: "Failed to load variables"

**Cause:** Variables don't exist or have wrong names.

**Fix:**
- Verify variable names exactly match (case-sensitive)
- For Managed Identity: Need `INTUNE_POLICY_ID` and `USE_MANAGED_IDENTITY = True`
- For Service Principal: Need all 5 credential variables
- Check for typos or extra spaces

### Diagnostics: "Failed to authenticate using Managed Identity"

**Cause:** Managed identity not enabled or permissions not granted.

**Fix:**
1. Verify **Identity** → **System assigned** is **On**
2. Re-run PowerShell permission grant command
3. Verify permission with `Get-MgServicePrincipalAppRoleAssignment`
4. Wait 5-10 minutes for Azure to propagate permissions
5. Restart the runbook job

### Diagnostics: "Failed to authenticate to Microsoft Graph" (Service Principal)

**Cause:** Invalid credentials or missing permissions.

**Fix:**
1. Verify Tenant ID is correct (Azure AD → Overview)
2. Verify Client ID is correct (App Registration → Overview)
3. Check Client Secret hasn't expired (Certificates & secrets)
4. Ensure admin consent was granted (API permissions → green checkmark)
5. Wait 5 minutes after granting consent

### Diagnostics: "API access failed - 403 Forbidden"

**Cause:** Permission not granted or consent missing.

**Fix:**
- **Managed Identity**: Re-run permission grant command from Part 2A.2
- **Service Principal**: Click "Grant admin consent" in API permissions
- Wait 5-10 minutes for permissions to propagate
- Verify permission type is **Application** (not Delegated)

### Diagnostics: "Policy access failed - 404 Not Found"

**Cause:** Incorrect Policy ID.

**Fix:**
1. Go to Intune → Devices → Compliance → Policies
2. Click your macOS policy
3. Copy GUID from URL
4. Update `INTUNE_POLICY_ID` variable
5. Ensure no extra spaces or characters

### Diagnostics: "SOFA API failed"

**Cause:** Network connectivity issue or SOFA temporary outage.

**Fix:**
- Check Automation Account network settings
- SOFA updates every 6 hours - may be brief maintenance
- Verify URL accessible: https://sofa.macadmins.io/v2/macos_data_feed.json
- Wait 10 minutes and retry
- Check SOFA status: https://sofa.macadmins.io

### Main Script: Shows wrong AuthMethod

**Symptom:** Expected "Managed Identity" but shows "Service Principal"

**Cause:** `USE_MANAGED_IDENTITY` variable not set correctly.

**Fix:**
1. Go to Variables → `USE_MANAGED_IDENTITY`
2. Verify Type is **Boolean** (not String)
3. Verify Value is `True` (not "True" with quotes)
4. Re-save if needed
5. Test again

### Main Script: "Configuration incomplete"

**Managed Identity:**
- Missing `INTUNE_POLICY_ID` variable

**Service Principal:**
- Missing `INTUNE_TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, or `POLICY_ID`

### Job keeps failing silently

1. Go to the failed job
2. Check **Output** stream for errors
3. Check **Error** stream for exceptions
4. Enable verbose logging (Settings → Log verbose records → On)
5. Run diagnostics to isolate the issue

---

## 🔄 Ongoing Maintenance

### Managed Identity: Zero Maintenance! 🎉

If using Managed Identity:
- ✅ Nothing expires
- ✅ No secrets to rotate
- ✅ No calendar reminders needed
- ✅ Just monitor job history

### Service Principal: Secret Rotation

If using Service Principal, rotate the secret before expiration:

**30 days before expiration:**

1. Go to App Registration → **Certificates & secrets**
2. Create a new client secret (24 months)
3. Copy the new secret value
4. Update `INTUNE_CLIENT_SECRET` variable in Automation Account
5. Test the runbook manually
6. Once confirmed working, delete the old secret
7. Set new calendar reminder for next rotation

### Update the Script

When new versions are released:

1. Download latest `Update-IntuneMacOSCompliance.ps1`
2. Go to runbook → **Edit**
3. Select all (Ctrl+A) and delete
4. Paste new script
5. **Save** → **Publish**
6. Run diagnostics to verify
7. Test manually
8. Monitor next scheduled run

### Change Configuration

Update version tracking behavior:

1. Go to **Variables**
2. Click variable name (e.g., `PIN_TO_MAJOR_VERSION`)
3. Change value
4. Click **Save**
5. No need to republish runbook - takes effect next run

### Migrate to Managed Identity

If currently using Service Principal and want to switch:

See **`MANAGED-IDENTITY-MIGRATION.md`** for complete step-by-step migration guide.

**Benefits:**
- Eliminate secret rotation forever
- Improve security posture
- Reduce operational overhead
- Easy rollback if needed

---

## 📚 Additional Resources

**Microsoft Documentation:**
- [Azure Automation](https://docs.microsoft.com/azure/automation/)
- [Managed Identities](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Microsoft Graph API](https://docs.microsoft.com/graph/)
- [Intune Compliance Policies](https://docs.microsoft.com/mem/intune/protect/device-compliance-get-started)

**Community Resources:**
- [SOFA Feed](https://sofa.macadmins.io) - MacAdmins Open Source
- [SOFA Documentation](https://sofa.macadmins.io/getting-started)

**This Repository:**
- `README.md` - Overview and quick start
- `STANDALONE-USAGE.md` - Local execution guide
- `MANAGED-IDENTITY-MIGRATION.md` - Migration from service principal
- `VERSION-STRATEGIES.md` - Detailed versioning strategies

---

## 💡 Pro Tips

1. **Start with Managed Identity** - Save yourself future maintenance
2. **Pin to major version** - Control OS rollout with `PIN_TO_MAJOR_VERSION`
3. **Enable verbose logging** - See authentication method and detailed flow
4. **Run diagnostics after changes** - Catch issues before scheduled run
5. **Monitor the AuthMethod field** - Confirm correct authentication
6. **Schedule during low-usage hours** - Minimize user impact
7. **Set up failure alerts** - Know immediately if something breaks
8. **Test version pinning strategy** - Use pilot group before production

---

## 🆘 Getting Help

**Step-by-step debugging:**

1. **Run diagnostics** - Identifies exactly where the problem is
2. **Check job output** - Full execution log with error details
3. **Enable verbose logging** - See authentication and API calls
4. **Verify variables** - Ensure correct names, types, and values
5. **Check permissions** - Managed Identity or App Registration
6. **Review this guide** - Troubleshooting section covers common issues
7. **Test manually** - Run on-demand before relying on schedule

**Common patterns:**
- Authentication fails → Check Part 2 setup
- Variables missing → Check Part 3 configuration
- Policy not found → Verify Policy ID from Intune URL
- SOFA API fails → Network or temporary outage

---

**You're all set! Your macOS compliance automation is now running with zero maintenance required.** 
