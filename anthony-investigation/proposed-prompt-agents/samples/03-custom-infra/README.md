# Custom Azure infrastructure feeding Foundry

Proposed target behavior for bidirectional provider composition:

1. The Bicep `app` layer creates Azure AI Search.
2. Its endpoint and resource ID are persisted as azd environment outputs.
3. The dependent `foundry` layer creates the Foundry project and its connection.
4. Agent deploy resolves the logical `search` connection, materializes the
   primary toolbox containing the Search tool, and attaches it to the agent.

This sample models the azd-managed lifecycle option; service-managed ownership
remains TBD in the overall design.

The current branch cannot reliably execute this direction because the Foundry
provider synthesizes before the Bicep layer publishes outputs. The proposal
requires deferred per-layer provider initialization described in `PROPOSAL.md`.
