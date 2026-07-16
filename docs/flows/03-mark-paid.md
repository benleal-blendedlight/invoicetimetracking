# Flow: Mark Invoice Paid

| | |
|---|---|
| **Name** | Mark Invoice Paid |
| **Trigger** | For a selected item (Invoices) or when Status set to Paid |
| **Purpose** | Record payment; keep cashflow views accurate |

## Steps

1. Trigger — selected invoice (must be Status = Sent, typically).  
2. Update item — Status = `Paid` (optional: PaidDate = today).  
3. Optional — send receipt email if you add `Clients.SendReceipt` = Yes later.

## Views that depend on this

- Cash collected this month: Status = Paid, SentAt/PaidDate in range  
- Outstanding AR: Status = Sent, DueDate filters  

## Test plan

1. Mark a Sent test invoice Paid from the list.  
2. Confirm it leaves Overdue / Outstanding views.  
3. Confirm it appears in a “Paid this month” view.
