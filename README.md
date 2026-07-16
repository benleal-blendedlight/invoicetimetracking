# Billing Platform

A Microsoft 365–native replacement for **Clockify** time tracking and client invoicing.

Built for a single operator on an M365 tenant: **SharePoint lists** as the system of record, **Power Automate** for monthly recurring invoices, **Outlook** for delivery (including true auto-send), and client-specific invoice titles with month/year tokens.

---

## The two problems this solves

1. **Recurring invoices that can auto-send**  
   Clockify creates the invoice and emails *you*. This system supports three modes per template:
   - `DraftOnly` — create in SharePoint only  
   - `NotifyOnly` — create + email you (Clockify-like)  
   - `AutoSend` — create PDF and email the **client**

2. **Invoice titles unique per client, with month & year**  
   Each client has a required `InvoiceTitleTemplate`, e.g.  
   `{{ClientName}} — Retainer {{MonthName}} {{Year}}`  
   → *Acme Consulting Ltd — Retainer April 2026*  
   No manual title edits every billing cycle.

---

## Repository layout

```
.
├── README.md                 ← you are here
├── docs/                     ← architecture pack (start here)
│   ├── architecture.md
│   ├── sharepoint-schema.md
│   ├── title-templates.md
│   ├── graph-api.md
│   ├── time-tracking.md
│   ├── roadmap.md
│   ├── github-layout.md
│   └── flows/
│       ├── 01-recurring-scheduler.md
│       ├── 02-send-on-demand.md
│       ├── 03-mark-paid.md
│       └── 04-failure-alert.md
├── sharepoint/               ← (Step 2) PnP provisioning
├── power-automate/           ← (Step 3) flow exports & expressions
├── templates/                ← Word invoice + email HTML
├── scripts/                  ← provision.ps1 etc.
└── app/                      ← (Step 4, optional) React SPA
```

Full layout notes: [docs/github-layout.md](docs/github-layout.md)

---

## Progress

| Step | Status | What |
|---|---|---|
| **1** | Done | Architecture pack on GitHub (`benleal-blendedlight/invoicetimetracking`) |
| **2** | **You now** | Provision SharePoint with PnP — [`docs/STEP-02-CHECKLIST.md`](docs/STEP-02-CHECKLIST.md) |
| **3** | Next | Power Automate scheduler expressions |
| **4** | Later | Optional React UI (MSAL + Graph) |

### Step 2 quick start

```powershell
cd scripts
./provision.ps1 -SiteUrl "https://YOUR_TENANT.sharepoint.com/sites/Billing" -SeedSampleData
```

Full checklist: [`docs/STEP-02-CHECKLIST.md`](docs/STEP-02-CHECKLIST.md) · Script notes: [`scripts/README.md`](scripts/README.md)

### Step 1 (completed)

Repo: https://github.com/benleal-blendedlight/invoicetimetracking

Replace `<YOUR_GITHUB_USERNAME>` and the repo name if you chose differently.

### C. Confirm

- [ ] Repo exists and is private  
- [ ] `README.md` renders on the repo home page  
- [ ] `docs/` tree is visible with all linked files  
- [ ] You can open `docs/sharepoint-schema.md` and `docs/flows/01-recurring-scheduler.md` in the browser  

**When A–C are done, reply: “Step 1 complete”** (paste your repo URL if you want a double-check).  
Then we move to **Step 2 — PnP.PowerShell list provisioning**.

---

## Architecture at a glance

```
┌─────────────────────────────────────────────────────────┐
│  You (operator)                                         │
│  SharePoint lists · optional Power App / React UI       │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  SharePoint site  /sites/Billing                        │
│  Clients · Projects · Time Entries                      │
│  Recurring Invoices · Invoices · Invoice Lines          │
│  Library: Invoice PDFs                                  │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  Power Automate                                         │
│  Daily scheduler → create invoice + resolve title       │
│  Branch on SendMode → Draft / Notify you / AutoSend     │
│  PDF (Word template) → Outlook email                    │
│  Failure alert → high-importance mail to you            │
└─────────────────────────────────────────────────────────┘
```

Details: [docs/architecture.md](docs/architecture.md)

---

## Build order (after Step 1)

| Step | Deliverable | Your action |
|---|---|---|
| 1 | Architecture pack in GitHub | Create repo + push *(now)* |
| 2 | PnP script + list schema | Run script against `/sites/Billing` |
| 3 | Scheduler + send flows | Import/build flows, set connections |
| 4 | Optional custom UI | MSAL app registration + React |

Roadmap detail: [docs/roadmap.md](docs/roadmap.md)

---

## License / scope

Personal / single-operator tool for your M365 tenant. Not multi-tenant SaaS.
