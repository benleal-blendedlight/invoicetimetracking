# Architecture

## Goals

Replace Clockify for **time tracking + client invoicing** while staying entirely inside an **M365 tenant**.

### Outcomes

- Recurring fixed-amount invoices fire on schedule without manual recreation
- Per-template choice: draft only, notify owner, or **auto-send to client**
- Invoice titles unique per client, always including the correct month/year
- PDFs and email sent from your domain via Outlook
- All data owned by you in SharePoint

## System layers

| Layer | Technology | Responsibility |
|---|---|---|
| System of record | SharePoint lists + document library | Clients, templates, invoices, time, PDFs |
| Calendar / automation | Power Automate | Daily due-check, create, PDF, send, advance next run |
| Delivery | Outlook (Office 365 connector) | Client invoices + owner notifications + failure alerts |
| Identity | Your M365 account (connectors) | Single-user; no multi-tenant app required for flows |
| Optional UI | Power Apps or React + MSAL + Graph | Time entry, review drafts, dashboard |
| Source control | GitHub | Docs, PnP scripts, flow exports, Word template |

## Data flow — recurring invoice (happy path)

1. **Daily 06:00** — Scheduler flow runs.
2. Query `Recurring Invoices` where `Active = true` and `NextRunDate ≤ today`.
3. For each due template:
   - Load parent **Client** (title template, billing email, payment terms, currency).
   - Compute period (month start/end), issue date, due date.
   - **Resolve title** from `Client.InvoiceTitleTemplate` tokens.
   - Allocate **invoice number**.
   - Idempotency check: skip if invoice already exists for this template + period.
   - Create **Invoice** (`Draft`) + **Invoice Line**.
   - Branch on **SendMode**:
     - `DraftOnly` → leave as Draft.
     - `NotifyOnly` → PDF + email you; status `ReadyToSend`.
     - `AutoSend` → PDF + email client; status `Sent`.
   - Advance `NextRunDate`, set `LastRunDate` and `LastInvoice`.
4. On any failure → status `Failed` + failure-alert flow emails you.

## SendMode decision matrix

| SendMode | Creates invoice | Generates PDF | Emails you | Emails client | Final status |
|---|---|---|---|---|---|
| DraftOnly | Yes | Optional | No | No | Draft |
| NotifyOnly | Yes | Yes | Yes | No | ReadyToSend |
| AutoSend | Yes | Yes | Optional BCC | Yes | Sent |

**Recommendation:** start new clients on `NotifyOnly`. Switch trusted retainers to `AutoSend` once title, amount, and PDF look correct for 1–2 cycles.

## What is deliberately out of scope (v1)

- Multi-user permissions / team timesheets
- Payment gateway / card collection
- Multi-currency FX conversion
- Client portal
- Clockify import automation (manual CSV import is fine initially)

## Related docs

- [sharepoint-schema.md](./sharepoint-schema.md)
- [title-templates.md](./title-templates.md)
- [flows/01-recurring-scheduler.md](./flows/01-recurring-scheduler.md)
- [graph-api.md](./graph-api.md)
