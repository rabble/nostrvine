# Diagnostic Data Policy

This policy covers user-initiated bug reports and support flows that collect
mobile diagnostics.

## Public Support Flows

Bug reports and feature requests submitted through Zendesk may be mirrored into
public GitHub issues. Treat every field sent through that path as public.

Public bug-report payloads may include:

- User-entered subject, description, reproduction steps, and expected behavior.
- App version and coarse platform/device details needed for triage.
- Error counts.
- A bounded summary of recent logs.
- The signed-in public Nostr account identifier when support needs to connect
  the report to an account.

Public bug-report payloads must not include:

- Nostr private keys, bearer tokens, passwords, or secret values.
- Email addresses collected incidentally from logs or typed fields.
- Device names, host names, or computer names.
- Full raw log archives or unbounded diagnostic dumps.

The mobile client enforces this by sanitizing diagnostics before they leave
`BugReportService` and by sanitizing each user-entered Zendesk field before
submission.

## Private Support Channels

Private channels, including encrypted support DMs and user-exported logs, may
carry fuller diagnostic context when the user explicitly triggers the flow. They
still must apply the same secret redaction rules before transmission or export.

Do not upload full user diagnostic logs to public content-addressed blob storage
for public Zendesk/GitHub support flows. If support needs full logs, use a
private store with access controls, retention limits, and an owner for deletion
requests before adding that collection path.

## Open Decisions

Two policy details need product and support-owner confirmation before broadening
the implementation:

- Whether public GitHub issues should continue to include the signed-in Nostr
  public key, or whether Zendesk-only private metadata is enough for support.
- Which private log store, retention period, and access controls apply if
  support needs full diagnostic archives beyond the bounded public summary.
