# macOS Compliance Updater

Automatically updates macOS version compliance policies in Microsoft Intune based on the latest releases.

## ✨ Features

- ✅ **Zero maintenance** with Azure Managed Identity
- ✅ **Accurate version data** from SOFA (MacAdmins community feed)
- ✅ **Flexible versioning strategies** - pin to major versions, track minor releases
- ✅ **Azure Automation ready** - serverless, scheduled execution
- ✅ **Comprehensive diagnostics** - verify setup before running
- ✅ **Production-tested** - used in real enterprise environments

## 🚀 Quick Start

### Option 1: Azure Automation (Recommended)

See [AZURE-AUTOMATION-SETUP.md](AZURE-AUTOMATION-SETUP.md) for complete step-by-step instructions.

**With Managed Identity (Zero Maintenance):**
1. Create Azure Automation Account
2. Enable system-assigned managed identity
3. Grant Graph API permissions (one PowerShell command)
4. Set 2 variables: `INTUNE_POLICY_ID` and `USE_MANAGED_IDENTITY=True`
5. Upload and schedule the runbook
6. Done! No credential rotation ever needed.

### Option 2: Standalone Execution

See [STANDALONE-USAGE.md](STANDALONE-USAGE.md) for local execution instructions.

## 📊 What It Does

The script:
1. Fetches latest macOS versions from **SOFA** (MacAdmins community feed)
2. Calculates target minimum version based on your strategy
3. Authenticates to Microsoft Graph (managed identity or service principal)
4. Updates your Intune compliance policy automatically

## 🎯 Version Strategies

**Track Major Versions** (conservative)
- Stay N major versions behind latest
- Example: If latest is macOS 26, require macOS 24

**Track Minor Versions** (aggressive)
- Stay N minor versions behind within all major versions  
- Example: If latest is 26.7, require 26.5

**Pin to Major Version** (recommended for phased rollouts)
- Lock to specific major version, track minor versions within it
- Example: Pin to 26, stay 2 versions behind → requires 26.5, ignores macOS 27.x
- Perfect for testing new OS while keeping production stable

## 🔐 Authentication Methods

### Managed Identity (Recommended)
- ✅ No secrets to manage
- ✅ No expiration
- ✅ More secure (no credentials stored anywhere)
- ✅ Azure best practice
- ✅ Zero ongoing maintenance

### Service Principal  
- ✅ Works everywhere (Azure, local, CI/CD)
- ⚠️ Client secret expires (requires rotation)
- ⚠️ Secret must be stored securely

Both methods fully supported. Easy migration path from service principal to managed identity.

## 📦 What's Included

- `Update-IntuneMacOSCompliance.ps1` - Main script (works standalone or Azure Automation)
- `Diagnostics-Runbook.ps1` - Pre-flight checks for Azure Automation
- `AZURE-AUTOMATION-SETUP.md` - Complete Azure setup guide (managed identity + service principal)
- `STANDALONE-USAGE.md` - Local execution guide
- `MANAGED-IDENTITY-MIGRATION.md` - Migration guide from service principal to managed identity


## 🔄 Recent Updates

**v3.0** (April 2026)
- ✅ Added managed identity support (zero maintenance!)
- ✅ Switched to SOFA feed (MacAdmins community standard)
- ✅ Fixed Azure Automation memory constraints
- ✅ Added `AuthMethod` to execution output
- ✅ Enhanced diagnostics with auth method detection
- ✅ Updated all documentation

**v2.0** 
- ✅ All-in-one script (works standalone + Azure Automation)
- ✅ Pin to major version support
- ✅ Comprehensive diagnostics
- ✅ Better error handling

## 💰 Cost

**Azure Automation:**
- ~$2.60/month with Free tier (500 minutes included)
- Script runs in ~4-6 seconds
- Weekly execution = ~25 seconds/month = essentially free

## 🎯 Example Configuration

**Scenario:** Testing macOS 27 on 20% of fleet, keep production on macOS 26

```powershell
# Production policy - pinned to macOS 26
PIN_TO_MAJOR_VERSION = 26
VERSIONS_BELOW = 2
# Result: If latest 26.x is 26.7, requires 26.5 (ignores macOS 27.x)

# Test policy - tracking macOS 27
PIN_TO_MAJOR_VERSION = 27
VERSIONS_BELOW = 1
# Result: If latest 27.x is 27.3, requires 27.2
```

## 📚 Resources

- [Azure Automation Documentation](https://docs.microsoft.com/azure/automation/)
- [Microsoft Graph API Reference](https://docs.microsoft.com/graph/)
- [Intune Compliance Policies](https://docs.microsoft.com/mem/intune/)
- [SOFA MacAdmins Feed](https://sofa.macadmins.io)
- [Managed Identity Documentation](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)

## 🆘 Support

1. Run `Diagnostics-Runbook.ps1` to verify setup
2. Check execution output for `AuthMethod` field
3. Enable verbose logging in Azure Automation for detailed logs
4. See troubleshooting sections in setup guides

## 📝 License

MIT License - feel free to use and modify for your organization.

## 🙏 Credits

- **SOFA Feed** by [MacAdmins Open Source](https://github.com/macadmins/sofa) - Community-maintained macOS version data