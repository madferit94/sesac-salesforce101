# Bank Operations Reconciliation App

**English** · [한국어](README-bank-recon.ko.md)

> Salesforce101 Day3 mini project. The bank, clients, people and amounts are all fictional. The app's screens are in Korean; English names are given in brackets below.

## Purpose

The app is used by **a bank operations team member**. It handles **one day's comparison of the system balance against the bank account balance**, and shows whether **the difference has reached 0** or **a report is needed**.

In a foreign bank's operations team, transactions were paired in Excel, the leftovers were crossed off by hand on a printout of system records, and if the balances still differed, a consolidated email went to every department. This app keeps the pairing in Excel and moves **the open items, the balance difference and the report history** into Salesforce.

### Why must the difference be 0?

The money in the account and the bank's ledger must agree; that is the proof that every client's money is recorded in the ledger.

The most common mismatch, **"not posted to the system"**, means the money has arrived in the bank account (the Parent account) but has not yet been recorded in the ledger under that client. Practice record DR-0007 is an example.

| Step | Account balance | System balance | Difference |
|---|---|---|---|
| Greencell Bio deposits ₩300,000; not posted | ₩100,300,000 | ₩100,000,000 | +₩300,000 |
| Doyun (finance) posts the ₩300,000 | ₩100,300,000 | ₩100,300,000 | ₩0 |

While the item is unposted, the ledger shows Greencell Bio ₩300,000 short, and the client cannot see the deposit. Even a small difference can be two large mistakes cancelling out, so every line is explained until the difference is 0.

## Components

![Overall structure of the reconciliation app](docs/screens/00-architecture.svg)

| Type | Name (API) | Role |
|---|---|---|
| App | 입출금 대조 [Reconciliation] (`Bank_Recon`) | Tabs: Home · Daily Reconciliation · Reconciliation Items · Account · Employee |
| Home page | 입출금 대조 홈 (`Bank_Recon_Home`) | Summary card (LWC `reconDashboard`) + two report charts (share by status, open items by date) + usage guide |
| Reports | Folder "입출금 대조 리포트": by status (`Daily_Recon_By_Status`), open items by date (`Open_Items_By_Date`) | Source of the home charts; clicking a chart opens the report |
| New object | Daily Reconciliation (`Daily_Recon__c`) | One record per day × account. System balance, account balance, difference (formula), open-item count (roll-up), status, report text, urgency (formula: 🔴 if an open item is agency payment funds or is 3+ days old) |
| New object | Reconciliation Item (`Recon_Item__c`) | One amount left unticked on the printout. Master-Detail to Daily Reconciliation. Transaction type, deposit purpose, cause, handler, resolved, days open (formula), urgency (formula: 🔴 urgent = unresolved and agency payment funds or 3+ days open / 🟡 normal / 🟢 resolved) |
| Existing object | Account | Counterparty company or bank (`Counterparty_Type__c`: company / bank) |
| Existing object | Employee (`Employee__c`) | Reconciler, handler, team lead (manager). Added "Finance" to the industry list |
| Report-to (formula) | `Report_Manager__c`, `Report_Department__c` | Shows the handler's team lead and department on every record |
| Automation | Flow: daily status decision (`Daily_Recon_Status`) | On save, decides the status and drafts the report text |
| Entry screen | Screen Flow: entry wizard (`Recon_Entry_Wizard`) | Create a new reconciliation or continue an open one → balances → log mismatches → result (home page, visible to operations only) |
| Permissions | Permission set: Reconciliation User (`Bank_Recon_User`) | Read/create/edit both objects (no delete), read Account and Employee, app/tab/wizard access. See "Users and permissions" below |

There are two accounts: **Checking (bank operating account)**: futures trades, the bank's own transfers, giro · **Parent (corporate client master account)**: deposits and withdrawals of corporate clients and other banks.

### Status rules (Flow)

| Condition | Status | What else happens |
|---|---|---|
| Account or system balance is empty | In progress | Missing-information case |
| Difference 0, no open items | Done | Earlier report text is kept as history |
| Anything else | Report needed | Report text drafted (team lead to report to, and "→ report to: Finance lead Taeo" per item); first report time recorded |

Resolving, adding or deleting an item changes the open-item roll-up, so the day is re-evaluated automatically.

## Demo steps

1. App Launcher → **입출금 대조** → **Daily Reconciliation** tab → list view **확인 필요** (needs review)
2. Open **DR-0005** (Oct 14, Parent): difference +₩4,990,000, 2 open items, status **Report needed**; check the drafted report text
3. In item **RI-0007** (Hanbyeol Trading deposit not posted) enter a resolution note and tick Resolved → the report shrinks to one line (saving without a note is blocked)
4. Do the same for **RI-0008** (₩10,000 fee) → correct DR-0005's system balance to **2,244,990,000** → status **Done**

To repeat the demo, **first** untick Resolved on RI-0007 and RI-0008 (the status returns to Report needed), then set DR-0005's system balance back to **2,240,000,000**. The order matters because a Done record's balances are locked.

## Sample data

| Data | Count | Where to see it |
|---|---|---|
| Daily Reconciliation | 7 (DR-0001–0007) | Daily Reconciliation tab → list views "전체" (all), "확인 필요" (needs review) |
| Reconciliation Item | 9 (RI-0001–0009) | Reconciliation Items tab → "전체", "미해결 항목" (open items, sorted by days open) |
| Counterparty accounts | 5 | Hanbyeol Trading, Bluewave Logistics, Greencell Bio, Aurora Electronic Parts, Hangang Bank |
| Employees | 6 | Jiwoo (reconciler) → operations lead Harin · Doyun (finance, posts to system) → finance lead Taeo · Seoa (corporate banking) → corporate banking lead Yujin |

| Record | Situation | Status |
|---|---|---|
| DR-0001 · Oct 12 Checking | Everything matches | Done |
| DR-0002 · Oct 12 Parent | Depositor name "(주)한별" vs "한별물산" confirmed as the same, resolved | Done |
| DR-0003 · Oct 13 Checking | Giro deposit not posted | Report needed |
| DR-0004 · Oct 13 Parent | Two deposits not posted + duplicate Hangang Bank transfer | Report needed |
| DR-0005 · Oct 14 Parent | Hanbyeol not posted + Bluewave fee deducted (demo) | Report needed |
| DR-0006 · Oct 14 Checking | Account balance not entered (missing-information case) | In progress |
| DR-0007 · Oct 15 Parent | Greencell Bio ₩300,000 not posted → posted by finance, resolved (practice) | Done |

Source: under `force-app/main/default/`: `applications/Bank_Recon.app-meta.xml`, `objects/Daily_Recon__c/`, `objects/Recon_Item__c/`, `flows/`, `flexipages/Bank_Recon_Home.flexipage-meta.xml`, `lwc/reconDashboard/`, `classes/`, `permissionsets/`, `roles/`, `sharingRules/`, `reports/`

## Users and permissions (security)

Principle: **only the operations team does reconciliation.** Other teams never enter the app; they receive the drafted report by email, fix the issue in their own system and tell operations. This matches how the work was actually done.

### Access by team

```
Branch manager
├─ Operations lead (Harin) ─ Operations (Jiwoo)          ← has access (public group "입출금 대조 접근 부서")
├─ Finance lead (Taeo) ─ Finance (Doyun)                 ┐
├─ Corporate banking lead (Yujin) ─ Corp. banking (Seoa) │
├─ IT (Junho)                                            ├ no access (report email only)
├─ HR (Soyeon)                                           │
└─ Task force (Hyunwoo)                                  ┘
```

| Team | Reconciliations visible (of 7) | App and reports |
|---|---|---|
| Operations (Harin, Jiwoo) | 7 | Visible |
| Finance, corporate banking, IT, HR, task force | **0** | Hidden |

Access is blocked in two layers.
1. **Permission sets = what you can do**: the app permission set "Reconciliation User" is given only to operations (Jiwoo, Harin) and the owner.
2. **Sharing = which records you can see**: the Daily Reconciliation default access (OWD) is **Private**, and the sharing rule **"운영팀에 공유" (share with operations)** opens it to the operations group only. Items follow their parent. The report folder is shared with the same group.

So even if another team is given the permission set by mistake, they see 0 records.

### Users

| User | Role | Profile | Permission set | Can do |
|---|---|---|---|---|
| Owner | Primary admin | System Administrator | Reconciliation User | Everything |
| Harin | Operations lead (backup admin) | System Administrator | Reconciliation User | Everything |
| Jiwoo | Operations reconciler | Standard Platform User | Reconciliation User | Create reconciliations and items, enter balances, resolve, wizard (no delete) |
| Doyun, Seoa, Taeo, Yujin | Handlers / team leads | Standard Platform User | None | No access; **only their names are recorded** as handler or report-to |
| Junho, Soyeon, Hyunwoo | IT · HR · task force | Force.com - Free User | None | No access |

- **No deletion**: reconciliation records are audit evidence, so only admins can delete them.
- **Wizard visibility**: the entry wizard on the home page is shown only to users with the custom permission `대조 입력` (Recon_Entry).
- The permission sets "Reconciliation Handler" and "Reconciliation Lead (read-only)" are not assigned to anyone yet; they are for splitting roles inside operations later.
- **Automated check**: the Apex test class `ReconSecurityTest` (4 tests) confirms edits and deletes are blocked by role, and that finance and IT see 0 records even with the permission set.
- All login users use the owner's email address; no password emails were sent.

## Record protection (audit evidence)

A reconciliation record later proves "what didn't match that day, and who fixed it how". So every change leaves a trace, and closed records are locked.

**Change history**: when the fields below change, "who / when / old value → new value" is logged automatically in the **change history** list on the record.

| Object | Tracked fields |
|---|---|
| Daily Reconciliation (7) | Date, account, system balance, account balance, status, reconciler, report time |
| Reconciliation Item (11) | Side, amount, direction, transaction type, deposit purpose, counterparty, depositor name, cause, handler, resolution note, resolved |

**Four validation rules**

| Rule | Blocks | Why |
|---|---|---|
| Resolution note required | Ticking Resolved without a note | Items must not disappear without a reason |
| Lock completed day | Editing date, account or balances of a Done record | Numbers of a closed day must not change later |
| No new items on a completed day | Adding an item to a Done record | A closed day's result must not change quietly |
| Lock resolved item | Editing amount, side or direction of a resolved item | Resolved must be unticked first, and that is logged |

- **Override permission** `대조 수정 예외` (Recon_Override): users with it can bypass the rules above. It is **assigned to no one** by default; an admin grants it briefly only when a fix is truly needed, and the fix is logged.
- **Automated check**: the Apex test class `ReconRecordProtectionTest` (5 tests) checks the rules and that history tracking is on.

## Known limits and next steps

- Pairing still happens in Excel; only open items are entered in the app.
- Report emails are not actually sent; the report text is kept on the record.
- Changing only an item's cause or handler does not update the report text immediately; saving the Daily Reconciliation once refreshes it.
- A user could fix the balance to make the difference 0 and then resolve the items without real postings. A required reason for balance changes and a check that open items add up to the difference are needed.
- Next: CSV import of the Excel result, automatic pairing of same-date/same-amount transactions, urgent-item alerts and real email, preventing duplicate days for the same account.

## Screenshots

Screenshots 1–4 are in preparation; only the flow diagram is included for now.

| # | Screen | File |
|---|---|---|
| 1 | Daily Reconciliation list view "확인 필요" | `docs/screens/01-list-needs-report.png` |
| 2 | DR-0005 detail: report needed + report text + item list | `docs/screens/02-dr0005-report.png` |
| 3 | RI-0007 resolved | `docs/screens/03-ri0007-resolved.png` |
| 4 | DR-0005 done | `docs/screens/04-dr0005-done.png` |
| 5 | Flow diagram: daily status decision | `docs/screens/05-flow-daily-recon-status.svg` |

![Flow: daily status decision](docs/screens/05-flow-daily-recon-status.svg)
