# Hosted agent study project

This project demonstrates a Python hosted agent deployed from source code. The
customer owns and runs the agent loop in `main.py`; Foundry hosts that process
and exposes its Responses endpoint.

## Files

| File | Purpose |
| --- | --- |
| `azure.yaml` | Provisions a Foundry project/model and defines the hosted agent inline. |
| `main.py` | Implements the Responses protocol handler. |
| `requirements.txt` | Supplies the official Python Responses hosting library. |
| `.agentignore` | Excludes project state and local files from the uploaded source ZIP. |
| `.gitignore` | Excludes local azd and Python state from Git. |
| `requests.http` | Contains a local request for the running agent. |

## Shape highlights

- `infra.provider: microsoft.foundry` asks the extension provider to synthesize
  infrastructure from `azure.yaml`; no checked-in `infra/` folder is required.
- `ai-project` owns account/project-level configuration such as model
  deployments.
- `hosted-study-agent` owns the runtime definition and depends on `ai-project`
  through `uses`.
- `codeConfiguration` selects source ZIP deployment, Python 3.13, and remote
  dependency installation. It avoids a customer-managed container image.
- `protocols` says the customer code implements the Responses contract.
- `startupCommand` is used by `azd ai agent run` for the local process.

The sample handler echoes input so the hosting boundary stays obvious. The
model deployment is present to show the complete project resource shape, but
this minimal handler does not call it.

## Local commands

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
azd ai agent run
```

In another terminal:

```bash
azd ai agent invoke --local "What kind of agent are you?"
```

Provisioning and deployment create billable Azure resources, so review the
subscription, region, model, and quota before running `azd up`.
