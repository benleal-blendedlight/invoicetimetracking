# Roadmap

## Phase 0 — Foundations (½ day)

- [ ] Create SharePoint site `/sites/Billing`
- [x] Create GitHub repo; commit architecture pack (**Step 1**) — `benleal-blendedlight/invoicetimetracking`
- [ ] Entra app registration only if planning custom SPA soon
- [ ] Confirm Outlook + SharePoint connector access in Power Automate

## Phase 1 — Data model (1 day) → **Step 2**

- [ ] Provision lists via PnP script (`scripts/provision.ps1`)
- [ ] Provision `Invoice PDFs` library
- [ ] Create views (Active Clients, Due Recurring, Draft Invoices, Unbilled Time, Overdue)
- [ ] Seed 1–2 test clients with `InvoiceTitleTemplate`
- [ ] Follow [STEP-02-CHECKLIST.md](./STEP-02-CHECKLIST.md)

## Phase 2 — Title engine + manual invoice (1 day)

- [ ] Instant flow: create invoice from client (resolve title tokens)
- [ ] Word invoice template + PDF path
- [ ] Prove two clients → two distinct titles with month/year, zero manual edits

## Phase 3 — Recurring scheduler (1–2 days) → **Step 3**

- [ ] Daily Recurring Invoice Scheduler
- [ ] SendMode: DraftOnly, NotifyOnly, AutoSend
- [ ] Idempotency guard
- [ ] Advance NextRunDate + LastInvoice
- [ ] Failure alert flow

## Phase 4 — Send pipeline polish (1 day)

- [ ] On-demand send for ReadyToSend
- [ ] Email HTML templates
- [ ] CC from Client.CCEmails
- [ ] Mark Paid flow + cashflow views

## Phase 5 — Time tracking (1–2 days)

- [ ] Start/stop entry UI
- [ ] Unbilled queue
- [ ] Invoice unbilled time flow (T&M path)

## Phase 6 — Optional custom UI (later) → **Step 4**

- [ ] React SPA + MSAL
- [ ] Dashboard: timer, due recurrings, drafts, revenue

---

## MVP definition of done

You can stop calling Clockify “good enough” when:

1. A recurring template with `NotifyOnly` creates an invoice on the right day with a **client-specific title including month and year**.  
2. Switching that template to `AutoSend` emails the client a PDF without manual steps.  
3. A second client uses a different title template and never needs hand-edited titles.  
4. A forced PDF/email failure emails **you** with FailureReason.  
5. All artifacts live under your M365 tenant + this GitHub repo.
