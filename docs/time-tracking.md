# Time tracking

## Timer model

| State | Start | End | Notes |
|---|---|---|---|
| Running | set | null | Only one running timer in v1 |
| Stopped | set | set | Write DurationMinutes, Rate snapshot, Amount |

**Amount** = `(DurationMinutes / 60) × Rate`  
**Rate** = Project.HourlyRate if set, else Client.DefaultRate

## Unbilled queue

Filter **Time Entries**:

- `Billable = Yes`  
- `Invoice` is empty  

Action: “Create invoice from unbilled” groups by Client, creates Invoice + Lines, sets each entry’s `Invoice` lookup.

## Retainers vs T&M (important)

| Type | Source of amount | Uses Time Entries? |
|---|---|---|
| Recurring fixed retainer | `Recurring Invoices.Amount` | **No** |
| Time & materials | Sum of unbilled entries | **Yes** |

Fixed retainers intentionally do **not** pull time. That matches the Clockify retainer pattern you want and keeps auto-send safe (amount is known).

Time entries remain for:

- Personal productivity / reporting  
- Ad-hoc T&M invoices  
- Optional future “hours worked” appendix (non-priced)

## Where to capture time

| Phase | UI |
|---|---|
| 1 | SharePoint list forms or simple Power App |
| 2 | Custom web app (MSAL → Graph → SharePoint) |
| 3 | Browser extension / tray timer |

## Acceptance checks

- Stop timer writes duration and amount.  
- Unbilled view excludes non-billable and already invoiced entries.  
- Creating a retainer invoice does not mark time entries as billed.
