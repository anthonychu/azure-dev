# Single standard prompt agent

Proposed minimal greenfield azd project:

- One Foundry project.
- One logical model deployment.
- One standard prompt agent (`harness` omitted).
- Agent-private instructions and knowledge.
- One implicit primary toolbox created and managed by azd for this sample from
  the declared `code_interpreter` tool and generated knowledge tool. Service
  ownership remains TBD in the overall design.

A clone can run `azd up` against a new azd environment without editing tracked
files. Selecting an existing Foundry project writes the binding to `.azure`,
not this azd project's `azure.yaml`.
