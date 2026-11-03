# Still Aware web checks

Run every Still Aware scenario from the repository root:

```sh
./run.sh still-aware
```

This runs the Maestro sitemap page flow and the link/download checker. Each
scenario gets a timestamped detailed log under `Still-Aware/logs/`, plus a
timestamped summary listing each scenario's pass/fail result and log path.
It also runs each form-submission flow, which creates test submissions.

## Submit forms

Run the Contact Us test submission by itself:

```sh
./run.sh still-aware flows/submit_contact_form.yaml
```

Run the volunteer or internship test application by itself:

```sh
./run.sh still-aware flows/submit_volunteer_application.yaml
./run.sh still-aware flows/submit_internship_application.yaml
```

The flow sends a clearly labeled QA-only message to the Contact Us form and
verifies that the form resets after submission. Each run creates another
submission in the configured environment (and may notify the contact team).
The volunteer and internship flows likewise create clearly labeled QA-only
application records in the isolated test environment. The internship flow
checks the required WIL checkbox, which the test applicant must truthfully
meet. After submission, both flows verify that the dialog closes rather than
relying on the brief confirmation toast.
The site currently has no other active, non-transactional form suitable for
automated test data. Donation and newsletter forms are excluded, as is the
Christmas Wreath form because its entries may be published as memorial
tributes.

Run only the browser page flow:

```sh
./run.sh still-aware flows/check_all_pages.yaml
```

The page flow checks the 36 internal URLs currently listed in the site's sitemap
at `https://stillaware.itmanage.com.au/sitemap.xml`. Update the URL list and
expected page headings in `flows/check_all_pages.yaml` when the sitemap
changes. The check navigates pages and verifies visible content; it does not
submit donations, newsletter subscriptions, or other forms. Maestro web
automation uses Chromium and is currently beta.

## Check links and downloads

Run only the link/download scenario from the repository root:

```sh
./run.sh still-aware links
```

It reads the sitemap, visits every listed page, collects unique HTTP(S) links,
follows redirects, and checks download responses using a small byte-range
request. PDF and ZIP downloads are also checked for their file signatures.
The detailed scenario log records each link's result. The checker does not save
files or click transaction links. `mailto:`, `tel:`, and Cloudflare-protected
email links are skipped.

The checker exits nonzero for broken links or links it could not verify.
Some external sites block automated requests (for example with HTTP 403 or
429); these are reported as **unverified**, not as confirmed broken links.

The `/qa-test-sa-800` sitemap route currently renders the shared site shell
without main-page content. Its check therefore verifies the shared `Quick
Links` footer only; replace this with a page-specific assertion if that route
is populated.
