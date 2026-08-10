# Foundry agent shape investigation

This folder contains two independent azd projects for studying the current
agent shapes on this branch. They are examples, not deployed environments.

| Project | Shape being demonstrated |
| --- | --- |
| `hosted-agent/` | Preferred split `azure.ai.project` + `azure.ai.agent` shape with customer-owned Python code deployed from source. |
| `prompt-agent/` | The compatibility-shaped service currently written by `runInitManaged`, plus the new prompt-agent conventions for tools, files, skills, and connections. |
| `proposed-prompt-agents/` | Recommended target design and proposed samples; intentionally not current-branch syntax. |

## Important boundaries

- No Azure provisioning or deployment was run while creating these projects.
- The hosted agent is locally runnable after installing its Python dependency.
- The prompt agent has no local server; Foundry and the GHCP harness own its
  runtime.
- `prompt-agent/azure.yaml` contains the same placeholder workspace tuple used
  by non-guided prompt init. Provisioning overlays it with the real Foundry
  project values.
- `prompt-agent/agent.yaml` intentionally has no `harness` property. The branch
  injects `harness: ghcp` when it builds the API request.
- The Search endpoint and index in the prompt example are placeholders. Replace
  them before attempting a deployment.

## Suggested reading order

1. Compare the two `azure.yaml` files.
2. Compare hosted `main.py` with prompt `agent.yaml` and `instructions.md`.
3. Inspect `prompt-agent/files/` and `prompt-agent/skills/`.
4. Read each project README for the transformations azd applies at deploy time.

## Validation performed

- Both `azure.yaml` files and the prompt `agent.yaml` parse as YAML.
- The hosted `main.py` compiles as Python.
- The branch's prompt YAML, tool passthrough, connection, file, and skill tests
  pass against these same field shapes.
