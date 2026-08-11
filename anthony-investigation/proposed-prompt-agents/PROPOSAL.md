# Proposed azd support for Foundry prompt agents

## Status

Design draft for discussion. No implementation is included.

Decisions already made:

- Keep deployed-agent instructions inline in `agent.yaml`; do not use
  `AGENTS.md` or an implicit `instructions.md` sidecar.
- Both runtime flavors use `kind: prompt`.
- A standard Foundry prompt agent omits `harness`, matching the service API.
- A GitHub Copilot harness agent sets `harness: ghcp`.
- `azd ai agent init` must let the user select the prompt-agent harness.

## Terminology

This document uses the following terms consistently:

| Term | Meaning |
| --- | --- |
| **azd project** | The local source/configuration unit rooted at `azure.yaml`. In azd code this is a `ProjectConfig`. One azd project can contain many services and deploy to many azd environments. |
| **azd environment** | A named deployment instance of an azd project, such as `dev` or `prod`. It stores environment-specific values under `.azure/<environment>/`. |
| **Foundry project** | The Azure cloud resource under a Foundry account (`Microsoft.CognitiveServices/accounts/projects`) that contains agents, connections, toolboxes, and related assets. |
| **Foundry project service** | The `azure.yaml` service declaration with `host: azure.ai.project`. It is source configuration that tells azd to create or bind to a Foundry project; it is not itself the Azure resource. |
| **Agent service** | An `azure.yaml` service declaration with `host: azure.ai.agent`. It represents one deployable agent in the azd project. |
| **Service source path** | The local folder configured by a service's unfortunately named `project:` YAML property. For example, `project: ./agents/support` points to source files; it does not identify either an azd project or a Foundry project. |
| **Primary toolbox** | The single toolbox through which a prompt agent receives all authored tools, skills, generated knowledge tools, and referenced toolbox endpoints. Who owns its lifecycle is still TBD. |

Bare **project** is avoided below when more than one meaning is possible.

## Hosted-agent compatibility boundary

The required prompt-agent implementation does **not** change the GA hosted-agent
contract. Existing azd projects containing hosted agents keep their current:

- Inline agent definition in `azure.yaml`.
- Init prompts and generated files.
- Container and source-code package/publish paths.
- Foundry hosted-agent API payloads and version lifecycle.
- Protocol endpoints, sessions, and environment variables.
- Targeted `azd deploy <service>` behavior.

Prompt agents reuse the same outer azd architecture -- one agent service per
agent, a shared Foundry project service (`host: azure.ai.project`), `uses:`
ordering, and the package/provision/deploy graph -- without requiring the inner
hosted-agent definition or runtime path to change.

Some recommendations later in this document improve shared azd core and Foundry
project provisioning and therefore benefit hosted agents too. They are additive
and must preserve existing hosted behavior. The final section lists optional
hosted cleanups separately; none block prompt-agent support.

## Goals

1. An azd project can be cloned and deployed into another subscription or an
  existing Foundry project without editing tracked resource identifiers.
2. One azd project can contain one or many prompt and hosted agents.
3. Agents can share models, connections, skill sources, tool definitions,
  toolboxes, and knowledge.
4. An azd project can provision ordinary Azure resources alongside Foundry.
5. Interactive and `--no-prompt` CI/CD flows use the same source files.
6. Prompt-agent behavior is consistent with hosted-agent service topology and
   azd lifecycle semantics.
7. Deploy never silently rewrites tracked source files.

## Non-goals

- Treating a prompt agent as a container or source-code service.
- Encoding subscription, resource-group, workspace, endpoint, or secret values
  in a portable template.
- Pretending a declared function tool has an executor when none exists.
- Making all tools available on both harnesses when the platform does not.

## Recommended source-of-truth boundaries

| Source | Owns | Must not own |
| --- | --- | --- |
| `azure.yaml` | Service topology, shared resources, provisioning declarations, `uses:` edges | Resolved Azure IDs, endpoints, secrets, generated agent versions |
| `agents/<name>/agent.yaml` | Portable **prompt-agent** version definition: kind, optional GHCP harness, model, inline instructions, toolbox inputs, policies, metadata, and behavior options | Subscription, resource group, workspace, Foundry project endpoint, secrets |
| Agent-local folders | Private knowledge and private skills owned by one agent | Shared resources consumed by several agents |
| `shared/` | Source for explicitly shared skills, tool definitions, toolboxes, and knowledge services | Environment bindings |
| `infra/` | Customer-authored non-Foundry Azure infrastructure, or a fully ejected IaC implementation | Agent instructions and agent-version payloads |
| `.azure/<env>/` | Environment-specific bindings and deployment state | Committed source |

There should be no `config.promptAgent` block. Harness routing is an
implementation detail derived from the selected Foundry project and the agent's
optional `harness` value.

This separate definition is required only for prompt agents. Hosted agents may
continue using their current inline `azure.yaml` definition.

## Recommended azd-project layout

Directory layout:

```text
azd-project/
|-- azure.yaml
|-- agents/
|   |-- support/
|   |   |-- agent.yaml
|   |   |-- knowledge/
|   |   `-- skills/
|   `-- researcher/
|       `-- agent.yaml
|-- shared/
|   |-- skills/
|   |-- tools/
|   |-- toolboxes/
|   `-- knowledge/
`-- infra/
    `-- app/
        |-- main.bicep
        `-- main.bicepparam
```

`knowledge/` replaces the overly generic `files/` name. A local `knowledge/`
folder is shorthand for an agent-private vector store and `file_search` tool.

## Flat, self-contained agent manifest

The proposed Foundry `agent.yaml` keeps all declarative agent-version
configuration in one flat, version-controlled file. Agent-level fields such as
model, instructions, tools, skills, policies, coordination settings, and
metadata live together rather than under an `agent:` wrapper or across implicit
sidecar files.

The manifest maps as directly as practical to the Foundry prompt-agent
definition. This makes it readable by itself, easier to review in pull
requests, and suitable for declarative CI apply/update workflows.

Field placement follows these boundaries:

| Concern | Source | Rationale |
| --- | --- | --- |
| Agent identity | azd agent-service key, with optional `resourceName` in `azure.yaml` | Avoid duplicating the remote name in the version definition. |
| Description | `description` in `agent.yaml` | Part of the saved agent definition. |
| Model | Logical `model` deployment reference in `agent.yaml` | azd resolves a portable logical name to a Foundry model deployment. |
| System behavior | Inline `instructions` in `agent.yaml` | Uses the Foundry API's field name and keeps behavior reviewable in one file. |
| Tools | `tools` in `agent.yaml` | Toolbox materialization is an implementation detail. |
| MCP/toolbox capabilities | `tools`/`toolboxes` in `agent.yaml`; connection resources in `azure.yaml` | Azure endpoint, identity, and credential lifecycle belongs in the azd resource graph/environment. |
| Skills | `skills` in `agent.yaml`; local bundles under `skills/` | References stay with the agent while bundle content remains independently reusable. |
| Multi-agent coordination | Add to `agent.yaml` only when Foundry exposes a stable contract | Do not invent a schema before the service contract exists. |
| Metadata | `metadata` in `agent.yaml` | Part of the saved agent definition. |

“Everything in `agent.yaml`” means every scalar and structured field belonging
to the saved agent definition. It does not mean embedding skill bundle files,
knowledge documents, secrets, Azure resource declarations, or azd service
topology in that file.

## `agent.yaml` definition

### Standard Foundry prompt agent

`agents/<name>/agent.yaml`:

```yaml
kind: prompt
model: chat
description: Answers product support questions using grounded documentation.
instructions: |
  You are a concise product support assistant.

  Use the available product knowledge for factual answers. If the knowledge
  does not contain an answer, say that the information is unavailable.
tools:
  - type: code_interpreter
metadata:
  owner: support-engineering
```

### GitHub Copilot harness agent

`agents/<name>/agent.yaml`:

```yaml
kind: prompt
harness: ghcp
model: chat
description: Investigates repositories and produces evidence-backed reports.
instructions: |
  You are a senior technical research coordinator.

  Inspect source and documentation before drawing conclusions. Clearly
  separate verified facts, assumptions, and recommendations.
tools:
  - type: code_interpreter
metadata:
  owner: developer-productivity
```

Rules:

- `ghcp` is the only valid value for `harness`.
- Omitting `harness` uses Foundry's no-harness prompt execution.
- `ghcp` compiles to `harness: ghcp` in the API payload.
- `model` is a logical deployment name declared by the `azure.ai.project`
  service, not a catalog model name or endpoint.
- `instructions` is an inline string. Use YAML's literal block (`|`) for
  multiline instructions. There is no implicit `instructions.md` lookup.
- `tools` and `skills` describe the capabilities of the primary toolbox. Under
  the azd-managed option azd compiles them into an explicit toolbox; under the
  service-managed option azd submits them as top-level agent fields and the
  service materializes the internal toolbox.
- `toolboxes` references additional toolbox services whose MCP endpoints are
  nested inside the agent's primary toolbox.
- The service key in `azure.yaml` is the default remote agent name. An optional
  standard azd `resourceName` override changes the remote name. Do not duplicate
  `name` in `agent.yaml`.
- Harness-specific fields are validated conditionally. Unsupported tools fail
  locally before any cloud mutation.

### Harness defaults and compatibility

The product/init default and the service API's omission semantics are separate
contracts:

| Time | Init selection shown as default | Representation written to `agent.yaml` |
| --- | --- | --- |
| Today | Standard Foundry runtime | `harness` omitted |
| Future | GitHub Copilot harness | `harness: ghcp` |

Changing the init default therefore affects only newly initialized agents. An
existing repository remains deterministic across azd upgrades and CI runners.

The Foundry service contract should preserve “omitted means standard” for the
current API version even if GHCP becomes the default in portals and client
tools. Those clients express their new default by explicitly sending `ghcp`.

If the service must eventually make omission mean GHCP, it first needs one of:

1. A new API/definition version whose omission semantics are explicitly GHCP,
   while the current version remains standard.
2. An explicit service representation for standard prompt execution.

Without one of those service-level mechanisms, azd cannot both change omission
to GHCP and preserve existing repositories that rely on standard execution.
Using the installed azd version to reinterpret the same file is not acceptable
for repeatable CI/CD deployments.

## azd-project service topology

`azure.yaml`:

```yaml
services:
  foundry-project:
    host: azure.ai.project
    deployments:
      - name: chat
        model:
          format: OpenAI
          name: gpt-4.1-mini
          version: "2025-04-14"
        sku:
          name: GlobalStandard
          capacity: 10

  support:
    host: azure.ai.agent
    # `project` is the local service source path.
    project: ./agents/support
    uses:
      - foundry-project
```

This matches hosted agents conceptually: each agent is an agent service, agents
share one Foundry project service, and `uses:` establishes lifecycle ordering.

### Agent definition discovery

For a prompt-agent service, azd loads `agent.yaml` from the service source path
by convention. The example therefore resolves to
`./agents/support/agent.yaml`; no repeated `$ref` is needed.

`$ref` is an azd Foundry configuration include, not native YAML syntax. It is
available as an explicit override when the definition needs a different
filename or location:

`azure.yaml`:

```yaml
support:
  host: azure.ai.agent
  project: ./agents/support
  $ref: ./definitions/support-agent.yaml
```

`$ref` paths are relative to the file containing the reference, may target
local YAML or JSON files, and cannot be URLs. Sibling properties beside `$ref`
override the loaded file using a shallow top-level merge.

Definition precedence is:

1. An inline agent definition or explicit root `$ref` on the service entry.
   This preserves existing hosted-agent behavior and advanced composition.
2. `<service source path>/agent.yaml`.

`azd ai agent init` writes the conventional `agent.yaml` filename and omits
`$ref`. A missing conventional file is a validation error. `agent.yml` may
remain a compatibility alias, but init should not generate it.

Core service fields remain in `azure.yaml`: `host`, `project`, `uses`,
`language`, `image`, and `docker` must not be supplied by a root agent `$ref`.
The prompt-agent file owns fields such as `kind`, `harness`, `model`,
`description`, `instructions`, `tools`, `skills`, and `metadata`.

## Portable Foundry-project binding

The tracked Foundry project service describes desired resources within a
Foundry project. The active azd environment decides whether azd creates a new
Foundry project or reconciles those declarations against an existing one.

Recommended precedence:

1. Explicit command flags.
2. Active azd environment values `FOUNDRY_PROJECT_ENDPOINT` and
   `AZURE_AI_PROJECT_ID`.
3. Create a Foundry project when neither binding exists.

Prompt-agent init may ask the user to select an existing Foundry project, but it
must write that selection only to `.azure/<env>/.env`. It must not stamp a
literal endpoint into `azure.yaml`.

The Foundry-project resolver should add this environment-binding path without
removing support for literal `endpoint` fields already generated for azd
projects containing hosted agents.
Changing hosted init to prefer portable environment binding is a desirable
follow-up, not a prompt-agent prerequisite.

An `endpoint` field can remain as an advanced compatibility feature for an azd
project intentionally pinned to one externally managed Foundry project, but
init should not produce it by default.

## Model portability

`azure.yaml` commits a desired, reproducible default deployment. Target-specific
overrides belong in the azd environment, keyed by logical deployment name.

For example, the logical deployment `chat` can be overridden by environment
values for catalog model, version, SKU, or capacity. Interactive provision may
offer an available alternative and persist the choice to the environment.
`--no-prompt` must fail with the exact missing or unavailable setting and never
choose a different model silently.

All Foundry scalar fields should use the shared `${VAR}` / `${VAR:-default}`
expander, including model and SKU fields. The current synthesizer does not yet
apply this consistently to deployments.

## Proposed primary-toolbox rule (ownership TBD)

“Rule” here means behavior intended to hold for every prompt agent: all
capabilities flow through one primary toolbox. This applies even when the author
supplies only `tools`, only `skills`, only knowledge, referenced toolboxes, or no
capabilities yet.

The primary toolbox's lifecycle owner is **TBD**. Two service designs are under
consideration:

1. **azd-managed toolbox:** azd explicitly creates, versions, attaches, records,
  and deletes the toolbox.
2. **Service-managed toolbox:** azd submits normalized `tools` and `skills` as
  top-level fields on the agent definition. The Foundry service materializes
  those capabilities into an internal toolbox, which may be hidden from the
  customer, and owns its versioning, attachment, and cleanup as part of the
  agent lifecycle.

The authoring contract should be identical in both cases. The remainder of this
proposal and its samples model the **azd-managed option** so the lifecycle is
concrete, but that ownership choice is not a settled requirement.

This is a deliberate change from the current branch. Today, inline `tools` and
generated `file_search` entries are passed directly to the agent; a toolbox is
created only when a local `skills/` folder or explicit toolbox reference is
present.

Under the azd-managed option, the toolbox is implicit: users do not add a
corresponding `host: azure.ai.toolbox` service for each agent. Its remote name
is derived deterministically from the agent's remote name, for example
`<agent-resource-name>-toolbox`, and azd records ownership metadata and the
resolved toolbox version in deployment state.

During package, azd resolves and normalizes these capability inputs:

- `tools:` entries in `agent.yaml`.
- Agent-local bundles under `skills/`.
- Referenced shared skill services or shared tool-definition files.
- `toolboxes:` references, each compiled to an MCP tool targeting that
  toolbox's endpoint.
- Generated tools such as `file_search` for private or shared knowledge.

The output representation then depends on lifecycle ownership:

- **azd-managed:** azd compiles the normalized inputs into an explicit toolbox
  manifest, deploys it, and places only its MCP attachment on the agent.
- **Service-managed:** azd places the normalized `tools` and `skills` on the
  agent definition as top-level fields. Referenced toolbox endpoints and
  generated knowledge capabilities appear as top-level tool entries. The
  service folds those fields into its internal toolbox.

Under the azd-managed option, deploy performs these steps:

1. Resolves the toolbox's connection dependencies.
2. Creates a new toolbox version only when its effective content hash changed.
3. Creates or updates the project connection used to authenticate to its MCP
  endpoint.
4. Attaches that endpoint to the prompt agent as an MCP tool.
5. Publishes the prompt-agent version only after the toolbox is ready.

The runtime behavior is one primary toolbox in either model, but the API shape
differs:

- **azd-managed:** the published agent definition contains one explicit MCP
  attachment for the primary toolbox. Authored tools and skills are not copied
  onto the agent.
- **Service-managed:** the published agent definition contains top-level
  `tools` and `skills`; the service-managed toolbox and its attachment may not
  appear in the public agent definition at all.

Model, instructions, policies, structured inputs, and tool-choice behavior
remain agent-level fields in both models.

Every authored or generated tool must be supported by the selected service
contract. Under the azd-managed option it must be representable by the public
Toolbox API. Under the service-managed option it must be accepted as a top-level
agent tool and supported by the service's internal toolbox. Validation fails
before cloud mutation when the selected contract cannot represent a tool.

An empty authored capability set still resolves to the one-primary-toolbox
runtime behavior. The azd-managed option requires an explicit empty toolbox;
the service-managed option may create no physical toolbox until needed or may
create a hidden empty toolbox. azd should not add a placeholder tool.

A referenced toolbox can be either:

- azd-managed and shared: a `host: azure.ai.toolbox` service without
  `endpoint`, deployed before its consumers.
- External: a `host: azure.ai.toolbox` service with `endpoint`, validated and
  reused without mutation.

In both cases, azd resolves the referenced toolbox's MCP endpoint. Under the
azd-managed option, azd adds the MCP tool to the explicit primary toolbox.
Under the service-managed option, azd submits it as a top-level MCP tool and the
service adds it to the internal toolbox. A referenced toolbox never replaces
the primary toolbox and is never deleted as part of deleting the consuming
agent.

`agents/<name>/agent.yaml`:

```yaml
toolboxes:
  - shared-research-tools
```

`azure.yaml`:

```yaml
services:
  shared-research-tools:
    host: azure.ai.toolbox
    uses:
      - foundry-project
    tools:
      - type: web_search

  researcher:
    host: azure.ai.agent
    project: ./agents/researcher
    uses:
      - foundry-project
      - shared-research-tools
```

Validation requires every `toolboxes:` name to identify a toolbox service and
requires the consuming agent's `uses:` list to contain the same service key.

## Tools and connections

### Tool ownership

| Tool category | Declared in | Executed by |
| --- | --- | --- |
| Foundry built-in tool | Top-level `tools` in source | Primary toolbox |
| Connection-backed tool | Top-level `tools`; connection is a service | Primary toolbox or remote service |
| Referenced toolbox | `toolboxes:` plus an `azure.ai.toolbox` service | Its MCP endpoint through the primary toolbox |
| External MCP tool | Top-level `tools` in source | External MCP server through the primary toolbox |
| Function schema | Top-level `tools` in source | Primary toolbox; customer client executes calls unless a harness provides an executor |

Connection definitions are first-class `azure.ai.connection` services. Tools
refer to the connection by its azure.yaml service key. Credentials use azd
environment values or managed identity and never appear literally in source.

`azure.yaml`:

```yaml
services:
  search:
    host: azure.ai.connection
    uses:
      - foundry-project
    category: CognitiveSearch
    target: ${AZURE_SEARCH_ENDPOINT}
    authType: ProjectManagedIdentity
```

`agents/<name>/agent.yaml`:

```yaml
tools:
  - type: azure_ai_search
    connection: search
    index_name: products
```

Until azd supports extension-discovered service dependencies, the agent service
also lists `search` under `uses:`. Validation must reject a reference without a
matching dependency edge so the two declarations cannot drift silently.

`azd ai agent invoke` must not claim to execute client-side function tools. If
the response requests one, the CLI should emit the structured tool call and an
actionable explanation unless an explicit tool-executor plugin is configured.

## Sharing skills, tools, and toolboxes

Two scopes are supported:

1. Agent-private convenience: `agents/<name>/skills/<skill>/SKILL.md` is
  packaged into that agent's primary toolbox.
2. azd-project-shared source: `azure.ai.skill` services and reusable tool
  definition files under `shared/tools/` can be referenced by multiple agents.
  Each consuming agent materializes them into its own primary toolbox.
3. azd-project-shared toolbox: an `azure.ai.toolbox` service is deployed once;
  each consumer adds its MCP endpoint as a nested tool in its own primary
  toolbox.

Shared skill and toolbox services get independent versions. Shared tool files
are source fragments and do not create remote resources by themselves. Each
Under the azd-managed option, each primary toolbox uses a deterministic name
based on azd-project name, azd environment, and agent identity and carries
ownership metadata for cleanup.

The service target for `azure.ai.skill` should accept a directory whose root is
`SKILL.md`, preserving the complete bundle rather than flattening it to inline
instructions.

## Knowledge

- `agents/<name>/knowledge/` creates an agent-private vector store.
- Hashes prevent unchanged files from being uploaded again.
- Deleting a source document removes it from the managed store on the next
  deploy; deployment must not be add-only.
- Chunking, file filters, and retention can be configured in `agent.yaml` when
  defaults are insufficient.
- Shared corpora are first-class `azure.ai.vectorstore` services rooted under
  `shared/knowledge/`; agents reference their service keys from `file_search`.
- Existing vector stores can be bound through environment-specific IDs and are
  never deleted by azd.

`azure.ai.vectorstore` is a proposed new service host; it does not exist in the
current implementation.

## Resource ownership

Every resolved resource must have one ownership mode:

| Mode | Example | Update | Delete |
| --- | --- | --- | --- |
| azd-environment-owned | Greenfield Foundry project, declared model | Reconcile | `azd down` |
| Shared service-owned | Skill, shared toolbox, shared vector store | Its service deploy | Reverse dependency order on full down |
| Agent-owned | Primary toolbox under the azd-managed option; private knowledge store | Agent deploy | Agent delete/full down |
| Service-owned | Primary toolbox under the service-managed option | Agent API | Foundry service agent lifecycle |
| External | Existing Foundry project, connection, toolbox/MCP server, vector store | Validate/reference only | Never |

Ownership is recorded in deployment state and remote metadata, not inferred
only from names. Removing a service from source stops management but should
produce a drift warning; destructive pruning requires an explicit command or
flag.

When an azd environment targets an existing Foundry project, `azd down` deletes
only environment-, service-, and agent-owned artifacts created by that azd
environment. It never deletes the external Foundry project or other external
resources.

## Command contracts

### `azd ai agent init`

For a new prompt agent (after the existing hosted-or-prompt selection):

1. Select standard Foundry runtime or GitHub Copilot harness.
2. Select/add the Foundry project service and logical model deployment.
3. Select a new or existing Foundry project for the active azd environment.
4. Scaffold `agents/<name>/agent.yaml` with inline starter instructions.
5. Add one `azure.ai.agent` service and its `uses:` edges.

Adding a second agent reuses the existing Foundry project service and offers
existing models and shared services. It never creates another root
`azure.yaml` within the azd project.

Existing Foundry project selections, subscription, location, quota-specific
model overrides, and secrets are written only to the active azd environment.

Non-interactive init requires flags or deterministic defaults:

Command line:

```text
--kind prompt --harness none|ghcp --agent-name <name> --model <logical-name>
```

### `azd provision`

1. Validate every manifest, reference, harness capability, and dependency graph
   before the first mutation.
2. Resolve the active azd environment's greenfield/brownfield Foundry-project
  binding.
3. Provision the Foundry account and Foundry project, model deployments, ARM
  connections, RBAC, and customer-authored infrastructure layers.
4. Persist canonical outputs in `.azure/<env>/.env`.

Provision does not create agent versions or upload agent manifests, knowledge,
or skills. It does not modify tracked files.

### `azd package [agent]`

Prompt agents have a real package phase even though they have no container. It
must produce a deterministic local artifact containing:

- Resolved portable agent manifest.
- Normalized tools/skills capability manifest and content hash.
- Explicit primary-toolbox manifest when using the azd-managed option.
- Agent-private knowledge metadata and content hashes.
- Agent-private skill bundles.
- Referenced tool schemas and a dependency lock/summary.

Package performs no cloud writes. This enables artifact promotion and
`azd deploy --from-package` in CI/CD.

### `azd deploy [agent]`

1. Load a package or package the selected service.
2. Resolve logical service references to environment-specific IDs/endpoints.
3. Validate that referenced shared services have resolved deployment outputs.
4. Reconcile private knowledge and skills, then materialize capabilities using
  the selected lifecycle model:
  - azd-managed: deploy the explicit primary toolbox.
  - service-managed: place normalized tools and skills on the agent payload.
5. Compile the final agent API payload and validate it against the selected
  harness. The azd-managed payload includes the primary toolbox attachment;
  the service-managed payload includes top-level tools and skills.
6. Create a new agent version only when the effective content hash changed.
7. Poll to a terminal state and persist name, version, endpoint, content hash,
  and any toolbox identity/version surfaced by the service to the azd
  environment/state store.

No tracked file is rewritten. To preserve GA hosted and core deploy semantics,
targeted deploy continues to deploy only the selected service. A new explicit
`--with-dependencies` option may deploy its `uses:` dependency closure. Without
that option, prompt deploy fails early with actionable guidance when a required
shared service has not been deployed. `azd up` and `azd deploy --all` already
walk all services in dependency order.

### `azd up`

Runs package, provision, and deploy through the existing graph. Prompt package
can overlap provisioning. Agent deploy waits for Foundry project provisioning
and its shared-service dependencies.

### Inspection commands

- `azd ai agent validate`: local schemas, files, references, capability matrix.
- `azd ai agent compile`: print/write the final payload with symbolic unresolved
  bindings, or fully resolve it when an environment is available.
- `azd ai agent show`: remote version, harness, primary toolbox ownership,
  effective tools/skills, dependencies, and ownership. Show toolbox identity
  and version only when the selected service contract exposes them.
- `azd ai agent list`: all agent kinds in the selected Foundry project.
- `azd ai agent invoke`: common Responses flow with harness-specific validation.
- `azd ai agent delete`: delete one agent and its other private owned assets.
  Delete the primary toolbox explicitly only under the azd-managed option;
  otherwise rely on the Foundry service's agent-lifecycle cleanup. Never delete
  shared or external assets without an explicit option.

### `azd down`

Delete in reverse dependency order, using the actual layer/service graph rather
than declaration order. Respect ownership modes and clear only outputs owned by
the deleted resources.

## Foundry plus custom Bicep: current verified behavior

Core azd supports mixed providers through `infra.layers[]`:

`azure.yaml`:

```yaml
infra:
  provider: microsoft.foundry
  layers:
    - name: foundry
      path: .
    - name: app
      provider: bicep
      path: ./infra/app
      dependsOn:
        - foundry
```

This runtime path is implemented and mixed-provider dependency analysis is
tested. Foundry outputs are merged into the azd environment before a dependent
Bicep layer starts.

Current limitations:

1. The published `azure.yaml` schema omits `infra.layers[].provider` even though
   the Go model and tests support it, so editors reject valid runtime syntax.
2. The root provider must be `microsoft.foundry` for `azd up`'s early provider
   initialization to take the intended path.
3. Custom Bicep must not use `./infra/main.bicep` while retaining the Foundry
   provider. That path makes the provider replace its embedded Foundry template
   with the on-disk template. Use a separate layer path such as `./infra/app`.
4. A custom Bicep layer can reliably consume Foundry outputs. The reverse is not
   reliable today: the Foundry provider synthesizes during early initialization
   and the extension host caches one provider instance by provider name, before
   an earlier Bicep layer can publish outputs.
5. Cross-provider dependencies require explicit `dependsOn`; only Bicep layers
   participate in static output analysis.
6. Multi-layer preview targets one layer at a time.
7. `azd down` reverses declaration order, not the dependency graph.
8. Layers are separate deployments, not one atomic ARM transaction.

An alternative available today is an ejected `infra/main.bicep`. Under
`microsoft.foundry`, that file completely replaces the embedded template. Users
can add arbitrary modules to it, but then own the full Foundry IaC implementation.

## Recommended provisioning improvements

1. Add `provider` to the published layer schema.
2. Do not initialize a root provider as a proxy for all layers. Resolve common
   subscription/location inputs once, then initialize each provider only when
   its layer is scheduled.
3. Key extension provisioning instances by provider plus layer identity, or
   make `Initialize` safely refresh the instance for each layer.
4. Defer Foundry synthesis until the Foundry layer executes so it sees outputs
   from declared dependencies.
5. Make on-disk-template replacement explicit in provider config and honor the
   layer path; do not trigger replacement merely because `infra/main.bicep`
  exists elsewhere in a layered azd project.
6. Use the dependency DAG in reverse for teardown.

With those changes, either direction works:

- Foundry -> Bicep: an app consumes Foundry project IDs/endpoints.
- Bicep -> Foundry: a Search/Storage resource is created first and then exposed
  through a Foundry connection.

## CI/CD contract

A clean runner must be able to use:

Command line:

```text
azd up --no-prompt --environment <name> \
  --subscription <subscription-id> --location <region>
```

Requirements:

- Federated or service-principal authentication; no interactive login.
- Existing Foundry project binding supplied through azd environment/secret
  configuration.
- No source mutation.
- No implicit model fallback.
- Machine-readable validation, preview, deployment, and endpoint output.
- Stable logical resource names with environment-specific physical names.
- Concurrent environments from the same commit without name collisions.
- Package artifacts that can be promoted without rebuilding source.

## Optional shared improvements

These are not required for prompt-agent support. Each needs separate UX and
compatibility review because it can change established hosted-agent behavior:

1. Migrate hosted definitions from inline service properties to
  `agents/<name>/agent.yaml`. Supporting both forms indefinitely is safer than
  forcing a migration.
2. Derive hosted remote names from the service key plus `resourceName`, removing
  its duplicate definition `name` only through an explicit compatibility plan.
3. Consider making targeted deploy include `uses:` dependencies by default for
  every service kind. Prompt support uses opt-in `--with-dependencies` first.
4. Add deterministic hosted package/compile artifacts and content-hash no-op
  deploys. Prompt packages can introduce this independently.
5. Change hosted init to store existing Foundry project bindings only in
  `.azure`, while continuing to accept existing literal `endpoint`
  declarations.

The following shared fixes are additive and can be made without changing hosted
agent semantics:

1. Use the same canonical Foundry project endpoint environment key in every
  extension.
2. Expose ownership and drift in `show`, `doctor`, and JSON output.
3. Keep schemas synchronized with runtime parsing and API payloads.
4. Fix mixed-provider layer initialization, schema support, and teardown order.

## Product facts still requiring confirmation

These are not unresolved architecture choices, but platform capability inputs
needed to finalize validation rules:

- Exact tool support differences between standard and GHCP prompt agents.
- Whether GHCP is the stable public harness identifier.
- Whether both prompt runtimes can invoke every supported tool through one
  toolbox MCP attachment.
- Whether the primary toolbox is azd-managed or service-managed.
- How the chosen owner represents an empty primary toolbox.
- Supported identity modes and when an agent principal becomes available.
- Foundry limits for files, vector stores, skill bundles, and agent versions.
