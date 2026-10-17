# Bank Reconciliation App (Salesforce)

**English** · [한국어](README.ko.md)

> A Salesforce app for a task every bank operations team does daily: **checking that the books match the real bank account.**
> I designed it from two years of doing this work by hand in a foreign bank's operations team.

This is my Day3 mini project for the Salesforce101 course (SeSAC Salesforce S.T.A.Track, cohort 3). The same repository also holds the Day1–2 exercises. All companies, people and amounts in the app are fictional.

## The problem

Every day a bank checks that the **balance in its system ledger** equals the **balance in the actual bank account**. The account only shows how much money there is; only the ledger knows whose money it is. If the two differ, customer balances, payments and reports to head office are all wrong.

The old way:

1. An Excel macro pairs up matching transactions.
2. The leftover transactions are **printed and ticked off by hand**.
3. If anything still doesn't match, someone **writes an email to every department**.

After a few days it becomes hard to tell what is still open, who should fix it, and when it was closed.

## What the app does

| Before | With this app |
| --- | --- |
| Open items scattered across emails and printouts | Only the mismatched transactions go into one list, with **days open** and an **urgency flag** shown automatically |
| A person decides when the day is done | When the difference is **0** and **no items remain**, the day is marked **"Done" automatically** |
| The report email is written by hand every time | The report text and the **team lead to report to** are drafted automatically |
| No record of who changed what | Every change is logged, and **closed records are locked** |
| Anyone can see the data | **Only the operations team** can see it (other teams just get the report email) |

## How it is used

```
① Pair transactions in Excel (unchanged)
② Enter today's balances in the app ──────► difference 0 + no open items → Done
③ Log each mismatched transaction
④ Report text is drafted → emailed to other teams
⑤ The other team fixes it in their own system → tells operations
⑥ Operations ticks "Resolved" + corrects the balance → back to the check in ②
```

Example: on Oct 15 the corporate client account held **₩300,000 more** than the ledger → cause: "Greencell Bio's ₩300,000 deposit was not posted to the ledger by the finance team" → finance posts it, operations marks it resolved → difference 0 → **Done**

## What I verified

- **13 automated tests** pass (status logic, team-based access, record locking)
- Checked in the real UI: trying to change the balance of a closed day is blocked with the message "완료된 대조는 … 고칠 수 없습니다" ("a completed reconciliation can't be edited")

## Technical overview (for Salesforce readers)

| Area | Details |
| --- | --- |
| Data model | One Daily Reconciliation (`Daily_Recon__c`) has many Reconciliation Items (`Recon_Item__c`) (Master-Detail). Difference, days open and urgency are formulas; open-item count is a roll-up |
| Automation | Record-triggered Flow (status decision, report text), Screen Flow (entry wizard) |
| UI | Home summary card (LWC + Apex), two report charts |
| Security | Permission sets + private sharing (OWD Private) + a sharing rule so only operations can access; four validation rules lock closed records; field history tracking |
| Tests | 13 Apex tests |

More detail: [README-bank-recon.md](README-bank-recon.md) · Presentation (Korean): [docs/presentation](docs/presentation/bank-recon-presentation.pdf)

## Day1–2 exercises (same repository)

| Exercise | What it covers |
| --- | --- |
| Employees | A shared employee record used by several apps (the reconciliation app reuses it) |
| Game marketing performance | Campaign results and a quick-entry screen |
| Luxury client consultations | Automatically escalating consultations based on customer tier |
| B2B AI projects | Screens and reports for managing companies' AI adoption projects |

## Folders

| Path | Contents |
| --- | --- |
| `force-app/main/default` | The files that make up the apps (data model, automation, screens, permissions) |
| `docs/` | Presentation, architecture and flow diagrams |
| `data/` | Sample data |

To deploy to a Salesforce org:

```bash
sf project deploy start --target-org <org alias> --source-dir force-app
```
