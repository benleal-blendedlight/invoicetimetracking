# Flow: Recurring Invoice Scheduler

| | |
|---|---|
| **Name** | Recurring Invoice Scheduler |
| **Trigger** | Recurrence — daily at 06:00 (tenant local time) |
| **Purpose** | Create due fixed-amount invoices with client-specific titles; notify or auto-send per SendMode |

## Connections required

- SharePoint (your tenant)
- Office 365 Outlook
- Word Online (Business) *or* OneDrive + Convert file — for PDF

## Steps

### 1. Recurrence

- Interval: 1 day  
- Time: 06:00  
- Cheap to run; work only when templates are due.

### 2. Get due templates

**SharePoint — Get items** on `Recurring Invoices`

Filter (ODATA-style):

```
Active eq 1 and NextRunDate le datetime'@{formatDateTime(utcNow(), 'yyyy-MM-dd')}T00:00:00Z'
```

- Expand / include Client lookup fields (Title, ClientCode, BillingEmail, CCEmails, InvoiceTitleTemplate, InvoicePrefix, PaymentTermsDays, Currency).
- Top count: sufficient for your volume (e.g. 100).

### 3. Apply to each template

- Concurrency control: **1** (keeps invoice number sequences clean).

### 4. Resolve period (Compose)

For monthly cadence, using `NextRunDate` as the anchor:

| Variable | Logic |
|---|---|
| PeriodStart | First day of month of NextRunDate |
| PeriodEnd | Last day of that month |
| IssueDate | Today (date only) |
| DueDate | IssueDate + Client.PaymentTermsDays |

### 5. Idempotency check

**Get items** on `Invoices` where:

- `RecurringTemplate` = this template id  
- `PeriodStart` = computed PeriodStart  

If any item found → **skip create**; optionally still fix `NextRunDate` if stale; continue to next template.

### 6. Build title from template

Read `Client.InvoiceTitleTemplate`.  
Replace all tokens (see [title-templates.md](../title-templates.md)).  
Store in variable `ResolvedTitle`.

Fail if template empty or unresolved `{{` remain.

### 7. Allocate invoice number

1. Prefix = `Client.InvoicePrefix` or `INV-{ClientCode}`  
2. YearMonth = `yyyyMM` of PeriodStart  
3. Query existing invoices with number startswith `{Prefix}-{YearMonth}`  
4. Sequence = max + 1, padded to 3 digits  
5. `InvoiceNumber` = `{Prefix}-{YearMonth}-{seq}`  

Example: `INV-ACME-202604-001`

### 8. Create Invoice (Draft)

**Create item** on `Invoices`:

- Title = ResolvedTitle  
- InvoiceNumber, Client, RecurringTemplate  
- IssueDate, DueDate, PeriodStart, PeriodEnd  
- Subtotal = Amount, Tax as configured, Total  
- Currency, SendMode (snapshot)  
- Status = `Draft`

### 9. Create Invoice Line

- Title = token-resolved `LineDescription`  
- Quantity = 1  
- UnitPrice = Amount  
- Amount = Amount  
- Invoice = new invoice id  
- SortOrder = 1  

### 10. Branch on SendMode

| Mode | Actions |
|---|---|
| DraftOnly | Skip PDF/email (or PDF only if you prefer). Leave Status = Draft. |
| NotifyOnly | Generate PDF → email **you** → Status = ReadyToSend |
| AutoSend | Generate PDF → email **client** → Status = Sent, SentAt = now |

### 11. Generate PDF

Preferred path:

1. Populate Word invoice template (content controls)  
2. Convert to PDF  
3. Save to `Invoice PDFs` library under `yyyy/MM/`  
4. Write `PDFLink` on invoice  

### 12. Send or notify

**Outlook — Send an email (V2)**

**AutoSend**

- To: Client.BillingEmail  
- CC: Client.CCEmails  
- Subject: ResolvedTitle (or `Invoice {InvoiceNumber} — {ResolvedTitle}`)  
- Body: short HTML (amount, due date, thanks)  
- Attachment: PDF  

**NotifyOnly**

- To: NotifyEmail or your mailbox  
- Subject: `Invoice ready: {ResolvedTitle}`  
- Body: review link to SharePoint item + amounts + “approve & send” instructions  
- Attachment: PDF  

### 13. Update invoice status

- Success paths as in table above  
- Catch block: Status = `Failed`, FailureReason = error message  

### 14. Advance template (always after successful create)

**Update item** on `Recurring Invoices`:

- LastRunDate = today  
- NextRunDate = same DayOfMonth, next month (clamp 28–31 carefully; prefer DayOfMonth ≤ 28)  
- LastInvoice = new invoice id  

**Critical:** advance even for NotifyOnly / DraftOnly so the scheduler never double-creates.

## Error handling

- Scope each template iteration in a try/catch (Configure run after).  
- On failure: invoice Failed if created; never advance NextRunDate if create failed (so it retries tomorrow).  
- Failure alert flow watches Status = Failed.

## Test plan

1. One template, NextRunDate = today, SendMode = DraftOnly → invoice + line only.  
2. Same with NotifyOnly → you receive email + PDF; status ReadyToSend.  
3. Same with AutoSend to a test mailbox you control.  
4. Re-run same day → idempotency skips second invoice.  
5. Two clients, different title templates → two correct distinct titles.
