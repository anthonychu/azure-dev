# Prompt agent study project

This project demonstrates the prompt-agent implementation added on this branch.
The author declares a model, instructions, and tools; Foundry owns the runtime.
The request mapper currently adds `harness: ghcp` unconditionally.

## Files

| File | Purpose |
| --- | --- |
| `azure.yaml` | Selects the service target, provisioning provider, model deployment, and managed-harness routing settings. |
| `agent.yaml` | Declares the prompt agent, model, explicit tools, structured inputs, and connection. |
| `instructions.md` | Supplies instructions because `agent.yaml` omits inline `instructions`. |
| `files/product-facts.md` | Becomes vector-store content and causes deploy to inject `file_search`. |
| `skills/release-notes/SKILL.md` | Defines a skill registered into a Foundry toolbox. |
| `skills/release-notes/references/style.md` | Demonstrates that the complete skill bundle, not only `SKILL.md`, is uploaded. |

## What deploy derives

The source does not contain the final definition verbatim. Deploy resolves this
graph before publishing:

1. Ensure the `gpt-4.1-mini` deployment exists.
2. Upload `files/product-facts.md`, create a vector store, and inject a
   `file_search` tool containing the returned vector-store ID.
3. Upload the whole `release-notes` skill bundle, create a toolbox version and
   its `RemoteTool` project connection, then inject an `mcp` tool containing the
   toolbox URL and connection ID.
4. Resolve or create the declared `study-search` connection and surface the
   required Search role assignment.
5. Copy the explicit tools through to the API definition.
6. Add `harness: ghcp` and create or update the agent version.

The resulting tool set is therefore larger than the three tools visibly
declared in `agent.yaml`.

## Explicit tools

- `function`: demonstrates the function schema. This repository contains no
  implementation for `calculate_total`; an execution integration is still
  required if the model calls it.
- `code_interpreter`: a platform tool requiring no customer runtime code.
- `azure_ai_search`: references `study-search`. The endpoint and index are
  placeholders and must be replaced before deployment.

## Harness settings

The `config.promptAgent` block is routing configuration, despite its name. It
contains no harness selector. The default subscription/resource-group/workspace
values are temporary placeholders used by prompt init; deploy overlays them
from the azd environment after Foundry project provisioning.

The model deployment is also nested under `config` because that is what
`runInitManaged` currently writes. Before provisioning, the extension's legacy
event handler reads that block and exports it as `AI_PROJECT_DEPLOYMENTS`; the
compatibility provisioning path consumes the environment value. The
synthesizer itself only reads top-level deployments from an
`azure.ai.project` service, so reading that component alone misses this path.

For a selected existing project, init also writes `projectEndpoint`, changes
`apiVersion` to `v1`, and derives `modelEndpoint` from the account host.

## Known branch mismatch

The generated schema annotation points to the public `PromptAgent.yaml` schema.
VS Code currently reports that API-style tool objects using `type` are missing
legacy `kind`/`name` fields. The branch's deploy implementation and tests,
however, explicitly accept and pass through the `type`-based shapes used here.
The diagnostics are therefore evidence of schema drift, not a YAML parse error.

Another stale test comment says prompt `files/` are unsupported, while the
deploy graph and changelog implement vector-store-backed file search. This
fixture follows the implemented deploy graph.

## Lifecycle commands

After replacing the Search placeholders and choosing an Azure environment:

```bash
azd up
azd ai agent show prompt-study-agent
azd ai agent invoke prompt-study-agent "Summarize the product facts"
azd ai agent list
```

`azd up` provisions billable resources. Review the target subscription, region,
model quota, Search connection, and generated plan before running it.
