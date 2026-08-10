# Multiple agents with shared resources

Proposed azd project demonstrating:

- Standard and GHCP prompt agents in one Foundry project.
- A shared model deployment.
- A shared Search connection.
- A shared azd-managed toolbox nested into the researcher's primary toolbox
  through MCP.
- A shared versioned skill.
- A shared vector store.
- One separately versioned primary toolbox per agent; this sample models azd as
  its lifecycle owner, while service ownership remains TBD.

The agent definitions refer to shared cloud resources by azure.yaml service
key. Their `uses:` lists provide lifecycle ordering and are validated against
those references. Direct tools, skills, generated knowledge tools, and the
referenced toolbox are all materialized into each consuming agent's own
toolbox.
