# SharePoint schema

**Site recommendation:** `https://<tenant>.sharepoint.com/sites/Billing`

**Document library:** `Invoice PDFs`  
Folder pattern: `yyyy/MM/{InvoiceNumber}.pdf` (e.g. `2026/04/INV-ACME-202604-001.pdf`)

---

## Lists overview

| List | Purpose |
|---|---|
| Clients | Master client + **InvoiceTitleTemplate** |
| Projects | Optional engagements under a client |
| Time Entries | Clockify-style logs (T&M; not used by fixed retainers) |
| Recurring Invoices | Standing orders — fixed amount + SendMode + schedule |
| Invoices | Every invoice instance |
| Invoice Lines | Line items for PDF |

---

## 1. Clients

Master client records. Each client owns billing contact details, default rates, and the invoice title template that eliminates manual title edits.

| Display name | Internal name | Type | Required | Notes |
|---|---|---|---|---|
| Title | Title | Single line of text | Yes | Legal / display name |
| Client Code | ClientCode | Single line of text | Yes | Short unique code for invoice numbers (e.g. `ACME`) |
| Billing Email | BillingEmail | Single line of text | Yes | Primary recipient; semicolon-separated OK |
| CC Emails | CCEmails | Multiple lines of text | | Optional CC list |
| Billing Address | BillingAddress | Multiple lines of text | | Printed on PDF |
| Currency | Currency | Choice: GBP, USD, EUR | Yes | Default GBP |
| Default Rate | DefaultRate | Number (currency) | | Hourly fallback |
| Payment Terms Days | PaymentTermsDays | Number | Yes | Default 30 |
| Invoice Title Template | InvoiceTitleTemplate | Single line of text | Yes | Tokenized — see title-templates.md |
| Invoice Prefix | InvoicePrefix | Single line of text | | e.g. `INV-ACME` |
| Status | Status | Choice: Active, Paused, Archived | Yes | |
| Notes | Notes | Multiple lines of text | | Internal only — never on PDF |

**Views:** Active Clients (`Status = Active`, sort Title)

---

## 2. Projects

| Display name | Internal name | Type | Required | Notes |
|---|---|---|---|---|
| Title | Title | Single line of text | Yes | Project name |
| Client | Client | Lookup → Clients | Yes | Parent client |
| Billable | Billable | Yes/No | Yes | Default Yes |
| Hourly Rate | HourlyRate | Number | | Overrides client DefaultRate |
| Status | Status | Choice: Active, Completed, Archived | Yes | |

**Views:** Active Projects

---

## 3. Time Entries

Source of truth for T&M invoices. **Not** required for fixed-amount recurring retainers.

| Display name | Internal name | Type | Required | Notes |
|---|---|---|---|---|
| Title | Title | Single line of text | Yes | Work description |
| Client | Client | Lookup → Clients | Yes | Denormalized for filtering |
| Project | Project | Lookup → Projects | | Recommended |
| Start | Start | Date and time | Yes | |
| End | End | Date and time | | Null while timer running |
| Duration Minutes | DurationMinutes | Number | | Computed on stop |
| Billable | Billable | Yes/No | Yes | Default from project |
| Rate | Rate | Number | | Snapshot at entry time |
| Amount | Amount | Number | | Hours × Rate |
| Invoice | Invoice | Lookup → Invoices | | Null = unbilled |
| Tags | Tags | Choice (multi) | | Meeting, Dev, Support, … |

**Views:**
- Unbilled Time — `Billable = Yes` AND `Invoice` is empty
- Running — `End` is empty

---

## 4. Recurring Invoices

Standing orders. Replaces Clockify’s limited recurring behaviour.

| Display name | Internal name | Type | Required | Notes |
|---|---|---|---|---|
| Title | Title | Single line of text | Yes | Internal label only (not client-facing) |
| Client | Client | Lookup → Clients | Yes | Title template read from client |
| Amount | Amount | Number | Yes | Fixed amount each cycle |
| Currency | Currency | Choice | | Usually from client |
| Line Description | LineDescription | Single line of text | Yes | Tokens allowed |
| Cadence | Cadence | Choice: Monthly | Yes | v1 = Monthly only |
| Day of Month | DayOfMonth | Number | Yes | Prefer 1–28 |
| Send Mode | SendMode | Choice: DraftOnly, NotifyOnly, AutoSend | Yes | |
| Next Run Date | NextRunDate | Date only | Yes | Scheduler key |
| Last Run Date | LastRunDate | Date only | | Audit |
| Last Invoice | LastInvoice | Lookup → Invoices | | Most recent produced |
| Active | Active | Yes/No | Yes | No = paused |
| Notify Email | NotifyEmail | Single line of text | | Override for NotifyOnly |

**Views:**
- Due Recurring — `Active = Yes` AND `NextRunDate ≤ [Today]`
- Active Templates — `Active = Yes`

---

## 5. Invoices

| Display name | Internal name | Type | Required | Notes |
|---|---|---|---|---|
| Title | Title | Single line of text | Yes | **Always** from client template |
| Invoice Number | InvoiceNumber | Single line of text | Yes | Unique; see numbering |
| Client | Client | Lookup → Clients | Yes | |
| Recurring Template | RecurringTemplate | Lookup → Recurring Invoices | | Null if manual |
| Issue Date | IssueDate | Date only | Yes | |
| Due Date | DueDate | Date only | Yes | Issue + PaymentTermsDays |
| Period Start | PeriodStart | Date only | | Usually month start |
| Period End | PeriodEnd | Date only | | Usually month end |
| Subtotal | Subtotal | Number | Yes | |
| Tax Rate | TaxRate | Number | | e.g. 20 for 20% VAT |
| Tax Amount | TaxAmount | Number | | |
| Total | Total | Number | Yes | |
| Currency | Currency | Choice | Yes | Snapshot at create |
| Status | Status | Choice: Draft, ReadyToSend, Sent, Paid, Void, Failed | Yes | |
| Send Mode | SendMode | Choice | | Snapshot from template |
| Sent At | SentAt | Date and time | | |
| PDF Link | PDFLink | Hyperlink | | |
| Failure Reason | FailureReason | Multiple lines of text | | When Failed |

**Invoice number pattern:** `{InvoicePrefix}-{YYYY}{MM}-{seq}`  
Example: `INV-ACME-202604-001`

**Views:**
- Draft Invoices — `Status = Draft` or `ReadyToSend`
- Sent — `Status = Sent`
- Overdue — `Status = Sent` AND `DueDate < [Today]`
- Failed — `Status = Failed`

---

## 6. Invoice Lines

| Display name | Internal name | Type | Required | Notes |
|---|---|---|---|---|
| Title | Title | Single line of text | Yes | Line text on PDF |
| Invoice | Invoice | Lookup → Invoices | Yes | Parent |
| Quantity | Quantity | Number | Yes | Retainers use 1 |
| Unit Price | UnitPrice | Number | Yes | |
| Amount | Amount | Number | Yes | Qty × UnitPrice |
| Sort Order | SortOrder | Number | | PDF order |
| Time Entry | TimeEntry | Lookup → Time Entries | | When derived from time |

**Views:** All items (filter by Invoice in flows)

---

## Relationships (logical)

```
Clients 1──* Projects
Clients 1──* Time Entries
Clients 1──* Recurring Invoices
Clients 1──* Invoices
Recurring Invoices 1──* Invoices
Invoices 1──* Invoice Lines
Invoices 1──* Time Entries (billed link)
Projects 1──* Time Entries
```

## Provisioning order

Create lists in this order so lookups resolve:

1. Clients  
2. Projects  
3. Invoices *(before Time Entries and Recurring if you want LastInvoice / Invoice lookups — or create lookups after all lists exist)*  
4. Invoice Lines  
5. Time Entries  
6. Recurring Invoices  
7. Add remaining lookups (LastInvoice, Invoice on Time Entries, RecurringTemplate)

Practical approach: create all lists with non-lookup columns first, then add lookup columns.

## Seed data (for testing)

After provisioning, create at least:

| Client | ClientCode | InvoiceTitleTemplate | PaymentTermsDays |
|---|---|---|---|
| Acme Consulting Ltd | ACME | `{{ClientName}} — Retainer {{MonthName}} {{Year}}` | 30 |
| Northwind Traders | NWT | `{{ClientCode}} Services Invoice · {{MonthShort}} {{Year}}` | 14 |

Plus one Recurring Invoice per client (Amount, DayOfMonth=1, SendMode=NotifyOnly, NextRunDate=today or tomorrow).
