---
name: legislation-audit
description: "Check a calculation, rate, threshold or rule in the code against the primary legislation it claims to implement — South African tax, estate and financial-services law. Reads the Act itself rather than commentary, and records the section and effective date so the finding can be re-checked next year. Triggers: 'legislative audit', 'check this against the Act', 'verify the legislation', 'is this still current', 'what does the Act actually say', 'audit the tax rates', 'check s4A', 'confirm the abatement', 'which section authorises this'."
compatibility: claude-code-only
---

# Legislative audit

Verify that what the code does is what the law says. The output is a finding tied to a
section number, a source, and an effective date — not a paraphrase of somebody's blog.

The failure this exists to prevent: an agent searches, finds a law firm's summary,
believes it, and writes the conclusion into a client-facing document. A summary is a
starting point for finding the section. It is never the citation.

## The rule

**Quote the Act. Cite the section. Record the date.**

Commentary — SARS guides, law-firm notes, textbooks — is for orientation: it tells you
*which* section to read. Then read that section. Where the two disagree, the Act wins
and the disagreement is itself worth reporting.

Do not reproduce commentary at length; it is somebody's copyrighted work. Quote the
operative words of the statute you are relying on, which is ordinary legal practice,
and link the rest.

## Cost discipline — work down this ladder

Each rung costs more than the one above it. Do not start at the bottom.

| Rung | Tool | Cost | Use it for |
|------|------|------|-----------|
| 1 | Already-known source in the repo (`docs/`, spec comments, a pinned tax-year config) | free | Finding what the code *claims*, before checking it |
| 2 | Built-in `WebSearch` | free | Finding which Act and section governs. **US-biased** — expect thin results for `gov.za`, and use `allowed_domains` to force them |
| 3 | Built-in `WebFetch` | free | Reading an HTML page. **Cannot read PDFs** — it returns unparseable binary, which is exactly how a previous audit failed three times |
| 4 | `curl` + `pdftotext` (below) | free | Reading the actual Act. This is where the citation comes from |
| 5 | Tavily MCP (`mcp__tavily__*`) | 1 credit/search, 1,000 free per month | A site that blocks WebFetch (403), or a search where the US bias is hiding the SA source |

Tavily's budget is a shared monthly pool. Spend it on the two things it is uniquely good
at — server-side extraction past a block, and non-US-weighted search — not on queries
rung 2 would have answered.

## Reading a PDF (rung 4)

Most South African legislation is published as PDF. Both steps are free and neither
sends the document anywhere.

```bash
curl -sL "<url>" -o /tmp/act.pdf && file /tmp/act.pdf     # confirm it IS a PDF
pdftotext -layout /tmp/act.pdf /tmp/act.txt && wc -l /tmp/act.txt
```

`-layout` preserves the column structure, which matters: rate tables and the schedules
to a tax Act are unreadable without it.

Then `Grep` the text for the section — `grep -n "4A" /tmp/act.txt` — and `Read` around
the hit. Quote from `/tmp/act.txt`, so the quotation is the Act's own words rather than
your reading of a picture.

**If `pdftotext` returns almost nothing**, the PDF is a scan with no text layer:

```bash
pdftoppm -png -r 150 -f <first> -l <last> /tmp/act.pdf /tmp/act-page
```

Then `Read` the PNGs. Slower, and you are transcribing rather than quoting — say so in
the finding.

## Where to look

Prefer the department that administers the Act; it publishes the consolidated current
text, and consolidated is what you want — an Act as originally enacted is usually wrong
by now.

| Subject | Source |
|---------|--------|
| Estate Duty Act, Income Tax Act, VAT Act — consolidated and current | `sars.gov.za`, under Legal Counsel |
| SARS interpretation notes, binding rulings, guides | `sars.gov.za` |
| Rate and threshold changes for the coming year | `treasury.gov.za` — Budget Review and the Rates and Monetary Amounts Act |
| Acts as gazetted, and amendment Acts | `gov.za` |
| Administration of Estates Act, Master's fees, executor tariff | `justice.gov.za` |
| Case law, and legislation as a cross-check | `saflii.org` |
| Financial advice, FAIS, product regulation | `fsca.co.za` |
| Matrimonial Property Act, accrual | `gov.za`, `saflii.org` |
| Consumer price index for accrual adjustment | `statssa.gov.za` |

With built-in `WebSearch`, force the domain rather than hoping:
`WebSearch(query: "Estate Duty Act section 4A consolidated", allowed_domains: ["sars.gov.za"])`.

## Three questions, in order

Answering only the first is the commonest way to get this wrong.

**1. What does the section say?**
The operative words. Watch for a proviso, a deeming provision, and a cross-reference to
another subsection — the qualification is usually where the money is.

**2. Is this version in force, and on what date?**
Find the amending Act, and whether the amendment is in operation or merely enacted.
Rates change every Budget. A threshold that was right last year is a defect this year,
and it will not announce itself.

**3. Does the code do that?**
Read the implementation and compare. Name the file and line. A test that asserts the
old behaviour is part of the defect, not evidence against it.

## Reporting a finding

One finding per section checked. Each carries enough that somebody can re-run it next
year without repeating the search:

- **Section** — Act, section, subsection.
- **What it says** — the operative words, quoted.
- **Source** — the URL, and whether it was consolidated text or as-enacted.
- **In force** — effective date, and the amending Act if the wording moved recently.
- **What the code does** — `file:line`, and the figure or rule it applies.
- **Verdict** — agrees / disagrees / the Act is silent and the code is making a choice.

The third verdict matters most. Where the Act does not settle the question, the code is
exercising judgement, and that judgement belongs to the adviser — surface it as a
decision for them, not as a bug.

## When you cannot get to primary text

Say so plainly, in the finding and in any document the finding reaches. A conclusion
resting on search snippets is a conclusion resting on search snippets, and a reader who
is told that can weigh it. A reader who is not told will assume you read the Act.

Do not paper over the gap by citing the section number you saw quoted in a summary — that
is a citation to something you have not read.
