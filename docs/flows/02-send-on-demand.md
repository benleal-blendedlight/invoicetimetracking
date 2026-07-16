# Flow: Send Invoice on Demand

| | |
|---|---|
| **Name** | Send Invoice on Demand |
| **Trigger** | When an Invoices item is modified (or manual button) |
| **Purpose** | Send a reviewed Draft / ReadyToSend invoice to the client |

## When to use

- After NotifyOnly scheduler run — you review PDF, then send  
- Fully manual invoices  
- Re-send after fixing a Failed invoice (reset status carefully)

## Trigger options (pick one)

### Option A — Status change

**When an item is modified** on Invoices  
Condition: `Status` changed to `ReadyToSend` **and** a flag `SendRequested` = Yes  

(Or simply: user sets Status to a dedicated value `SendNow`.)

### Option B — For a selected item

**Instant cloud flow** — “For a selected item” on Invoices list.  
Best UX from SharePoint list UI.

## Steps

1. **Get invoice** (trigger body or Get item).  
2. **Get Client** — BillingEmail, CCEmails, Title.  
3. **Get Invoice Lines** — filter by Invoice lookup.  
4. **Generate PDF** if `PDFLink` empty; else download existing file.  
5. **Send email (V2)** — To client, CC list, attach PDF.  
6. **Update invoice** — Status = `Sent`, SentAt = utcNow().  
7. **On error** — Status = `Failed`, FailureReason = message.

## Guardrails

- Do not send if Status is already `Sent` or `Void` (unless explicit Resend flag).  
- Do not send if BillingEmail is empty.  
- Prefer For-a-selected-item so accidental list edits don’t fire sends.

## Test plan

1. Create draft manually with known test client email (your alt mailbox).  
2. Run flow from list item menu.  
3. Confirm mail + attachment + Status = Sent.  
4. Confirm second run is blocked or no-ops.
