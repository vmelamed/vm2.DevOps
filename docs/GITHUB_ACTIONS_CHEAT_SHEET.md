# GitHub Actions Cheat Sheet

A compact guide to the GitHub Actions features used by vm2.DevOps consumers. For the complete reusable-workflow API,
see [Workflows Reference](WORKFLOWS_REFERENCE.md); for the release model, see [Release Process](RELEASE_PROCESS.md).

Official references: [workflow syntax](https://docs.github.com/actions/reference/workflows-and-actions/workflow-syntax),
[contexts](https://docs.github.com/actions/learn-github-actions/contexts), and
[reusable workflows](https://docs.github.com/actions/how-tos/reuse-automations/reuse-workflows).

## Data Scopes

| Mechanism | Producer | Consumer | Crosses reusable-workflow boundary? | Typical use |
| :-------- | :------- | :------- | :---------------------------------- | :---------- |
| `vars.NAME` | Organization, repository, or environment configuration | Workflow expressions | Available from the caller's organization, repository, or declared environment, subject to access rules and precedence.| Non-secret repository configuration |
| `env.NAME` | Workflow, job, or step `env:` | Descendant jobs or steps in the same workflow | No | Shell configuration and derived settings |
| `inputs.NAME` | Caller `with:` or manual-dispatch input | Called workflow or the receiving workflow | Yes, when declared under `workflow_call.inputs` | Typed reusable-workflow contract |
| `secrets.NAME` | Repository, organization, or environment secret | Explicitly mapped called workflow | No, unless explicitly passed or inherited | Tokens and credentials |
| `steps.id.outputs.NAME` | A step writes `$GITHUB_OUTPUT` | Later steps in the same job | Not directly | Step-to-step values |
| `needs.job.outputs.NAME` | A job maps its step outputs | Dependent jobs | Not directly | Job-to-job values |
| `needs.call.outputs.NAME` | A reusable workflow declares workflow outputs | Jobs that depend on the caller job | Yes, through declared workflow outputs | Results returned by a reusable workflow |
| Artifact | `actions/upload-artifact` | `actions/download-artifact` | Yes, within the workflow run | Files, packages, reports, and build outputs |

`vars` and `env` solve different problems. `vars` reads GitHub configuration; `env` defines runner environment variables.
Use explicit inputs for anything the reusable workflow needs as part of its public contract, even when a value currently
comes from `vars`.

## Reusable Workflow Contract

Declare the caller-facing contract in the shared workflow:

```yaml
on:
  workflow_call:
    inputs:
      configuration:
        type: string
        required: false
        default: Release
    secrets:
      RELEASE_PAT:
        required: true
    outputs:
      version:
        description: Published package version
        value: ${{ jobs.publish.outputs.version }}
```

Call it as a job, not as a step:

```yaml
jobs:
  prerelease:
    uses: vmelamed/vm2.DevOps/.github/workflows/_prerelease.yaml@main
    with:
      configuration: ${{ vars.CONFIGURATION || 'Release' }}
    secrets:
      RELEASE_PAT: ${{ secrets.RELEASE_PAT }}
    permissions:
      contents: write
      packages: write
      id-token: write
```

For third-party reusable workflows, pin `uses:` to a full commit SHA. The vm2 repositories currently use `@main` for
their shared internal workflows so fixes are adopted centrally; that is a deliberate trust and rollout trade-off.

## What Reusable Workflows Receive

| Item | Behavior |
| :--- | :------- |
| `github` context | Comes from the caller's workflow run, including repository, SHA, actor, and event payload. |
| `GITHUB_TOKEN` | Available automatically, limited by the caller's granted permissions. |
| Permissions | May be maintained or reduced at each nesting level; a called workflow cannot elevate them. |
| Configuration variables | Resolved through the `vars` context according to their normal organization, repository, and environment visibility. Do not make them an implicit reusable-workflow contract. |
| Caller `env:` | Not inherited. Workflow-, job-, and step-level `env` values stop at the reusable-workflow boundary. |
| Caller secrets | Not inherited by default. Pass named secrets or use `secrets: inherit`. |

`secrets: inherit` is available only when the caller and callee are in the same organization or enterprise. Prefer named
mapping for release workflows because it documents and limits the credential surface:

```yaml
secrets:
  RELEASE_PAT: ${{ secrets.RELEASE_PAT }}
  NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
```

Secrets move one call at a time. In `A -> B -> C`, workflow `C` receives a secret only when `A` passes it to `B` and
`B` passes it to `C`. An environment secret cannot be passed through `workflow_call`; if the called workflow's job
declares an environment, that job uses the environment's secret.

## Passing Values

### Between Steps

```yaml
- id: version
  shell: bash
  run: echo "value=1.2.3" >> "$GITHUB_OUTPUT"

- run: echo "${{ steps.version.outputs.value }}"
```

Use `$GITHUB_ENV` only for later steps in the same job:

```yaml
- shell: bash
  run: echo "ARTIFACTS_DIR=artifacts/pack" >> "$GITHUB_ENV"
```

The step that writes `$GITHUB_ENV` does not see the newly assigned variable. The next step does.

### Between Jobs

```yaml
jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      package-projects: ${{ steps.parameters.outputs.package-projects }}
    steps:
      - id: parameters
        shell: bash
        run: echo 'package-projects=["src/Package/Package.csproj"]' >> "$GITHUB_OUTPUT"

  package:
    needs: prepare
    runs-on: ubuntu-latest
    steps:
      - run: echo '${{ needs.prepare.outputs.package-projects }}'
```

This is the vm2 pattern for converting consumer workflow configuration into `with:` inputs for a reusable workflow.

### From a Reusable Workflow

Map a step output to a job output, then map that job output to `workflow_call.outputs`:

```yaml
on:
  workflow_call:
    outputs:
      version:
        value: ${{ jobs.publish.outputs.version }}

jobs:
  publish:
    outputs:
      version: ${{ steps.package.outputs.version }}
```

The caller reads it through `needs`:

```yaml
jobs:
  publish:
    uses: owner/repo/.github/workflows/publish.yaml@main

  announce:
    needs: publish
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ needs.publish.outputs.version }}"
```

## Expressions and Conditions

Use contexts in YAML expressions and runner syntax inside shell scripts:

```yaml
if: github.event_name == 'workflow_dispatch' && inputs.publish
run: echo "$CONFIGURATION"
```

Useful helpers:

| Expression | Purpose |
| :--------- | :------ |
| `success()` | All required preceding jobs or steps succeeded. |
| `failure()` | A preceding job or step failed. |
| `cancelled()` | The workflow or job was cancelled. |
| `always()` | Run even when a dependency failed or was cancelled. |
| `fromJSON(value)` | Convert a JSON string to a boolean, number, array, or object. |
| `toJSON(value)` | Serialize a context for diagnostics. Do not print secrets. |
| `hashFiles('**/packages.lock.json')` | Hash matching files for cache keys or artifact names. |

Use `if: always()` on a gate job that must report a stable required check even when an upstream job fails:

```yaml
postrun-ci:
  if: always()
  needs: [build, test, benchmarks, pack]
  runs-on: ubuntu-latest
```

Treat all event-derived strings as untrusted input. Do not interpolate untrusted expressions directly into shell source;
instead, pass them through `env:` and quote shell expansions.

## Artifacts, Caches, and Summaries

| Mechanism | Use it for | Do not use it for |
| :-------- | :--------- | :---------------- |
| Artifact | Files needed by another job in the same run, reports, `.nupkg` files | Long-lived dependency reuse |
| Cache | Dependencies and expensive reproducible intermediates across runs | Passing correctness-critical build output between jobs |
| `$GITHUB_STEP_SUMMARY` | Human-readable Markdown on the workflow-run summary | Programmatic data exchange |

```yaml
- uses: actions/upload-artifact@v7
  with:
    name: packages
    path: artifacts/pack/*.nupkg
    if-no-files-found: error

- name: Summarize
  shell: bash
  run: |
    echo "## Package result" >> "$GITHUB_STEP_SUMMARY"
    echo "Published successfully." >> "$GITHUB_STEP_SUMMARY"
```

## Release Trigger Pattern

Use `workflow_run` to trigger prerelease work after CI on `main`, then pass the validated SHA to the release workflow.
The reusable workflow must verify that `main` still points at that SHA before mutating changelog history or tags.

```yaml
on:
  workflow_run:
    workflows: ["CI: Build, Test, Benchmark, Pack"]
    branches: [main]
    types: [completed]

jobs:
  prerelease:
    if: github.event.workflow_run.conclusion == 'success'
    uses: vmelamed/vm2.DevOps/.github/workflows/_prerelease.yaml@main
    with:
      sha: ${{ github.event.workflow_run.head_sha }}
    secrets:
      RELEASE_PAT: ${{ secrets.RELEASE_PAT }}
```

`workflow_run` has a distinct event payload. Use `github.event.workflow_run.head_sha`, not `github.sha`, to identify the
commit CI validated. See [Release Process](RELEASE_PROCESS.md) for the full prerequisite and race-condition handling.
