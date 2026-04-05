# Migrating to Managed Identity

This guide walks you through migrating from Service Principal (client secret) authentication to Managed Identity authentication.

## Why Migrate?

**Current Setup (Service Principal):**
- ❌ Client secrets expire (90 days to 2 years maximum)
- ❌ Manual rotation required
- ❌ Secret stored in Automation variables
- ❌ Calendar reminders needed for expiration
- ❌ Risk of forgotten expiration = broken automation

**With Managed Identity:**
- ✅ No secrets to manage - Azure handles authentication automatically
- ✅ No expiration - works indefinitely
- ✅ Zero maintenance - set it and forget it
- ✅ More secure - no credentials stored anywhere
- ✅ Azure best practice - Microsoft's recommended approach
- ✅ Simpler configuration

## Migration Steps

### Step 1: Enable Managed Identity on Automation Account

1. Go to **Azure Portal** → Your Automation Account
2. Click **Identity** (under Account Settings)
3. Switch to **System assigned** tab
4. Toggle **Status** to **On**
5. Click **Save**
6. **Copy the Object (principal) ID** - you'll need this in Step 2

### Step 2: Grant Microsoft Graph API Permissions

You need to grant the managed identity the same permissions your app registration has.

**Option A: Using Azure Cloud Shell (Recommended)**

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.Read.All","AppRoleAssignment.ReadWrite.All"

# Replace with your managed identity's Object ID from Step 1
$managedIdentityId = "YOUR-OBJECT-ID-HERE"

# Microsoft Graph App ID (this is always the same)
$graphAppId = "00000003-0000-0000-c000-000000000000"

# Get the Graph service principal
$graphSP = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'"

# Get the permission for DeviceManagementConfiguration.ReadWrite.All
$permission = $graphSP.AppRoles | Where-Object {
    $_.Value -eq "DeviceManagementConfiguration.ReadWrite.All"
}

# Assign the permission to the managed identity
New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $managedIdentityId `
    -PrincipalId $managedIdentityId `
    -ResourceId $graphSP.Id `
    -AppRoleId $permission.Id

Write-Host "✓ Permission granted successfully!" -ForegroundColor Green
```

**Option B: Using Azure Portal (Manual)**

Unfortunately, Azure Portal doesn't have a UI for granting managed identity API permissions. You must use PowerShell (Option A) or Azure CLI.

**Option C: Using Azure CLI**

```bash
# Replace with your managed identity's Object ID
MANAGED_IDENTITY_ID="YOUR-OBJECT-ID-HERE"

# Get Microsoft Graph service principal ID
GRAPH_SP_ID=$(az ad sp list --filter "appId eq '00000003-0000-0000-c000-000000000000'" --query "[0].id" -o tsv)

# Get the role ID for DeviceManagementConfiguration.ReadWrite.All
ROLE_ID=$(az ad sp show --id $GRAPH_SP_ID --query "appRoles[?value=='DeviceManagementConfiguration.ReadWrite.All'].id" -o tsv)

# Assign the permission
az rest --method POST \
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$MANAGED_IDENTITY_ID/appRoleAssignments" \
    --headers Content-Type=application/json \
    --body "{\"principalId\":\"$MANAGED_IDENTITY_ID\",\"resourceId\":\"$GRAPH_SP_ID\",\"appRoleId\":\"$ROLE_ID\"}"

echo "✓ Permission granted successfully!"
```

### Step 3: Verify Permissions

```powershell
# Check that the permission was granted
$managedIdentityId = "YOUR-OBJECT-ID-HERE"
$assignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId

# Should see DeviceManagementConfiguration.ReadWrite.All
$assignments | Select-Object AppRoleId, ResourceDisplayName, @{
    Name='Permission'
    Expression={(Get-MgServicePrincipal -ServicePrincipalId $_.ResourceId).AppRoles | Where-Object Id -eq $_.AppRoleId | Select-Object -ExpandProperty Value}
}
```

You should see:
```
AppRoleId                            ResourceDisplayName Permission
---------                            ------------------- ----------
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx Microsoft Graph     DeviceManagementConfiguration.ReadWrite.All
```

### Step 4: Update Automation Account Variables

1. Go to **Automation Account** → **Variables**
2. **Add new variable**:
   - Name: `USE_MANAGED_IDENTITY`
   - Type: `Boolean`
   - Value: `True`

**Note:** You can keep your existing variables (TENANT_ID, CLIENT_ID, CLIENT_SECRET) as fallback, or delete them if you're confident in the migration.

### Step 5: Update the Runbook

The script already supports managed identity! Just make sure you're using the latest version:

1. Go to **Automation Account** → **Runbooks** → Your runbook
2. Click **Edit**
3. Replace with the latest script (supports both modes)
4. **Save** → **Publish**

### Step 6: Test It!

Run the runbook. It should now authenticate using managed identity.

Look for this log message:
```
[INFO] Managed Identity mode enabled
[INFO] Authenticating using Managed Identity...
[SUCCESS] Successfully authenticated using Managed Identity
```

## Rollback Plan

If something goes wrong, you can instantly rollback:

1. Go to **Automation Account** → **Variables**
2. Set `USE_MANAGED_IDENTITY` to `False` (or delete the variable)
3. Script will fall back to service principal authentication

Your old credentials are still in the variables, so it will work immediately.

## Cleanup (After Successful Migration)

Once you've verified managed identity works for a week or two:

1. **Delete the app registration** (optional, but recommended):
   - Go to **Azure AD** → **App registrations**
   - Find your "Intune-macOS-Compliance-Automation" app
   - Delete it

2. **Remove old variables**:
   - `INTUNE_TENANT_ID` (no longer needed)
   - `INTUNE_CLIENT_ID` (no longer needed)
   - `INTUNE_CLIENT_SECRET` (no longer needed)

3. **Keep these variables**:
   - `INTUNE_POLICY_ID` (still needed)
   - `PIN_TO_MAJOR_VERSION` (still needed)
   - `VERSIONS_BELOW` (still needed)
   - `USE_MANAGED_IDENTITY` (still needed)

## Troubleshooting

### "Failed to authenticate using Managed Identity"

**Cause:** Managed identity not enabled or permissions not granted.

**Fix:**
1. Verify System Assigned Identity is **On** in Automation Account
2. Verify Graph API permission was granted (Step 2)
3. Wait 5-10 minutes for permissions to propagate

### "The identity of the calling application could not be established"

**Cause:** Managed identity is enabled in variable but not in Automation Account.

**Fix:**
1. Go to Automation Account → Identity
2. Enable System assigned identity
3. Run Step 2 again to grant permissions

### Script still using client secret

**Cause:** `USE_MANAGED_IDENTITY` variable not set or is `False`.

**Fix:**
1. Check variable exists and is set to `True` (boolean, not string)
2. Verify variable name is exactly `USE_MANAGED_IDENTITY` (case-sensitive)

## Verification Checklist

- [ ] System assigned identity enabled on Automation Account
- [ ] Managed identity Object ID copied
- [ ] Graph API permission granted via PowerShell/CLI
- [ ] Permission verified with Get-MgServicePrincipalAppRoleAssignment
- [ ] `USE_MANAGED_IDENTITY` variable created and set to `True`
- [ ] Latest runbook script uploaded
- [ ] Test run successful
- [ ] Log shows "Managed Identity mode enabled"
- [ ] Week-long monitoring passed
- [ ] Old app registration deleted (optional)
- [ ] Old credential variables removed (optional)

## Benefits Summary

After migration:

- **Zero maintenance**: No more secret rotation reminders
- **More secure**: No credentials stored anywhere
- **Simpler**: 1 variable instead of 3
- **Best practice**: Microsoft's recommended approach
- **Future-proof**: Works indefinitely

**Cost:** No change ($2.60/month stays the same)
**Effort:** 15-20 minutes one-time setup
**Risk:** Very low (easy rollback, old method still works as fallback)
