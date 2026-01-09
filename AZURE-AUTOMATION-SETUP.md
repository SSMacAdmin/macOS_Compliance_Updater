# Azure Automation Setup Guide

## 🚀 Complete Step-by-Step Setup

This guide shows you how to set up the script in Azure Automation for fully automated, serverless execution.

## Why Azure Automation?

- ✅ **No infrastructure needed** - Runs in Azure cloud
- ✅ **Built-in scheduling** - Set and forget
- ✅ **Secure credential storage** - Encrypted variables
- ✅ **Logging and monitoring** - Track all executions
- ✅ **High availability** - Microsoft manages reliability

---

## Part 1: Create Azure Automation Account (5 minutes)

### Step 1.1: Create the Account

1. Go to [Azure Portal](https://portal.azure.com)
2. Search for "Automation Accounts" and click it
3. Click **+ Create**
4. Fill in:
   - **Subscription**: Choose your subscription
   - **Resource group**: Create new or use existing (e.g., "rg-automation")
   - **Name**: `intune-macos-automation` (or your choice)
   - **Region**: Choose closest to you
5. Click **Review + Create** → **Create**
6. Wait for deployment to complete (~1 minute)

### Step 1.2: Enable System-Assigned Managed Identity (Optional but Recommended)

If you want to use Managed Identity instead of a service principal:

1. Go to your Automation Account
2. Navigate to **Identity** (under Account Settings)
3. Switch **System assigned** tab to **On**
4. Click **Save** → **Yes**
5. Note the **Object (principal) ID** for later

---

## Part 2: Set Up Azure App Registration (5 minutes)

### Option A: Using Service Principal (Recommended for this script)

#### Step 2.1: Create App Registration

1. Go to **Azure Active Directory** → **App registrations** → **New registration**
2. Fill in:
   - Name: `Intune-macOS-Compliance-Automation`
   - Supported account types: **Accounts in this organizational directory only**
3. Click **Register**

#### Step 2.2: Add API Permissions

1. In your new app, go to **API permissions**
2. Click **Add a permission** → **Microsoft Graph** → **Application permissions**
3. Search and select: `DeviceManagementConfiguration.ReadWrite.All`
4. Click **Add permissions**
5. Click **Grant admin consent for [Your Organization]**
6. Confirm by clicking **Yes**

#### Step 2.3: Create Client Secret

1. Go to **Certificates & secrets** → **Client secrets** → **New client secret**
2. Description: `Intune Compliance Automation`
3. Expires: **24 months** (or your preference)
4. Click **Add**
5. **CRITICAL**: Copy the **Value** immediately (you won't see it again!)

#### Step 2.4: Collect Your IDs

Copy these values - you'll need them in Part 3:

- **Tenant ID**: Azure AD → Overview → Tenant ID
- **Client ID**: Your app → Overview → Application (client) ID
- **Client Secret**: The value you just copied

---

## Part 3: Configure Azure Automation Variables (3 minutes)

### Step 3.1: Create Variables

1. Go to your **Automation Account**
2. Navigate to **Variables** (under Shared Resources)
3. Click **+ Add a variable** for each of the following:

#### Variable 1: INTUNE_TENANT_ID
- **Name**: `INTUNE_TENANT_ID`
- **Description**: `Azure AD Tenant ID`
- **Type**: `String`
- **Value**: Your Tenant ID
- **Encrypted**: `No`
- Click **Create**

#### Variable 2: INTUNE_CLIENT_ID
- **Name**: `INTUNE_CLIENT_ID`
- **Description**: `App Registration Client ID`
- **Type**: `String`
- **Value**: Your Client ID (Application ID)
- **Encrypted**: `No`
- Click **Create**

#### Variable 3: INTUNE_CLIENT_SECRET
- **Name**: `INTUNE_CLIENT_SECRET`
- **Description**: `App Registration Client Secret`
- **Type**: `String`
- **Value**: Your Client Secret
- **Encrypted**: `Yes` ⚠️ **IMPORTANT: Check this box!**
- Click **Create**

#### Variable 4: INTUNE_POLICY_ID
- **Name**: `INTUNE_POLICY_ID`
- **Description**: `Intune macOS Compliance Policy ID`
- **Type**: `String`
- **Value**: Your Policy ID (from Intune portal URL)
- **Encrypted**: `No`
- Click **Create**

### Step 3.2: Optional Configuration Variables

You can also create these optional variables:

#### Variable 5: VERSIONS_BELOW (Optional)
- **Name**: `VERSIONS_BELOW`
- **Type**: `Integer`
- **Value**: `2` (or your preference: 1-10)
- **Encrypted**: `No`

#### Variable 6: USE_MINOR_VERSIONS (Optional)
- **Name**: `USE_MINOR_VERSIONS`
- **Type**: `Boolean`
- **Value**: `False` (or `True` for minor version tracking)
- **Encrypted**: `No`

#### Variable 7: PIN_TO_MAJOR_VERSION (Optional)
- **Name**: `PIN_TO_MAJOR_VERSION`
- **Type**: `Integer`
- **Value**: `0` (or `15` to pin to macOS 15.x)
- **Encrypted**: `No`
- **Description**: `Pin to specific major version (0 = disabled)`

---

## Part 4: Upload the Runbook (2 minutes)

### Step 4.1: Create the Runbook

1. In your Automation Account, go to **Runbooks** (under Process Automation)
2. Click **+ Create a runbook**
3. Fill in:
   - **Name**: `Update-macOS-Compliance-Policy`
   - **Runbook type**: `PowerShell`
   - **Runtime version**: `5.1` (or `7.2` if available)
   - **Description**: `Automatically updates Intune macOS compliance policy based on AppleDB`
4. Click **Create**

### Step 4.2: Upload the Script

1. The editor will open automatically
2. Copy the entire contents of `Update-IntuneMacOSCompliance.ps1`
3. Paste into the editor
4. Click **Save**
5. Click **Publish**
6. Confirm by clicking **Yes**

---

## Part 5: Test the Runbook (2 minutes)

### Step 5.1: Manual Test Run

1. In your runbook, click **Start**
2. **Parameters**: Leave empty (it will use variables)
3. Click **OK**
4. Watch the output in real-time

### Step 5.2: Verify the Output

You should see:
```
========================================
Intune macOS Compliance Policy Updater
Version 2.0 (All-in-One)
========================================
Detected Azure Automation environment
Loading credentials from Azure Automation variables...
Successfully loaded credentials from Azure Automation
...
Successfully updated compliance policy!
========================================
COMPLIANCE POLICY UPDATE COMPLETE
========================================
```

### Step 5.3: Check Job History

1. Go to **Jobs** (under Resources)
2. You should see your recent job with status **Completed**
3. Click on it to see full logs

---

## Part 6: Schedule the Runbook (3 minutes)

### Step 6.1: Create a Schedule

1. In your Automation Account, go to **Schedules** (under Shared Resources)
2. Click **+ Add a schedule**
3. Click **Link a schedule to your runbook**
4. Click **+ Add a schedule** → **Create a new schedule**
5. Fill in:
   - **Name**: `Weekly-Tuesday-2AM`
   - **Description**: `Runs every Tuesday at 2:00 AM to check for macOS updates`
   - **Starts**: Choose next Tuesday
   - **Time**: `02:00` (2:00 AM)
   - **Time zone**: Your time zone
   - **Recurrence**: `Recurring`
   - **Recur every**: `1 Week`
   - **On these days**: Check **Tuesday** only
   - **Set expiration**: `No`
6. Click **Create**

### Step 6.2: Link Schedule to Runbook

1. Go to your **Runbook** → **Schedules** (under Resources)
2. Click **+ Add a schedule**
3. Select the schedule you just created
4. **Parameters**: Leave empty (uses variables)
5. **Run settings**: Default
6. Click **OK**

---

## Part 7: Set Up Monitoring (Optional but Recommended)

### Step 7.1: Configure Alerts

1. In your Automation Account, go to **Alerts** (under Monitoring)
2. Click **+ New alert rule**
3. **Condition**: Job failed
4. **Actions**: Create action group
   - Add your email or Teams webhook
5. **Alert rule name**: `Intune macOS Compliance - Job Failed`
6. Click **Create alert rule**

### Step 7.2: Enable Diagnostic Logs

1. Go to **Diagnostic settings** (under Monitoring)
2. Click **+ Add diagnostic setting**
3. **Name**: `AuditLogs`
4. Check: **JobLogs** and **JobStreams**
5. **Destination**: 
   - Log Analytics workspace (recommended)
   - Or Storage account
6. Click **Save**

---

## 🎯 Verification Checklist

After setup, verify:

- [ ] Automation Account created
- [ ] App Registration created with correct permissions
- [ ] Admin consent granted for API permissions
- [ ] Client secret created and copied
- [ ] All 4 required variables created in Automation Account
- [ ] `INTUNE_CLIENT_SECRET` is encrypted
- [ ] Runbook created and script uploaded
- [ ] Runbook published
- [ ] Test run completed successfully
- [ ] Schedule created and linked
- [ ] Alerts configured (optional)
- [ ] Diagnostic logging enabled (optional)

---

## 📊 Monitoring Your Automation

### Check Job History

1. Go to **Automation Account** → **Jobs**
2. See all executions with status
3. Click any job to see detailed logs

### View Execution Summary

Each execution outputs a JSON summary:
```json
{
  "Success": true,
  "PolicyId": "xxx-xxx-xxx",
  "PreviousVersion": "13.5",
  "NewVersion": "13.7",
  "Updated": true,
  "Duration": 8.5,
  "Timestamp": "2025-01-07T14:30:00Z"
}
```

### Query Logs in Log Analytics (if enabled)

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.AUTOMATION"
| where Category == "JobLogs"
| where RunbookName_s == "Update-macOS-Compliance-Policy"
| project TimeGenerated, ResultType, RunbookName_s
| order by TimeGenerated desc
```

---

## 🔧 Troubleshooting

### "Failed to load Azure Automation variables"
- Verify all 4 variables exist with correct names (case-sensitive)
- Check variable values are correct
- Ensure no extra spaces in variable values

### "Failed to authenticate to Microsoft Graph"
- Verify Tenant ID is correct
- Verify Client ID is correct
- Check Client Secret hasn't expired
- Ensure admin consent was granted

### "Failed to retrieve compliance policy"
- Verify Policy ID is correct
- Check app has DeviceManagementConfiguration.ReadWrite.All permission
- Ensure the policy still exists in Intune

### Runbook shows "Failed" status
- Click the failed job to see error details
- Check the Output and Error streams
- Review the script logs

---

## 🔄 Maintenance

### Rotate Client Secret (Before Expiration)

1. Create new secret in App Registration
2. Update `INTUNE_CLIENT_SECRET` variable in Automation Account
3. Test the runbook manually
4. Delete old secret once confirmed working

### Update the Script

1. Go to your Runbook
2. Click **Edit**
3. Paste new script version
4. Click **Save** → **Publish**
5. Test manually

### Change Configuration

Update any variable in Automation Account:
1. Go to **Variables**
2. Click the variable name
3. Update the value
4. Click **Save**

Changes take effect on next run (no need to republish runbook)

---

## 📚 Additional Resources

- [Azure Automation Documentation](https://docs.microsoft.com/azure/automation/)
- [Microsoft Graph API Reference](https://docs.microsoft.com/graph/)
- [Intune Compliance Policies](https://docs.microsoft.com/mem/intune/)
- [AppleDB GitHub](https://github.com/littlebyteorg/appledb)

---

## 🆘 Need Help?

1. Check job output logs in Azure Automation
2. Review this guide's troubleshooting section
3. Verify all variables are set correctly
4. Test the App Registration permissions manually
5. Check Azure AD sign-in logs for authentication issues
