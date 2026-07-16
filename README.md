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

## Step 1 — Create the GitHub repo and push this pack

You confirmed you have a GitHub account but **no repo yet**. Do this once:

### A. Create the empty repo on GitHub

1. Open [https://github.com/new](https://github.com/new)
2. **Repository name:** `billing-platform` (or `clockify-replacement` — your choice)
3. **Description:** `M365 billing & time tracking — SharePoint + Power Automate`
4. Set to **Private** (recommended — client names and billing data will live nearby in docs/examples)
5. **Do not** add a README, .gitignore, or license (this pack already has a README)
6. Click **Create repository**

### B. Push from a local folder

Copy the contents of this project’s docs export into a local folder, then:

```bash
# from the folder that contains README.md and docs/
git init
git add README.md docs/
git commit -m "docs: add architecture pack (SharePoint, flows, title templates)"
git branch -M main
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/billing-platform.git
git push -u origin main
```

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
