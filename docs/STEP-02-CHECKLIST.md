# Step 2 checklist — SharePoint provisioning

**Goal:** Lists, library, views, and seed data exist on your M365 tenant so flows (Step 3) have a schema to target.

**Repo artifacts:**

- `provision.ps1` (repo root) and `scripts/provision.ps1`
- `scripts/README.md`
- `docs/sharepoint-schema.md` (reference)

---

## A. Before you run the script

- [ ] PowerShell available (`pwsh --version` or Windows PowerShell 5.1+)
- [ ] You can sign in to M365 as someone who can create lists on the target site
- [ ] Site URL ready:  
  `https://blendedlight.sharepoint.com/sites/InvoiceandTimeTracking`
- [ ] Repo cloned / pulled (must include `-ClientId` support)
- [ ] **Entra app Client ID** for PnP (required by PnP.PowerShell 3.x) — section A2

### A1. Create the site (if it does not exist)

1. SharePoint home → **Create site** → **Team site**
2. Name: **Invoice and Time Tracking** (or **Billing**)
3. Privacy: **Private**
4. Copy the URL

### A2. Entra app for PnP (one-time)

PnP 3.x without `-ClientId` errors with:

> Please specify a valid client id for an Entra ID App Registration  
> Specified method is not supported

1. [Entra → App registrations → New](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)
2. Name **Billing Platform PnP**, single-tenant → Register
3. Copy **Application (client) ID** from Overview
4. **Allow public client flows** — Entra’s **Authentication (Preview)** often hides “Advanced”:
   - Click banner **“switch to the old experience”** → Advanced → **Allow public client flows = Yes**, **or**
   - Authentication → **Settings** tab → enable public client flows, **or**
   - **Manifest** → `"allowPublicClient": true` → Save
5. **+ Add Redirect URI** → **Mobile and desktop** → enable  
   `https://login.microsoftonline.com/common/oauth2/nativeclient` (and/or `http://localhost`)
6. **API permissions** → SharePoint → Delegated → **AllSites.FullControl** →  
   **Grant admin consent for your tenant**
7. No client secret needed

Full detail: [`scripts/README.md`](../scripts/README.md)

---

## B. Run provisioning

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

cd "C:\Users\BenLeal\OneDrive - BlendedLight LLC\Clients\BlendedLight\invoicetimetracking"
git pull

$env:PNP_CLIENT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Application (client) ID

./provision.ps1 `
  -SiteUrl "https://blendedlight.sharepoint.com/sites/InvoiceandTimeTracking" `
  -ClientId $env:PNP_CLIENT_ID `
  -SeedSampleData
```

If interactive browser login fails:

```powershell
./provision.ps1 `
  -SiteUrl "https://blendedlight.sharepoint.com/sites/InvoiceandTimeTracking" `
  -ClientId $env:PNP_CLIENT_ID `
  -SeedSampleData `
  -LoginMode DeviceLogin
```

### Expected console signals

- `OK  Created list: …` or `--  List exists: …`
- `OK  Clients.ClientCode` (and many field lines)
- `OK  View Invoices / Overdue`
- `Provisioning complete.`

---

## C. Verify in the browser (double-check together)

Open the site → **Site contents**. Confirm:

| Artifact | Check |
|---|---|
| Clients | List present; ClientCode, InvoiceTitleTemplate, BillingEmail |
| Projects | Lookup column **Client** |
| Time Entries | Start/End, Billable, Invoice lookup |
| Recurring Invoices | Amount, SendMode, NextRunDate, Active |
| Invoices | InvoiceNumber, Status choices, PDF Link |
| Invoice Lines | Quantity, UnitPrice, Amount, Invoice lookup |
| Invoice PDFs | Document library |

**Views:**

- [ ] Clients → **Active Clients**
- [ ] Recurring Invoices → **Due Recurring**, **Active Templates**
- [ ] Invoices → **Draft Invoices**, **Sent**, **Overdue**, **Failed**
- [ ] Time Entries → **Unbilled Time**, **Running**

**Seed data** (if `-SeedSampleData`):

- [ ] Clients: Acme Consulting Ltd + Northwind Traders
- [ ] Different `InvoiceTitleTemplate` on each
- [ ] Two Recurring Invoices, SendMode = NotifyOnly
- [ ] Change seed **Billing Email** to a mailbox **you** control before any AutoSend

---

## D. Manual polish (5 minutes)

- [ ] Site settings → **Regional settings**: currency/locale for how you invoice
- [ ] Update seed client billing emails
- [ ] Optional: pin lists on Quick Launch

---

## E. Report back

```
Step 2 complete
Site: https://blendedlight.sharepoint.com/sites/InvoiceandTimeTracking
Seed: yes/no
Issues: none | <short description>
```

Paste red error lines if something failed (no secrets). Script is safe to re-run.

---

## Out of scope for Step 2

- Power Automate flows → **Step 3**
- PDF Word template → later
- Custom React UI → Step 4

## Rollback

Delete the six lists + Invoice PDFs from Site contents, then re-run `provision.ps1`.  
**Do not** delete a production site with real data.
