# Foundry Routines

Manage Microsoft Foundry Routines from your terminal. (Preview)

## Extension telemetry API

Extension code can report best-effort usage events through the shared
`pkg/foundry/telemetry` package:

```go
reporter := telemetry.NewReporter(azdClient.Telemetry(), nil)
reporter.Report(ctx, telemetry.Event{
  Name: "routine.operation.completed",
  Attributes: map[string]string{
    "operation": "dispatch",
  },
})
```

The example is illustrative; this extension does not currently emit a product
usage event. Add an event only after its product question, bounded values,
documentation, and privacy review are agreed. Before emitting, declare each
`ext.*` attribute in `cli/azd/extensions/telemetry/fields.go` — reuse an existing
declaration only when its meaning, allowed values, classification, and purpose are
identical, otherwise declare a distinct key — as enforced by
`go test ./extensions/telemetry`.

`Report` has no return value and never changes command or service-target
behavior. It uses a one-second timeout, does not retry, and does not log
attribute values or transport error details. Put approved event builders and
finite-value types in `internal/telemetry/events.go`; do not call `ReportUsage`
directly. Never include routine names, definitions, schedules, inputs, outputs,
IDs, endpoints, paths, URLs, or other customer content. The azd host records
events only for extensions installed from the official registry.

## Add a routine to azure.yaml

Use `routine add` to declare a local YAML or JSON routine manifest in the
current project's `azure.yaml`. The command only updates local project
configuration; run `azd deploy <name>` or `azd up` to create or update the
routine in Microsoft Foundry.

```bash
azd ai routine add nightly-summary --file ./routines/nightly-summary.yaml
azd deploy nightly-summary
```

The manifest must be inside the azd project. The command writes a portable
`$ref`, produces the same declaration when repeated, and adds `uses:` when the
manifest invokes an `azure.ai.agent` service in the same project. Existing
service fields not owned by the routines extension are preserved. Convert or
remove an inline routine service before replacing it with a file-backed
declaration.

## Reference a routine manifest

An `azure.ai.routine` service can load its routine definition from a local YAML
or JSON file. Properties beside `$ref` override values from the referenced file.

```yaml
services:
  nightly-summary:
    host: azure.ai.routine
    $ref: ./routines/nightly-summary.yaml
    enabled: false
```

References are resolved during `azd deploy`. Remote URLs are not supported.

## Choose a dispatch identity

Routines dispatch as the target agent identity by default. Use creator identity when the invoked
agent needs delegated access from the person who creates the routine:

```bash
azd ai routine create morning-briefing \
  --trigger recurring \
  --cron "0 8 * * *" \
  --time-zone America/Los_Angeles \
  --action agent-response \
  --agent-name personal-productivity \
  --dispatch-identity creator
```

The same setting is supported in YAML and JSON manifests and in inline or file-backed
`host: azure.ai.routine` services:

```yaml
authorization:
  identity: creator
```

Dispatch identity is applied only when the service creates the routine. Updates preserve the
existing identity, even when an update request includes `authorization`. Delete and recreate the
routine to change its dispatch identity.

## Timeout configuration

Routine read API calls default to a 30-second HTTP request timeout.
Routine write API calls default to a two-minute timeout to allow cold
recurring routine creates to finish AgentIdentity binding. Override both
defaults with the root `--timeout` flag, using Go duration syntax:

```bash
azd ai routine --timeout 3m create my-routine ...
```

Set `AZURE_AI_ROUTINES_HTTP_TIMEOUT` to apply the same override when
the extension runs without command flags, such as during `azd deploy`
service target upserts. The `--timeout` flag wins when both are
provided.
