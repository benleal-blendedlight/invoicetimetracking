# Step 2 checklist — SharePoint provisioning

**Goal:** Lists, library, views, and seed data exist on your M365 tenant so flows (Step 3) have a schema to target.

**Repo artifacts (already pushed):**

- `provision.ps1` (repo root) and `scripts/provision.ps1`
- `scripts/README.md`
- `docs/sharepoint-schema.md` (reference)

---

## A. Before you run the script

- [ ] PowerShell available (`pwsh --version` or Windows PowerShell 5.1+)
- [ ] You can sign in to your M365 tenant as someone who can create lists on the target site
- [ ] Site URL ready, e.g.  
  `https://blendedlight.sharepoint.com/sites/InvoiceandTimeTracking`
- [ ] Repo cloned / pulled (latest includes `-ClientId` support)
- [ ] **Entra app Client ID** for PnP (required by PnP.PowerShell 3.x) — see A2

### A1. Create the site (if it does not exist)

1. Go to SharePoint home → **Create site** → **Team site**
2. Name: **Invoice and Time Tracking** (or **Billing**)
3. Privacy: **Private**
4. Copy the URL → paste into the run command below

### A2. Entra app for PnP (one-time — fixes “valid client id” error)

PnP.PowerShell 3.x no longer ships a multi-tenant login app. You must pass `-ClientId`.

1. Open [Entra admin center → App registrations → New](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)
2. **Name:** `Billing Platform PnP` · **Supported accounts:** Single tenant → **Register**
3. Copy **Application (client) ID**
4. **Authentication** → Advanced → **Allow public client flows = Yes** → Save  
   Optional: Add platform → Mobile and desktop → enable `https://login.microsoftonline.com/common/oauth2/nativeclient`
5. **API permissions** → Add → **SharePoint** → Delegated → **AllSites.FullControl** → Add  
   Then click **Grant admin consent for your tenant**
6. No client secret needed for interactive login

Full notes: [`scripts/README.md`](../scripts/README.md)

---

## B. Run provisioning

```powershell
# If script is blocked by execution policy:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

cd "path\to\invoicetimetracking"   # folder that contains provision.ps1
git pull   # get latest -ClientId fix

$env:PNP_CLIENT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Application (client) ID

./provision.ps1 `
  -SiteUrl "https://blendedlight.sharepoint.com/sites/InvoiceandTimeTracking" `
  -ClientId $env:PNP_CLIENT_ID `
  -SeedSampleData
```

Alternate login if interactive browser fails:

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
| Clients | List present; columns include ClientCode, InvoiceTitleTemplate, BillingEmail |
| Projects | Lookup column **Client** |
| Time Entries | Start/End, Billable, Invoice lookup |
| Recurring Invoices | Amount, SendMode, NextRunDate, Active |
| Invoices | InvoiceNumber, Status choices, PDF Link |
| Invoice Lines | Quantity, UnitPrice, Amount, Invoice lookup |
| Invoice PDFs | Document library |

**Views** (open each list → view dropdown):

- [ ] Clients → **Active Clients**
- [ ] Recurring Invoices → **Due Recurring**, **Active Templates**
- [ ] Invoices → **Draft Invoices**, **Sent**, **Overdue**, **Failed**
- [ ] Time Entries → **Unbilled Time**, **Running**

**Seed data** (if you used `-SeedSampleData`):

- [ ] Clients: Acme Consulting Ltd + Northwind Traders
- [ ] Different `InvoiceTitleTemplate` on each
- [ ] Two Recurring Invoices, SendMode = NotifyOnly
- [ ] `BillingEmail` still example.com → **change to your test mailbox** before any AutoSend

---

## D. Manual polish (5 minutes)

- [ ] Site settings → **Regional settings**: currency/locale match how you invoice (e.g. United Kingdom for GBP)
- [ ] Update seed client **Billing Email** to an address you control
- [ ] Optional: pin the six lists to the site navigation if Quick Launch is messy
- [ ] Optional: create folder `templates` in Invoice PDFs for future Word templates (not required yet)

---

## E. Report back

Reply with something like:

```
Step 2 complete
Site: https://….sharepoint.com/sites/Billing
Seed: yes/no
Issues: none | <short description>
```

Paste any red error lines from the script if something failed — I’ll help fix and we can re-run (script is safe to re-run).

---

## Out of scope for Step 2

- Power Automate flows → **Step 3**
- PDF Word template → later in Phase 2
- Custom React UI → Step 4

---

## Rollback (only if you want a clean slate)

Delete the six lists + Invoice PDFs library from Site contents, then re-run `provision.ps1`.  
**Do not** delete a production site with real data.
