<#
.SYNOPSIS
  Provision SharePoint lists, columns, views, and Invoice PDFs library for the billing platform.

.DESCRIPTION
  Idempotent where practical: re-running skips existing lists/fields and continues.
  Creates lists in dependency-safe order, then lookup columns, then views, then optional seed data.

.PARAMETER SiteUrl
  Full SharePoint site URL, e.g. https://contoso.sharepoint.com/sites/Billing

.PARAMETER ClientId
  Entra app Application (client) ID. Required by PnP.PowerShell 3.x for Interactive/DeviceLogin.
  Falls back to env var PNP_CLIENT_ID if omitted.

.PARAMETER Tenant
  Optional tenant domain or ID, e.g. blendedlight.onmicrosoft.com

.PARAMETER SeedSampleData
  If set, creates two test clients and one recurring template each (NotifyOnly).

.PARAMETER LoginMode
  Interactive (default), DeviceLogin, or WebLogin (legacy).

.EXAMPLE
  ./provision.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/Billing" -ClientId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

.EXAMPLE
  ./provision.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/Billing" -ClientId $env:PNP_CLIENT_ID -SeedSampleData
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SiteUrl,

  [string]$ClientId = $env:PNP_CLIENT_ID,

  [string]$Tenant,

  [switch]$SeedSampleData,

  [ValidateSet("Interactive", "DeviceLogin", "WebLogin")]
  [string]$LoginMode = "Interactive"
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
  Write-Host "    OK  $Message" -ForegroundColor Green
}

function Write-Skip([string]$Message) {
  Write-Host "    --  $Message" -ForegroundColor DarkGray
}

function Write-Warn([string]$Message) {
  Write-Host "    !!  $Message" -ForegroundColor Yellow
}

function Ensure-Module {
  if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Step "Installing PnP.PowerShell (CurrentUser)…"
    Install-Module PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
  }
  Import-Module PnP.PowerShell -ErrorAction Stop
  $ver = (Get-Module PnP.PowerShell).Version
  Write-Ok "PnP.PowerShell $ver loaded"
}

function Connect-BillingSite {
  Write-Step "Connecting to $SiteUrl"

  # PnP.PowerShell 2.x/3.x removed the multi-tenant "PnP Management Shell" app.
  # Interactive and DeviceLogin require an Entra app Client ID (public client).
  if ($LoginMode -ne "WebLogin" -and [string]::IsNullOrWhiteSpace($ClientId)) {
    Write-Host ""
    Write-Host "PnP.PowerShell requires -ClientId (Entra app Application ID)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "One-time setup (tenant admin or app creator):" -ForegroundColor Cyan
    Write-Host "  1. https://entra.microsoft.com → Identity → Applications → App registrations → New registration"
    Write-Host "  2. Name: Billing Platform PnP   Supported accounts: Single tenant"
    Write-Host "  3. After create → copy Application (client) ID"
    Write-Host "  4. Authentication → Advanced → Allow public client flows = Yes → Save"
    Write-Host "  5. API permissions → Add → SharePoint → Delegated → AllSites.FullControl"
    Write-Host "     (or Microsoft Graph Sites.FullControl.All if you prefer Graph-backed ops)"
    Write-Host "  6. Grant admin consent for the tenant"
    Write-Host ""
    Write-Host "Then re-run:" -ForegroundColor Cyan
    Write-Host "  ./provision.ps1 -SiteUrl `"$SiteUrl`" -ClientId `"YOUR-APP-CLIENT-ID`" -SeedSampleData"
    Write-Host ""
    Write-Host "Or set once per session:" -ForegroundColor Cyan
    Write-Host "  `$env:PNP_CLIENT_ID = 'YOUR-APP-CLIENT-ID'"
    Write-Host ""
    throw "Missing -ClientId. See scripts/README.md (Entra app for PnP)."
  }

  $connectParams = @{ Url = $SiteUrl }
  if (-not [string]::IsNullOrWhiteSpace($ClientId)) {
    $connectParams.ClientId = $ClientId
  }
  if (-not [string]::IsNullOrWhiteSpace($Tenant)) {
    $connectParams.Tenant = $Tenant
  }

  switch ($LoginMode) {
    "DeviceLogin" {
      $connectParams.DeviceLogin = $true
      Connect-PnPOnline @connectParams
    }
    "WebLogin" {
      # Legacy cookie-based login — no ClientId. May be blocked by Conditional Access.
      Write-Warn "WebLogin is legacy and may fail under modern Conditional Access."
      Connect-PnPOnline -Url $SiteUrl -UseWebLogin
    }
    default {
      $connectParams.Interactive = $true
      Connect-PnPOnline @connectParams
    }
  }

  $web = Get-PnPWeb
  Write-Ok "Connected as site: $($web.Title) ($($web.Url))"
}

function Ensure-List {
  param(
    [string]$Title,
    [string]$Description,
    [Microsoft.SharePoint.Client.ListTemplateType]$Template = [Microsoft.SharePoint.Client.ListTemplateType]::GenericList
  )
  $existing = Get-PnPList -Identity $Title -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Skip "List exists: $Title"
    return $existing
  }
  $list = New-PnPList -Title $Title -Template $Template -OnQuickLaunch
  if ($Description) {
    Set-PnPList -Identity $Title -Description $Description | Out-Null
  }
  Write-Ok "Created list: $Title"
  return (Get-PnPList -Identity $Title)
}

function Ensure-Library {
  param(
    [string]$Title,
    [string]$Description
  )
  $existing = Get-PnPList -Identity $Title -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Skip "Library exists: $Title"
    return $existing
  }
  New-PnPList -Title $Title -Template DocumentLibrary -OnQuickLaunch | Out-Null
  if ($Description) {
    Set-PnPList -Identity $Title -Description $Description | Out-Null
  }
  Write-Ok "Created library: $Title"
  return (Get-PnPList -Identity $Title)
}

function Field-Exists {
  param([string]$ListTitle, [string]$InternalName)
  $f = Get-PnPField -List $ListTitle -Identity $InternalName -ErrorAction SilentlyContinue
  return $null -ne $f
}

function Ensure-TextField {
  param(
    [string]$ListTitle,
    [string]$DisplayName,
    [string]$InternalName,
    [switch]$Required,
    [switch]$Multi,
    [int]$MaxLength = 255
  )
  if (Field-Exists -ListTitle $ListTitle -InternalName $InternalName) {
    Write-Skip "$ListTitle.$InternalName"
    return
  }
  if ($Multi) {
    Add-PnPField -List $ListTitle -DisplayName $DisplayName -InternalName $InternalName -Type Note -Required:$Required | Out-Null
  }
  else {
    Add-PnPField -List $ListTitle -DisplayName $DisplayName -InternalName $InternalName -Type Text -Required:$Required | Out-Null
  }
  Write-Ok "$ListTitle.$InternalName ($DisplayName)"
}

function Ensure-NumberField {
  param(
    [string]$ListTitle,
    [string]$DisplayName,
    [string]$InternalName,
    [switch]$Required,
    [switch]$Currency,
    [double]$Min,
    [double]$Max,
    [int]$Decimals = 2
  )
  if (Field-Exists -ListTitle $ListTitle -InternalName $InternalName) {
    Write-Skip "$ListTitle.$InternalName"
    return
  }
  $type = if ($Currency) { "Currency" } else { "Number" }
  Add-PnPField -List $ListTitle -DisplayName $DisplayName -InternalName $InternalName -Type $type -Required:$Required | Out-Null
  # Tighten decimals / min-max via XML when useful
  if ($PSBoundParameters.ContainsKey("Min") -or $PSBoundParameters.ContainsKey("Max") -or $Decimals -ne 2) {
    try {
      $field = Get-PnPField -List $ListTitle -Identity $InternalName
      $schema = $field.SchemaXml
      # best-effort; ignore if Set fails on some tenants
      if ($PSBoundParameters.ContainsKey("Min")) {
        Set-PnPField -List $ListTitle -Identity $InternalName -Values @{ MinimumValue = $Min } -ErrorAction SilentlyContinue
      }
      if ($PSBoundParameters.ContainsKey("Max")) {
        Set-PnPField -List $ListTitle -Identity $InternalName -Values @{ MaximumValue = $Max } -ErrorAction SilentlyContinue
      }
    }
    catch { }
  }
  Write-Ok "$ListTitle.$InternalName ($DisplayName)"
}

function Ensure-ChoiceField {
  param(
    [string]$ListTitle,
    [string]$DisplayName,
    [string]$InternalName,
    [string[]]$Choices,
    [switch]$Required,
    [switch]$Multi,
    [string]$Default
  )
  if (Field-Exists -ListTitle $ListTitle -InternalName $InternalName) {
    Write-Skip "$ListTitle.$InternalName"
    return
  }
  $params = @{
    List         = $ListTitle
    DisplayName  = $DisplayName
    InternalName = $InternalName
    Type         = if ($Multi) { "MultiChoice" } else { "Choice" }
    Choices      = $Choices
    Required     = $Required
  }
  Add-PnPField @params | Out-Null
  # Add-PnPField has no -Default; set the default value after creation.
  if ($Default) {
    try {
      Set-PnPField -List $ListTitle -Identity $InternalName -Values @{ DefaultValue = $Default } -ErrorAction SilentlyContinue | Out-Null
    }
    catch { }
  }
  Write-Ok "$ListTitle.$InternalName ($DisplayName)"
}

function Ensure-YesNoField {
  param(
    [string]$ListTitle,
    [string]$DisplayName,
    [string]$InternalName,
    [switch]$Required,
    [bool]$DefaultValue = $true
  )
  if (Field-Exists -ListTitle $ListTitle -InternalName $InternalName) {
    Write-Skip "$ListTitle.$InternalName"
    return
  }
  Add-PnPField -List $ListTitle -DisplayName $DisplayName -InternalName $InternalName -Type Boolean -Required:$Required | Out-Null
  try {
    Set-PnPField -List $ListTitle -Identity $InternalName -Values @{ DefaultValue = if ($DefaultValue) { "1" } else { "0" } } -ErrorAction SilentlyContinue
  }
  catch { }
  Write-Ok "$ListTitle.$InternalName ($DisplayName)"
}

function Ensure-DateField {
  param(
    [string]$ListTitle,
    [string]$DisplayName,
    [string]$InternalName,
    [switch]$Required,
    [switch]$IncludeTime
  )
  if (Field-Exists -ListTitle $ListTitle -InternalName $InternalName) {
    Write-Skip "$ListTitle.$InternalName"
    return
  }
  $type = if ($IncludeTime) { "DateTime" } else { "DateOnly" }
  # PnP uses DateTime; DateOnly via DisplayFormat
  Add-PnPField -List $ListTitle -DisplayName $DisplayName -InternalName $InternalName -Type DateTime -Required:$Required | Out-Null
  if (-not $IncludeTime) {
    try {
      Set-PnPField -List $ListTitle -Identity $InternalName -Values @{ DisplayFormat = 0 } -ErrorAction SilentlyContinue
    }
    catch {
      # Fallback: update schema DisplayFormat="DateOnly"
      try {
        $f = Get-PnPField -List $ListTitle -Identity $InternalName
        $xml = $f.SchemaXml -replace 'Format="DateTime"', 'Format="DateOnly"'
        if ($xml -notmatch 'Format=') {
          $xml = $xml -replace '/>', ' Format="DateOnly" />'
        }
        Set-PnPField -List $ListTitle -Identity $InternalName -Values @{ SchemaXml = $xml } -ErrorAction SilentlyContinue
      }
      catch { }
    }
  }
  Write-Ok "$ListTitle.$InternalName ($DisplayName)"
}

function Ensure-UrlField {
  param(
    [string]$ListTitle,
    [string]$DisplayName,
    [string]$InternalName,
    [switch]$Required
  )
  if (Field-Exists -ListTitle $ListTitle -InternalName $InternalName) {
    Write-Skip "$ListTitle.$InternalName"
    return
  }
  Add-PnPField -List $ListTitle -DisplayName $DisplayName -InternalName $InternalName -Type URL -Required:$Required | Out-Null
  Write-Ok "$ListTitle.$InternalName ($DisplayName)"
}

function Ensure-LookupField {
  param(
    [string]$ListTitle,
    [string]$DisplayName,
    [string]$InternalName,
    [string]$LookupListTitle,
    [string]$LookupField = "Title",
    [switch]$Required
  )
  if (Field-Exists -ListTitle $ListTitle -InternalName $InternalName) {
    Write-Skip "$ListTitle.$InternalName (lookup → $LookupListTitle)"
    return
  }
  $lookupList = Get-PnPList -Identity $LookupListTitle
  $reqAttr = if ($Required) { 'Required="TRUE"' } else { 'Required="FALSE"' }
  $fieldXml = "<Field Type='Lookup' DisplayName='$DisplayName' Name='$InternalName' StaticName='$InternalName' List='{$($lookupList.Id)}' ShowField='$LookupField' $reqAttr />"
  Add-PnPFieldFromXml -List $ListTitle -FieldXml $fieldXml | Out-Null
  Write-Ok "$ListTitle.$InternalName → $LookupListTitle"
}

function Ensure-View {
  param(
    [string]$ListTitle,
    [string]$ViewTitle,
    [string]$Query,
    [string[]]$Fields,
    [switch]$SetAsDefault
  )
  $existing = Get-PnPView -List $ListTitle -Identity $ViewTitle -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Skip "View $ListTitle / $ViewTitle"
    return
  }
  $params = @{
    List   = $ListTitle
    Title  = $ViewTitle
    Fields = $Fields
  }
  if ($Query) { $params.Query = $Query }
  if ($SetAsDefault) { $params.SetAsDefault = $true }
  Add-PnPView @params | Out-Null
  Write-Ok "View $ListTitle / $ViewTitle"
}

# ── Main ──────────────────────────────────────────────────────────────────────

Ensure-Module
Connect-BillingSite

Write-Step "Creating lists (no lookups yet)"

Ensure-List -Title "Clients" -Description "Master client records, rates, and invoice title templates."
Ensure-List -Title "Projects" -Description "Engagements under a client for time tracking and reporting."
Ensure-List -Title "Invoices" -Description "Invoice instances (manual or from recurring templates)."
Ensure-List -Title "Invoice Lines" -Description "Line items belonging to an invoice."
Ensure-List -Title "Time Entries" -Description "Clockify-style time logs. Used for T&M; not required for fixed retainers."
Ensure-List -Title "Recurring Invoices" -Description "Standing orders: fixed amount, SendMode, schedule."
Ensure-Library -Title "Invoice PDFs" -Description "Generated invoice PDF files. Folder pattern yyyy/MM/{InvoiceNumber}.pdf"

# ── Clients ───────────────────────────────────────────────────────────────────
Write-Step "Fields: Clients"
Ensure-TextField   -ListTitle "Clients" -DisplayName "Client Code"            -InternalName "ClientCode"            -Required
Ensure-TextField   -ListTitle "Clients" -DisplayName "Billing Email"          -InternalName "BillingEmail"          -Required
Ensure-TextField   -ListTitle "Clients" -DisplayName "CC Emails"              -InternalName "CCEmails"              -Multi
Ensure-TextField   -ListTitle "Clients" -DisplayName "Billing Address"        -InternalName "BillingAddress"        -Multi
Ensure-ChoiceField -ListTitle "Clients" -DisplayName "Currency"               -InternalName "Currency"              -Choices @("GBP","USD","EUR") -Required -Default "GBP"
Ensure-NumberField -ListTitle "Clients" -DisplayName "Default Rate"           -InternalName "DefaultRate"           -Currency
Ensure-NumberField -ListTitle "Clients" -DisplayName "Payment Terms Days"     -InternalName "PaymentTermsDays"      -Required -Decimals 0
Ensure-TextField   -ListTitle "Clients" -DisplayName "Invoice Title Template" -InternalName "InvoiceTitleTemplate"  -Required
Ensure-TextField   -ListTitle "Clients" -DisplayName "Invoice Prefix"         -InternalName "InvoicePrefix"
Ensure-ChoiceField -ListTitle "Clients" -DisplayName "Status"                 -InternalName "Status"                -Choices @("Active","Paused","Archived") -Required -Default "Active"
Ensure-TextField   -ListTitle "Clients" -DisplayName "Notes"                  -InternalName "Notes"                 -Multi

# ── Projects ──────────────────────────────────────────────────────────────────
Write-Step "Fields: Projects (non-lookup)"
Ensure-YesNoField  -ListTitle "Projects" -DisplayName "Billable"    -InternalName "Billable"    -Required -DefaultValue $true
Ensure-NumberField -ListTitle "Projects" -DisplayName "Hourly Rate" -InternalName "HourlyRate"  -Currency
Ensure-ChoiceField -ListTitle "Projects" -DisplayName "Status"      -InternalName "Status"      -Choices @("Active","Completed","Archived") -Required -Default "Active"

# ── Invoices ──────────────────────────────────────────────────────────────────
Write-Step "Fields: Invoices (non-lookup)"
Ensure-TextField   -ListTitle "Invoices" -DisplayName "Invoice Number"  -InternalName "InvoiceNumber"  -Required
Ensure-DateField   -ListTitle "Invoices" -DisplayName "Issue Date"      -InternalName "IssueDate"      -Required
Ensure-DateField   -ListTitle "Invoices" -DisplayName "Due Date"        -InternalName "DueDate"        -Required
Ensure-DateField   -ListTitle "Invoices" -DisplayName "Period Start"    -InternalName "PeriodStart"
Ensure-DateField   -ListTitle "Invoices" -DisplayName "Period End"      -InternalName "PeriodEnd"
Ensure-NumberField -ListTitle "Invoices" -DisplayName "Subtotal"        -InternalName "Subtotal"       -Required -Currency
Ensure-NumberField -ListTitle "Invoices" -DisplayName "Tax Rate"        -InternalName "TaxRate"        -Decimals 2
Ensure-NumberField -ListTitle "Invoices" -DisplayName "Tax Amount"      -InternalName "TaxAmount"      -Currency
Ensure-NumberField -ListTitle "Invoices" -DisplayName "Total"           -InternalName "Total"          -Required -Currency
Ensure-ChoiceField -ListTitle "Invoices" -DisplayName "Currency"        -InternalName "Currency"       -Choices @("GBP","USD","EUR") -Required -Default "GBP"
Ensure-ChoiceField -ListTitle "Invoices" -DisplayName "Status"          -InternalName "Status"         -Choices @("Draft","ReadyToSend","Sent","Paid","Void","Failed") -Required -Default "Draft"
Ensure-ChoiceField -ListTitle "Invoices" -DisplayName "Send Mode"       -InternalName "SendMode"       -Choices @("DraftOnly","NotifyOnly","AutoSend")
Ensure-DateField   -ListTitle "Invoices" -DisplayName "Sent At"         -InternalName "SentAt"         -IncludeTime
Ensure-UrlField    -ListTitle "Invoices" -DisplayName "PDF Link"        -InternalName "PDFLink"
Ensure-TextField   -ListTitle "Invoices" -DisplayName "Failure Reason"  -InternalName "FailureReason"  -Multi

# ── Invoice Lines ─────────────────────────────────────────────────────────────
Write-Step "Fields: Invoice Lines (non-lookup)"
Ensure-NumberField -ListTitle "Invoice Lines" -DisplayName "Quantity"   -InternalName "Quantity"   -Required
Ensure-NumberField -ListTitle "Invoice Lines" -DisplayName "Unit Price" -InternalName "UnitPrice"  -Required -Currency
Ensure-NumberField -ListTitle "Invoice Lines" -DisplayName "Amount"     -InternalName "Amount"     -Required -Currency
Ensure-NumberField -ListTitle "Invoice Lines" -DisplayName "Sort Order" -InternalName "SortOrder"  -Decimals 0

# ── Time Entries ──────────────────────────────────────────────────────────────
Write-Step "Fields: Time Entries (non-lookup)"
Ensure-DateField   -ListTitle "Time Entries" -DisplayName "Start"             -InternalName "Start"            -Required -IncludeTime
Ensure-DateField   -ListTitle "Time Entries" -DisplayName "End"               -InternalName "End"              -IncludeTime
Ensure-NumberField -ListTitle "Time Entries" -DisplayName "Duration Minutes"  -InternalName "DurationMinutes"  -Decimals 0
Ensure-YesNoField  -ListTitle "Time Entries" -DisplayName "Billable"          -InternalName "Billable"         -Required -DefaultValue $true
Ensure-NumberField -ListTitle "Time Entries" -DisplayName "Rate"              -InternalName "Rate"             -Currency
Ensure-NumberField -ListTitle "Time Entries" -DisplayName "Amount"            -InternalName "Amount"           -Currency
Ensure-ChoiceField -ListTitle "Time Entries" -DisplayName "Tags"              -InternalName "Tags"             -Choices @("Meeting","Dev","Support","Travel","Admin","Other") -Multi

# ── Recurring Invoices ────────────────────────────────────────────────────────
Write-Step "Fields: Recurring Invoices (non-lookup)"
Ensure-NumberField -ListTitle "Recurring Invoices" -DisplayName "Amount"           -InternalName "Amount"          -Required -Currency
Ensure-ChoiceField -ListTitle "Recurring Invoices" -DisplayName "Currency"         -InternalName "Currency"        -Choices @("GBP","USD","EUR") -Default "GBP"
Ensure-TextField   -ListTitle "Recurring Invoices" -DisplayName "Line Description" -InternalName "LineDescription" -Required
Ensure-ChoiceField -ListTitle "Recurring Invoices" -DisplayName "Cadence"          -InternalName "Cadence"         -Choices @("Monthly") -Required -Default "Monthly"
Ensure-NumberField -ListTitle "Recurring Invoices" -DisplayName "Day of Month"     -InternalName "DayOfMonth"      -Required -Decimals 0 -Min 1 -Max 28
Ensure-ChoiceField -ListTitle "Recurring Invoices" -DisplayName "Send Mode"        -InternalName "SendMode"        -Choices @("DraftOnly","NotifyOnly","AutoSend") -Required -Default "NotifyOnly"
Ensure-DateField   -ListTitle "Recurring Invoices" -DisplayName "Next Run Date"    -InternalName "NextRunDate"     -Required
Ensure-DateField   -ListTitle "Recurring Invoices" -DisplayName "Last Run Date"    -InternalName "LastRunDate"
Ensure-YesNoField  -ListTitle "Recurring Invoices" -DisplayName "Active"           -InternalName "Active"          -Required -DefaultValue $true
Ensure-TextField   -ListTitle "Recurring Invoices" -DisplayName "Notify Email"     -InternalName "NotifyEmail"

# ── Lookups (after all lists exist) ───────────────────────────────────────────
Write-Step "Lookup columns"
Ensure-LookupField -ListTitle "Projects"            -DisplayName "Client"              -InternalName "Client"             -LookupListTitle "Clients"             -Required
Ensure-LookupField -ListTitle "Invoices"            -DisplayName "Client"              -InternalName "Client"             -LookupListTitle "Clients"             -Required
Ensure-LookupField -ListTitle "Invoices"            -DisplayName "Recurring Template"  -InternalName "RecurringTemplate"  -LookupListTitle "Recurring Invoices"
Ensure-LookupField -ListTitle "Invoice Lines"       -DisplayName "Invoice"             -InternalName "Invoice"            -LookupListTitle "Invoices"            -Required
Ensure-LookupField -ListTitle "Invoice Lines"       -DisplayName "Time Entry"          -InternalName "TimeEntry"          -LookupListTitle "Time Entries"
Ensure-LookupField -ListTitle "Time Entries"        -DisplayName "Client"              -InternalName "Client"             -LookupListTitle "Clients"             -Required
Ensure-LookupField -ListTitle "Time Entries"        -DisplayName "Project"             -InternalName "Project"            -LookupListTitle "Projects"
Ensure-LookupField -ListTitle "Time Entries"        -DisplayName "Invoice"             -InternalName "Invoice"            -LookupListTitle "Invoices"
Ensure-LookupField -ListTitle "Recurring Invoices"  -DisplayName "Client"              -InternalName "Client"             -LookupListTitle "Clients"             -Required
Ensure-LookupField -ListTitle "Recurring Invoices"  -DisplayName "Last Invoice"        -InternalName "LastInvoice"        -LookupListTitle "Invoices"

# ── Views ─────────────────────────────────────────────────────────────────────
Write-Step "Views"

Ensure-View -ListTitle "Clients" -ViewTitle "Active Clients" -Query @"
<Where>
  <Eq><FieldRef Name='Status'/><Value Type='Choice'>Active</Value></Eq>
</Where>
<OrderBy><FieldRef Name='Title' Ascending='TRUE'/></OrderBy>
"@ -Fields @("Title","ClientCode","BillingEmail","Currency","DefaultRate","PaymentTermsDays","InvoiceTitleTemplate","Status")

Ensure-View -ListTitle "Projects" -ViewTitle "Active Projects" -Query @"
<Where>
  <Eq><FieldRef Name='Status'/><Value Type='Choice'>Active</Value></Eq>
</Where>
<OrderBy><FieldRef Name='Title' Ascending='TRUE'/></OrderBy>
"@ -Fields @("Title","Client","Billable","HourlyRate","Status")

Ensure-View -ListTitle "Time Entries" -ViewTitle "Unbilled Time" -Query @"
<Where>
  <And>
    <Eq><FieldRef Name='Billable'/><Value Type='Boolean'>1</Value></Eq>
    <IsNull><FieldRef Name='Invoice'/></IsNull>
  </And>
</Where>
<OrderBy><FieldRef Name='Start' Ascending='FALSE'/></OrderBy>
"@ -Fields @("Title","Client","Project","Start","End","DurationMinutes","Rate","Amount","Billable","Tags")

Ensure-View -ListTitle "Time Entries" -ViewTitle "Running" -Query @"
<Where>
  <IsNull><FieldRef Name='End'/></IsNull>
</Where>
<OrderBy><FieldRef Name='Start' Ascending='FALSE'/></OrderBy>
"@ -Fields @("Title","Client","Project","Start","Billable")

Ensure-View -ListTitle "Recurring Invoices" -ViewTitle "Due Recurring" -Query @"
<Where>
  <And>
    <Eq><FieldRef Name='Active'/><Value Type='Boolean'>1</Value></Eq>
    <Leq><FieldRef Name='NextRunDate'/><Value Type='DateTime'><Today/></Value></Leq>
  </And>
</Where>
<OrderBy><FieldRef Name='NextRunDate' Ascending='TRUE'/></OrderBy>
"@ -Fields @("Title","Client","Amount","Currency","DayOfMonth","SendMode","NextRunDate","LastRunDate","Active")

Ensure-View -ListTitle "Recurring Invoices" -ViewTitle "Active Templates" -Query @"
<Where>
  <Eq><FieldRef Name='Active'/><Value Type='Boolean'>1</Value></Eq>
</Where>
<OrderBy><FieldRef Name='Title' Ascending='TRUE'/></OrderBy>
"@ -Fields @("Title","Client","Amount","Cadence","DayOfMonth","SendMode","NextRunDate","Active")

Ensure-View -ListTitle "Invoices" -ViewTitle "Draft Invoices" -Query @"
<Where>
  <Or>
    <Eq><FieldRef Name='Status'/><Value Type='Choice'>Draft</Value></Eq>
    <Eq><FieldRef Name='Status'/><Value Type='Choice'>ReadyToSend</Value></Eq>
  </Or>
</Where>
<OrderBy><FieldRef Name='IssueDate' Ascending='FALSE'/></OrderBy>
"@ -Fields @("Title","InvoiceNumber","Client","IssueDate","DueDate","Total","Currency","Status","SendMode")

Ensure-View -ListTitle "Invoices" -ViewTitle "Sent" -Query @"
<Where>
  <Eq><FieldRef Name='Status'/><Value Type='Choice'>Sent</Value></Eq>
</Where>
<OrderBy><FieldRef Name='SentAt' Ascending='FALSE'/></OrderBy>
"@ -Fields @("Title","InvoiceNumber","Client","IssueDate","DueDate","Total","Currency","Status","SentAt")

Ensure-View -ListTitle "Invoices" -ViewTitle "Overdue" -Query @"
<Where>
  <And>
    <Eq><FieldRef Name='Status'/><Value Type='Choice'>Sent</Value></Eq>
    <Lt><FieldRef Name='DueDate'/><Value Type='DateTime'><Today/></Value></Lt>
  </And>
</Where>
<OrderBy><FieldRef Name='DueDate' Ascending='TRUE'/></OrderBy>
"@ -Fields @("Title","InvoiceNumber","Client","IssueDate","DueDate","Total","Currency","Status")

Ensure-View -ListTitle "Invoices" -ViewTitle "Failed" -Query @"
<Where>
  <Eq><FieldRef Name='Status'/><Value Type='Choice'>Failed</Value></Eq>
</Where>
<OrderBy><FieldRef Name='Modified' Ascending='FALSE'/></OrderBy>
"@ -Fields @("Title","InvoiceNumber","Client","Total","Status","FailureReason","SendMode")

# ── Seed data ─────────────────────────────────────────────────────────────────
if ($SeedSampleData) {
  Write-Step "Seeding sample clients + recurring templates"

  function Get-ItemIdByTitle {
    param([string]$ListTitle, [string]$Title)
    $items = Get-PnPListItem -List $ListTitle -PageSize 500 | Where-Object { $_.FieldValues.Title -eq $Title }
    if ($items) { return $items[0].Id }
    return $null
  }

  $acmeId = Get-ItemIdByTitle -ListTitle "Clients" -Title "Acme Consulting Ltd"
  if (-not $acmeId) {
    $acme = Add-PnPListItem -List "Clients" -Values @{
      Title                 = "Acme Consulting Ltd"
      ClientCode            = "ACME"
      BillingEmail          = "billing@example.com"
      Currency              = "GBP"
      DefaultRate           = 125
      PaymentTermsDays      = 30
      InvoiceTitleTemplate  = "{{ClientName}} — Retainer {{MonthName}} {{Year}}"
      InvoicePrefix         = "INV-ACME"
      Status                = "Active"
      Notes                 = "Sample client — replace BillingEmail before AutoSend."
    }
    $acmeId = $acme.Id
    Write-Ok "Client Acme Consulting Ltd (Id=$acmeId)"
  }
  else {
    Write-Skip "Client Acme Consulting Ltd already exists (Id=$acmeId)"
  }

  $nwtId = Get-ItemIdByTitle -ListTitle "Clients" -Title "Northwind Traders"
  if (-not $nwtId) {
    $nwt = Add-PnPListItem -List "Clients" -Values @{
      Title                 = "Northwind Traders"
      ClientCode            = "NWT"
      BillingEmail          = "ap@example.com"
      Currency              = "GBP"
      DefaultRate           = 95
      PaymentTermsDays      = 14
      InvoiceTitleTemplate  = "{{ClientCode}} Services Invoice · {{MonthShort}} {{Year}}"
      InvoicePrefix         = "INV-NWT"
      Status                = "Active"
      Notes                 = "Sample client — replace BillingEmail before AutoSend."
    }
    $nwtId = $nwt.Id
    Write-Ok "Client Northwind Traders (Id=$nwtId)"
  }
  else {
    Write-Skip "Client Northwind Traders already exists (Id=$nwtId)"
  }

  $tomorrow = (Get-Date).Date.AddDays(1).ToString("yyyy-MM-dd")

  $rec1 = Get-ItemIdByTitle -ListTitle "Recurring Invoices" -Title "Acme monthly retainer"
  if (-not $rec1) {
    Add-PnPListItem -List "Recurring Invoices" -Values @{
      Title            = "Acme monthly retainer"
      Client           = $acmeId
      Amount           = 2500
      Currency         = "GBP"
      LineDescription  = "Monthly retainer — {{MonthName}} {{Year}}"
      Cadence          = "Monthly"
      DayOfMonth       = 1
      SendMode         = "NotifyOnly"
      NextRunDate      = $tomorrow
      Active           = $true
    } | Out-Null
    Write-Ok "Recurring: Acme monthly retainer (NotifyOnly, NextRun=$tomorrow)"
  }
  else {
    Write-Skip "Recurring Acme monthly retainer exists"
  }

  $rec2 = Get-ItemIdByTitle -ListTitle "Recurring Invoices" -Title "Northwind monthly services"
  if (-not $rec2) {
    Add-PnPListItem -List "Recurring Invoices" -Values @{
      Title            = "Northwind monthly services"
      Client           = $nwtId
      Amount           = 1800
      Currency         = "GBP"
      LineDescription  = "Managed services {{MonthName}} {{Year}}"
      Cadence          = "Monthly"
      DayOfMonth       = 1
      SendMode         = "NotifyOnly"
      NextRunDate      = $tomorrow
      Active           = $true
    } | Out-Null
    Write-Ok "Recurring: Northwind monthly services (NotifyOnly, NextRun=$tomorrow)"
  }
  else {
    Write-Skip "Recurring Northwind monthly services exists"
  }
}
else {
  Write-Step "Skipping seed data (pass -SeedSampleData to create sample clients)"
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Step "Summary"
$lists = @("Clients","Projects","Time Entries","Recurring Invoices","Invoices","Invoice Lines","Invoice PDFs")
foreach ($name in $lists) {
  $l = Get-PnPList -Identity $name -ErrorAction SilentlyContinue
  if ($l) {
    $count = (Get-PnPListItem -List $name -PageSize 1 -ScriptBlock { param($items) $items } -ErrorAction SilentlyContinue)
    # ItemCount is cheaper
    Write-Host ("    {0,-22} items={1}" -f $name, $l.ItemCount) -ForegroundColor White
  }
  else {
    Write-Warn "Missing list: $name"
  }
}

Write-Host ""
Write-Host "Provisioning complete." -ForegroundColor Green
Write-Host "Next: open the site, verify views, then Step 3 (Power Automate flows)." -ForegroundColor Green
Write-Host ""
Write-Host "Site: $SiteUrl" -ForegroundColor Cyan
