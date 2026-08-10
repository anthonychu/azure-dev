# Product facts

- The hosted study agent runs customer-owned Python code.
- The prompt study agent is declarative and has no customer-owned runtime code.
- This branch serializes every prompt agent with `harness: ghcp`.
- A non-empty `files/` folder is uploaded into a Foundry vector store.
- A non-empty `skills/` folder is registered as a Foundry toolbox and attached
  to the prompt agent as an MCP tool.
