# GitHub repository layout

Target structure for `billing-platform` (name flexible):

```
billing-platform/
├── README.md
├── docs/
│   ├── README.md
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
├── sharepoint/
│   └── lists/                 # PnP templates / site scripts (Step 2)
├── power-automate/
│   ├── expressions/           # copy-paste expressions (Step 3)
│   └── exports/               # .zip flow packages when ready
├── templates/
│   ├── invoice.docx           # Word content-control template
│   └── invoice-email.html
├── scripts/
│   └── provision.ps1          # PnP.PowerShell (Step 2)
└── app/                       # optional React SPA (Step 4)
```

## What to commit

| Commit | Do |
|---|---|
| Docs, scripts, Word template structure | Yes |
| Exported flow zips | Yes (after build) |
| Client real names / live emails in seed examples | Prefer fake/test data in repo |
| Secrets, connection strings, certificates | **Never** |
| PDF copies of real invoices | **Never** |

## Branching (simple)

- `main` — protected when you add automation  
- Feature branches optional; single-operator can commit to `main` for docs

## Scope by step

| Step | Paths in repo |
|---|---|
| **1** (done) | `README.md`, `docs/**` |
| **2** (now) | `scripts/provision.ps1`, `scripts/README.md`, `sharepoint/lists/README.md`, `docs/STEP-02-CHECKLIST.md` |
| **3** | `power-automate/expressions/**`, flow export zips |
| **4** | `app/**` optional SPA |
