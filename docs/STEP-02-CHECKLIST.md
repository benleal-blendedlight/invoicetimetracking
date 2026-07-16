# Step 2 checklist — SharePoint provisioning

**Goal:** Lists, library, views, and seed data exist on your M365 tenant so flows (Step 3) have a schema to target.

**Repo artifacts (already pushed):**

- `scripts/provision.ps1`
- `scripts/README.md`
- `docs/sharepoint-schema.md` (reference)

---

## A. Before you run the script

- [ ] PowerShell available (`pwsh --version` or Windows PowerShell 5.1+)
- [ ] You can sign in to your M365 tenant as someone who can create lists on the target site
- [ ] You know (or will create) the site URL, e.g.  
  `https://<tenant>.sharepoint.com/sites/Billing`
- [ ] Repo cloned (or at least `scripts/provision.ps1` downloaded)

### Create the site (if it does not exist)

1. Go to SharePoint home → **Create site** → **Team site**
2. Name: **Billing** (alias `Billing` is fine)
3. Privacy: **Private**
4. Copy the URL → paste into the run command below

---

## B. Run provisioning

```powershell
cd path/to/invoicetimetracking/scripts

# Installs PnP.PowerShell if needed, then creates everything
./provision.ps1 -SiteUrl "https://YOUR_TENANT.sharepoint.com/sites/Billing" -SeedSampleData
```

Alternate login if interactive browser fails:

```powershell
./provision.ps1 -SiteUrl "https://YOUR_TENANT.sharepoint.com/sites/Billing" -SeedSampleData -LoginMode DeviceLogin
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
