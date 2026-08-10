# Proposed prompt-agent support

This directory is a design draft. It does not describe syntax accepted by the
current branch, and its samples are not intended to deploy yet.

- `PROPOSAL.md` defines the recommended ownership and command contracts.
- `samples/` demonstrates the proposed source layout for key customer cases.

The proposal keeps `kind: prompt` for both standard Foundry prompt agents and
GitHub Copilot harness agents. Standard agents omit `harness`, matching the
service API; GitHub Copilot harness agents set `harness: ghcp`.

Every proposed prompt agent receives one primary toolbox. Authored tools,
skills, generated knowledge tools, and referenced toolboxes feed that toolbox.
The samples model azd compiling an explicit toolbox. In the service-managed
alternative, azd submits tools and skills as top-level agent fields and the
service materializes an internal, potentially hidden toolbox. Ownership remains
TBD.
