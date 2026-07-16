# Invoice title templates

## Problem

Clockify (and many tools) generate a generic invoice title. You end up editing every invoice so the client sees something meaningful that includes the service period.

## Rule

**Titles are never typed on the invoice.**  
They are always generated from `Clients.InvoiceTitleTemplate` at create time (manual flow or scheduler).

`InvoiceTitleTemplate` is **required** on every Active client.

---

## Tokens

| Token | Source | Example |
|---|---|---|
| `{{ClientName}}` | Clients.Title | Acme Consulting Ltd |
| `{{ClientCode}}` | Clients.ClientCode | ACME |
| `{{MonthName}}` | Full English month of IssueDate / PeriodStart | April |
| `{{MonthShort}}` | 3-letter month | Apr |
| `{{MonthNumber}}` | Zero-padded month | 04 |
| `{{Year}}` | 4-digit year | 2026 |
| `{{YearShort}}` | 2-digit year | 26 |
| `{{PeriodStart}}` | Formatted period start (`dd MMM yyyy`) | 01 Apr 2026 |
| `{{PeriodEnd}}` | Formatted period end | 30 Apr 2026 |
| `{{InvoiceNumber}}` | Generated number | INV-ACME-202604-001 |

### Which date drives month/year?

For **monthly retainers**, use **PeriodStart** (first day of the service month), not “today”, so an invoice generated on the 1st for *last* month still titles correctly if you ever bill in arrears.

Default v1 convention: **bill current month in advance** on DayOfMonth → PeriodStart = first day of current month of `NextRunDate`.

---

## Examples

| Client | Template | Resolved (April 2026) |
|---|---|---|
| Acme Consulting Ltd | `{{ClientName}} — Retainer {{MonthName}} {{Year}}` | Acme Consulting Ltd — Retainer April 2026 |
| Northwind Traders | `{{ClientCode}} Services Invoice · {{MonthShort}} {{Year}}` | NWT Services Invoice · Apr 2026 |
| Contoso | `Professional services for {{PeriodStart}} – {{PeriodEnd}}` | Professional services for 01 Apr 2026 – 30 Apr 2026 |
| Fabrikam | `{{ClientName}} \| Invoice {{InvoiceNumber}}` | Fabrikam \| Invoice INV-FAB-202604-001 |

---

## Line description tokens

`Recurring Invoices.LineDescription` supports a subset:

- `{{MonthName}}`, `{{MonthShort}}`, `{{Year}}`
- `{{PeriodStart}}`, `{{PeriodEnd}}`

Example: `Monthly retainer — {{MonthName}} {{Year}}`

---

## Power Automate resolution sketch

Conceptually (exact expressions delivered in Step 3):

```
title = Client.InvoiceTitleTemplate
title = replace(title, '{{ClientName}}', Client.Title)
title = replace(title, '{{ClientCode}}', Client.ClientCode)
title = replace(title, '{{MonthName}}', formatDateTime(PeriodStart, 'MMMM'))
title = replace(title, '{{MonthShort}}', formatDateTime(PeriodStart, 'MMM'))
title = replace(title, '{{MonthNumber}}', formatDateTime(PeriodStart, 'MM'))
title = replace(title, '{{Year}}', formatDateTime(PeriodStart, 'yyyy'))
title = replace(title, '{{YearShort}}', formatDateTime(PeriodStart, 'yy'))
title = replace(title, '{{PeriodStart}}', formatDateTime(PeriodStart, 'dd MMM yyyy'))
title = replace(title, '{{PeriodEnd}}', formatDateTime(PeriodEnd, 'dd MMM yyyy'))
title = replace(title, '{{InvoiceNumber}}', variables('InvoiceNumber'))
```

Nest `replace()` calls or use successive Compose/Set variable actions.

### Validation

Before create:

- If `InvoiceTitleTemplate` is empty → fail the run for that client, set template or invoice Failed, alert owner.
- If resolved title still contains `{{` → fail (unknown/unreplaced token).

---

## Acceptance test (must pass before enabling AutoSend)

1. Seed two clients with **different** templates (see examples above).
2. Run create-invoice (manual or scheduler) for both for the same period.
3. Confirm:
   - Titles differ
   - Each includes the correct month name and year
   - **Zero** manual edits to Title fields
