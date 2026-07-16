# Step 1 checklist — GitHub repo + architecture pack

**Goal:** Empty private GitHub repo exists; architecture pack is committed and readable on github.com.

## You do

### 1. Create repo

1. Go to https://github.com/new  
2. Name: `billing-platform` (or your preference)  
3. Private  
4. **No** auto-generated README / gitignore / license  
5. Create repository  

### 2. Get the files

You need the local folder that contains:

- `README.md` (repo root)
- `docs/` (full tree)

These were generated in this project. Options:

**Option A — Download from this sandbox**  
Copy/export the `README.md` and `docs/` folder to your machine.

**Option B — Recreate by copy-paste**  
If download is awkward, create files locally and paste contents from this project’s `README.md` and `docs/*`.

### 3. Push

```bash
cd /path/to/billing-platform   # folder containing README.md and docs/
git init
git add README.md docs/
git commit -m "docs: add architecture pack (SharePoint, flows, title templates)"
git branch -M main
git remote add origin https://github.com/<YOUR_USERNAME>/<REPO_NAME>.git
git push -u origin main
```

If GitHub shows HTTPS instructions with a different URL (SSH), use that instead.

### 4. Self-check (before you ping me)

Open the repo in the browser and verify:

- [ ] README hero text mentions Clockify replacement + AutoSend + title templates  
- [ ] Link to `docs/architecture.md` works  
- [ ] Link to `docs/sharepoint-schema.md` works  
- [ ] `docs/flows/01-recurring-scheduler.md` opens  
- [ ] `docs/title-templates.md` shows `{{MonthName}}` / `{{Year}}`  
- [ ] Repo is **Private**  

### 5. Reply in chat

Message exactly when ready:

```
Step 1 complete
Repo: https://github.com/<user>/<repo>
```

I will **double-check** the checklist with you (and spot-check structure if you paste the file tree). Then we start **Step 2 — PnP.PowerShell provisioning**.

## I will not do in Step 1

- Create the GitHub repo for you (needs your account)  
- Provision SharePoint (Step 2)  
- Build Power Automate flows (Step 3)
