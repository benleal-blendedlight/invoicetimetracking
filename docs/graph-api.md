# Microsoft Graph API patterns

Power Automate connectors cover the recurring pipeline without a custom app registration. Use Graph when you add a custom SPA or scripts.

## Authentication (single-user)

| Scenario | Approach |
|---|---|
| Power Automate only | Built-in SharePoint + Outlook connectors under your account. **No app reg required.** |
| Custom React SPA later | Single-tenant Entra ID app registration, **SPA** platform, MSAL.js, delegated permissions |
| Unattended script | Prefer running as you via PnP or device code; avoid over-privileged app-only unless needed |

### Suggested delegated Graph permissions (SPA)

- `Sites.ReadWrite.All` or site-scoped permission if available  
- `Files.ReadWrite.All` (PDF library)  
- `Mail.Send`  
- `User.Read`  
- `offline_access`

Admin consent may be required depending on tenant policy.

## SharePoint list CRUD

Power Automate SharePoint actions are preferred inside flows (paging, retries, lookups).

Graph examples:

```http
GET /sites/{site-id}/lists/{list-id}/items?$expand=fields&$filter=fields/Active eq 1
```

```http
POST /sites/{site-id}/lists/{list-id}/items
Content-Type: application/json

{
  "fields": {
    "Title": "Acme Consulting Ltd — Retainer April 2026",
    "InvoiceNumber": "INV-ACME-202604-001",
    "Status": "Draft"
  }
}
```

Notes:

- Prefer list **id** over display name in Graph.  
- `$select` / expand only needed fields.  
- Lookup fields write as `{fieldName}LookupId`.

## Sending mail with PDF attachment

**Outlook connector** in flows: attach file content from SharePoint/OneDrive.

**Graph:**

```http
POST /me/sendMail
```

Attachment: `@odata.type` = `#microsoft.graph.fileAttachment`, `contentBytes` = base64, `name` = `{InvoiceNumber}.pdf`.

Keep HTML body short: title, total, due date, thank-you. Always attach PDF.

## PDF generation options (M365-native rank)

1. **Word template** + “Populate a Microsoft Word template” + “Convert file” → PDF (best layout)  
2. HTML in OneDrive → Convert file  
3. Third-party PDF connector (avoid if possible)

Store under library `Invoice PDFs`, path `yyyy/MM/{InvoiceNumber}.pdf`.

## Idempotency & double-billing guard

Before creating from a recurring template:

- Exists invoice where `RecurringTemplate` = template and `PeriodStart` = period? → skip create.  
- Only advance `NextRunDate` after successful create (or when skip confirms period already billed).

Optional: `Flow Run Log` list for every scheduler pass (template id, result, invoice id, error).
