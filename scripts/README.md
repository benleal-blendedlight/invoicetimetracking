# Scripts

## `provision.ps1`

Idempotent PnP.PowerShell script that creates:

| Artifact | Notes |
|---|---|
| **Clients** | Title template, rates, billing email |
| **Projects** | Lookup → Clients |
| **Time Entries** | Lookups → Clients, Projects, Invoices |
| **Recurring Invoices** | Fixed amount + SendMode + schedule |
| **Invoices** | Status pipeline + PDF link |
| **Invoice Lines** | Lookup → Invoices, Time Entries |
| **Invoice PDFs** | Document library |
| **Views** | Active Clients, Due Recurring, Draft, Overdue, Unbilled, Failed, … |
| **Optional seed** | Acme + Northwind clients + two NotifyOnly recurrings |

### Prerequisites

1. **PowerShell 7+** recommended (`pwsh`). Windows PowerShell 5.1 often works too.
2. **PnP.PowerShell** module (script installs to CurrentUser if missing). **v3.x requires `-ClientId`.**
3. A **SharePoint site** you can admin, e.g.  
   `https://blendedlight.sharepoint.com/sites/InvoiceandTimeTracking`
4. **Your own Entra app registration** (one-time) — see below. PnP no longer ships a multi-tenant login app.

### Entra app for PnP (required once)

PnP.PowerShell 2.x/3.x will error with:

> Please specify a valid client id for an Entra ID App Registration  
> Specified method is not supported

Create a **public client** app your user can sign into:

1. Open [Entra admin center → App registrations](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade) → **New registration**
2. **Name:** `Billing Platform PnP`
3. **Supported account types:** Accounts in this organizational directory only (single tenant)
4. **Redirect URI:** leave blank for now → **Register**
5. Copy **Application (client) ID** — you will pass it as `-ClientId`
6. **Authentication** → under Advanced settings set **Allow public client flows** = **Yes** → Save  
   (Optional but recommended: Add a platform → **Mobile and desktop applications** → enable  
   `https://login.microsoftonline.com/common/oauth2/nativeclient`)
7. **API permissions** → **Add a permission** → **SharePoint** → **Delegated permissions** →  
   `AllSites.FullControl` (or at least `AllSites.Manage`) → **Add**  
   Then **Grant admin consent for &lt;tenant&gt;**
8. (Optional) **Owners** → add yourself so others can maintain the app

You do **not** need a client secret for interactive/device login.

### Create the site (if needed)

In browser:

1. SharePoint admin / Create site → **Team site**  
2. Name: **Billing**  
3. Privacy: **Private**  
4. Copy the site URL

Or via PnP after connecting to the tenant admin (optional):

```powershell
# Only if you already use PnP against the tenant
New-PnPSite -Type TeamSite -Title "Billing" -Alias "Billing" -IsPublic:$false
```

### Run

```powershell
# From a clone of this repo
cd scripts

# First run — creates lists + columns + views
./provision.ps1 -SiteUrl "https://YOUR_TENANT.sharepoint.com/sites/Billing"

# Same + sample clients / recurring templates
./provision.ps1 -SiteUrl "https://YOUR_TENANT.sharepoint.com/sites/Billing" -SeedSampleData

# Headless / remote session
./provision.ps1 -SiteUrl "https://YOUR_TENANT.sharepoint.com/sites/Billing" -LoginMode DeviceLogin
```

### Execution policy (Windows)

If scripts are blocked:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### What “OK” looks like

Console ends with a summary of all 7 lists/libraries and:

```text
Provisioning complete.
```

In SharePoint:

- Site contents shows all six lists + **Invoice PDFs**
- **Clients → Active Clients** view works
- **Recurring Invoices → Due Recurring** view works
- If seeded: two clients with different `InvoiceTitleTemplate` values

### Safe to re-run

Yes. Existing lists/fields/views are skipped (`--` lines). Seed items are skipped if a matching **Title** already exists.

### Troubleshooting

| Symptom | Fix |
|---|---|
| `Connect-PnPOnline` consent / AADSTS errors | Ask a tenant admin to allow PnP.PowerShell, or register your own Entra app and use `-ClientId` (advanced) |
| Lookup field fails | Re-run the script — lists must exist first; script order handles this |
| Field type wrong after manual edits | Delete the field in UI (if empty) and re-run |
| Currency shows wrong symbol | SharePoint currency fields follow **site regional settings** — set site locale/currency in Site settings |

### Do not commit

- Tenant-specific connection dumps  
- Exported list XML that contains real client emails/rates from production  

The script itself is safe to keep in git.
