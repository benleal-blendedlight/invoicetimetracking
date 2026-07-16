# Flow: Invoice Failure Alert

| | |
|---|---|
| **Name** | Invoice Failure Alert |
| **Trigger** | When an Invoices item is modified — Status = Failed |
| **Purpose** | Never silently fail auto-send or PDF generation |

## Steps

1. **Trigger** — SharePoint “When an item is created or modified” on Invoices.  
   Trigger condition (settings):

   ```
   @equals(triggerOutputs()?['body/Status'], 'Failed')
   ```

2. **Send email (high importance)** to you:

   - Subject: `INVOICE FAILED: {Title} ({InvoiceNumber})`  
   - Body: Client name, amount, FailureReason, deep link to list item, SendMode  
   - Importance: High  

## Design notes

- Pair with try/catch in the scheduler and send flows that always write FailureReason.  
- Do not auto-retry infinitely; fix data, then re-queue (ReadyToSend / NextRunDate).

## Test plan

1. Force a failure (invalid email, break PDF path temporarily).  
2. Confirm invoice Status = Failed + FailureReason populated.  
3. Confirm high-importance email arrives within a minute.
