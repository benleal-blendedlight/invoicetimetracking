# Billing Platform — Architecture Pack

M365-native replacement for Clockify time tracking + invoicing.

**Stack:** SharePoint (system of record) · Power Automate (scheduler & send) · Outlook (delivery) · optional React SPA later

## Why this exists

Clockify gaps this system closes:

| Need | Clockify | This system |
|---|---|---|
| Monthly fixed-amount recurrence | Creates invoice, notifies you | DraftOnly / NotifyOnly / **AutoSend** |
| Auto-send to client | No | Per-template `SendMode` |
| Client-specific invoice titles | Generic — edit every invoice | Token template on each Client |
| Title includes month & year | Manual | `{{MonthName}} {{Year}}` automatic |
| Data ownership | Clockify cloud | Your M365 tenant |

## Docs index

| File | Contents |
|---|---|
| [architecture.md](./architecture.md) | System map, principles, layers |
| [sharepoint-schema.md](./sharepoint-schema.md) | All lists, columns, views |
| [title-templates.md](./title-templates.md) | Token reference + examples |
| [flows/](./flows/) | Power Automate flow specs |
| [graph-api.md](./graph-api.md) | Auth, list CRUD, mail, PDF |
| [time-tracking.md](./time-tracking.md) | Timer model, retainers vs T&M |
| [roadmap.md](./roadmap.md) | Phased build plan |
| [github-layout.md](./github-layout.md) | Repo structure |
| [STEP-01-CHECKLIST.md](./STEP-01-CHECKLIST.md) | Step 1 — GitHub bootstrap |
| [STEP-02-CHECKLIST.md](./STEP-02-CHECKLIST.md) | Step 2 — SharePoint / PnP provision |

## Design principles

1. **SharePoint is the system of record** — clients, templates, invoices, PDFs live in your tenant.
2. **Power Automate owns the calendar** — only the scheduler creates recurring invoices.
3. **Titles come from the client** — `Client.InvoiceTitleTemplate` is required; humans edit the template once.
4. **SendMode is explicit** — DraftOnly / NotifyOnly / AutoSend per recurring template.
5. **Fail loudly** — send/PDF failures set `Status = Failed` and email you.

## Quick start

- [x] **Step 1** — GitHub repo + architecture pack  
- [ ] **Step 2** — PnP.PowerShell provision SharePoint lists → [STEP-02-CHECKLIST.md](./STEP-02-CHECKLIST.md) · [`scripts/provision.ps1`](../scripts/provision.ps1)  
- [ ] **Step 3** — Power Automate expressions for the scheduler  
- [ ] **Step 4** — Optional React UI (MSAL + Graph)

See the root [README.md](../README.md) for progress and bootstrap notes.
