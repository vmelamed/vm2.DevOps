# NuGet.org Trusted Publishing Migration

<!-- TOC tocDepth:2..3 chapterDepth:2..6 -->

- [NuGet.org Trusted Publishing Migration](#nugetorg-trusted-publishing-migration)
  - [Purpose and Scope](#purpose-and-scope)
  - [How Trusted Publishing Works](#how-trusted-publishing-works)
  - [Migration Design](#migration-design)
  - [One-Time NuGet.org Setup](#one-time-nugetorg-setup)
  - [Repository Configuration](#repository-configuration)
  - [Consumer Workflow Changes](#consumer-workflow-changes)
  - [Reusable Workflow Changes](#reusable-workflow-changes)
  - [Publishing Script](#publishing-script)
  - [Documentation and Template Updates](#documentation-and-template-updates)
  - [Rollout Procedure](#rollout-procedure)
  - [Troubleshooting](#troubleshooting)
  - [Security Notes](#security-notes)
  - [References](#references)

<!-- /TOC -->

How to replace the long-lived NuGet.org API key used by vm2 publishing workflows with NuGet.org trusted publishing through
GitHub Actions OpenID Connect (OIDC).

## Purpose and Scope

Trusted publishing applies to **NuGet.org only**. It does not authenticate publishing to GitHub Packages or to arbitrary
NuGet-compatible servers. Therefore, the vm2.DevOps framework should use trusted publishing for `NUGET_SERVER=nuget` and
retain the existing API-key path for `NUGET_SERVER=github` and custom URLs.

The migration changes only how the publish job obtains its API key. It does not change MinVer versioning, package contents,
the changelog process, Git tags, package artifacts, or `RELEASE_PAT`.

## How Trusted Publishing Works

1. The GitHub Actions publishing job requests an OIDC token with `id-token: write` permission.
1. `NuGet/login@v1` exchanges that token with NuGet.org.
1. NuGet.org validates the token against a trusted-publishing policy that identifies the repository and workflow.
1. NuGet.org returns a temporary API key, valid for one hour.
1. The existing `dotnet nuget push --api-key ...` invocation publishes with that temporary key.

The OIDC token can be exchanged only once. Request the temporary API key immediately before publishing so it cannot expire
while the workflow is building and packing the project.

## Migration Design

Keep `publish-package.sh` independent of the authentication mechanism. The script continues to require `NUGET_API_KEY` and
to pass it to `dotnet nuget push`; the reusable workflow supplies either:

- a temporary key from `NuGet/login@v1` when the target is NuGet.org; or
- a long-lived API key secret when the target is GitHub Packages or a custom server.

This preserves the current multi-server API while removing the NuGet.org publishing secret. A `nuget-username` reusable-
workflow input identifies the NuGet.org profile used by `NuGet/login@v1`. A profile name is not a credential, so it belongs
in a repository variable rather than a secret.

## One-Time NuGet.org Setup

Perform these steps for every vm2 repository that publishes a package to NuGet.org.

1. Sign in to NuGet.org as the package owner.
1. Open the account menu and select **Trusted Publishing**.
1. Create a trusted-publishing policy for the prerelease workflow:
   - **Repository Owner:** `vmelamed`
   - **Repository:** the consumer repository name, for example `vm2.Ulid`
   - **Workflow File:** `Prerelease.yaml`
   - **Environment:** leave empty unless the publishing job uses a GitHub Actions environment.
1. Create a second policy for the stable-release workflow, changing **Workflow File** to `Release.yaml`.
1. Repeat for every package repository.

The policy names the consumer repository's entry workflow, not the reusable workflows in vm2.DevOps. For example, use
`Prerelease.yaml`, not `_prerelease.yaml`.

For private repositories, a policy can initially be active for only seven days. Complete one successful publish during that
window so NuGet.org can bind the policy permanently to the GitHub repository and owner IDs.

## Repository Configuration

In each consumer repository, create these GitHub Actions variables:

```text
NUGET_SERVER   = nuget
NUGET_USERNAME = vmelamed (TODO: modify vm2.DevOps/scripts/bash/setup-repo.sh)
```

`NUGET_USERNAME` must be the NuGet.org profile name, not an email address. Once trusted publishing is verified for that
repository, remove its long-lived `NUGET_API_KEY` secret if it is used only for NuGet.org publishing.

Do not remove `RELEASE_PAT`. It authorizes a different operation: bypassing branch-protection rules so the release workflow
can push a generated changelog commit and tag to `main`.

## Consumer Workflow Changes

Update the canonical consumer workflows in vm2.Templates:

- `templates/AddNewPackage/content/.github/workflows/Prerelease.yaml`
- `templates/AddNewPackage/content/.github/workflows/Release.yaml`

For the jobs that call `_prerelease.yaml` and `_release.yaml`:

1. Change the default `NUGET_SERVER` from `github` to `nuget`.
1. Grant `id-token: write` in the calling job's `permissions` block. Called workflows can reduce permissions but cannot add a
   permission that their caller did not grant.
1. Pass `nuget-username: ${{ vars.NUGET_USERNAME }}` in the reusable-workflow inputs.
1. Stop forwarding `NUGET_API_KEY` when publishing to NuGet.org.
1. Remove `packages: write` when the workflow is NuGet.org-only. That permission is for GitHub Packages, not NuGet.org.

The intended NuGet.org caller shape is:

```yaml
prerelease:
  uses: vmelamed/vm2.DevOps/.github/workflows/_prerelease.yaml@main
  permissions:
    contents: write
    id-token: write
  secrets:
    RELEASE_PAT: ${{ secrets.RELEASE_PAT }}
  with:
    nuget-server: ${{ needs.get-params.outputs.nuget-server }}
    nuget-username: ${{ vars.NUGET_USERNAME }}
```

If GitHub Packages and custom-server publishing remain supported, use an explicit authentication-mode input or a conditional
secret path. Do not attempt to use NuGet.org trusted publishing for those servers.

## Reusable Workflow Changes

Update both vm2.DevOps reusable workflows:

- `.github/workflows/_prerelease.yaml`
- `.github/workflows/_release.yaml`

1. Add a `nuget-username` `workflow_call` input.
1. Retain `NUGET_API_KEY` only as an optional fallback secret for `github` and custom URL targets. Its description must make
   that scope explicit.
1. On the package publishing job, grant the minimum permissions required for NuGet.org:

   ```yaml
   permissions:
     contents: read
     id-token: write
   ```

1. Immediately before the publish step, conditionally authenticate to NuGet.org:

   ```yaml
   - name: Authenticate with NuGet.org trusted publishing
     if: inputs.nuget-server == 'nuget'
     id: nuget-login
     uses: NuGet/login@v1
     with:
       user: ${{ inputs.nuget-username }}
   ```

1. Set the publish step's `NUGET_API_KEY` environment variable conditionally: use
   `${{ steps.nuget-login.outputs.NUGET_API_KEY }}` for NuGet.org, otherwise use the fallback secret.
1. Fail before packing when `nuget-server` is `nuget` and `nuget-username` is empty, or when another server needs an API key
   but the fallback secret is missing.

The final environment expression may be clearer and safer when handled in two explicit publish steps: one for NuGet.org
OIDC and one for API-key servers. Both steps invoke the same `publish-package.sh` command. This avoids a subtle empty-
credential expression and makes the security boundary obvious in workflow logs.

## Publishing Script

No initial code change is required in `.github/scripts/publish-package.sh`. It already accepts an API key through the
`NUGET_API_KEY` environment variable and uses it only for:

```bash
dotnet nuget push "$artifacts_dir"/*.nupkg \
    --source "$server_url" \
    --api-key "$server_api_key" \
    --skip-duplicate
```

Trusted publishing changes where `NUGET_API_KEY` comes from, not how the NuGet CLI consumes it. Update
`publish-package.usage.sh` to call it an API key supplied by the workflow, rather than implying that it must always be a
long-lived repository secret.

## Documentation and Template Updates

Update the canonical template and vm2.DevOps documentation in the same change:

1. `docs/CONFIGURATION.md`: document `NUGET_USERNAME` and OIDC for NuGet.org; describe `NUGET_API_KEY` as the fallback for
   GitHub Packages and custom servers.
1. `docs/RELEASE_PROCESS.md`: document the two trusted-publishing policies, `id-token: write`, and the temporary-key flow.
1. `docs/WORKFLOWS_REFERENCE.md`: update reusable-workflow inputs, permissions, and secret requirements.
1. `docs/ERROR_RECOVERY.md`: replace the NuGet.org API-key recovery guidance with trusted-policy, workflow-name, and OIDC-
   permission checks; retain API-key recovery for fallback targets.
1. `templates/AddNewPackage/content/.template.config/template.json`: remove NuGet.org `NUGET_API_KEY` from the new-
   repository secret checklist and add `NUGET_USERNAME` plus trusted-policy setup.
1. `templates/AddNewPackage/content/README.md`: update setup and configuration examples.

Consumer workflow files are template-synchronized content. Make their canonical changes in vm2.Templates first, then
propagate them with `diff-shared.sh`.

## Rollout Procedure

1. Implement the reusable-workflow and documentation changes in vm2.DevOps.
1. Update the canonical consumer workflows and setup documentation in vm2.Templates.
1. Select one low-risk package repository as a pilot.
1. Create its two NuGet.org trusted-publishing policies and set `NUGET_SERVER=nuget` and `NUGET_USERNAME`.
1. Propagate the updated template workflow files to the pilot repository.
1. Run a manual prerelease. Verify that `NuGet/login@v1` succeeds and that NuGet.org marks the policy active.
1. Run a stable release after the prerelease succeeds.
1. Remove the pilot repository's long-lived NuGet.org `NUGET_API_KEY` secret.
1. Roll out to the remaining repositories one at a time.

Do not switch every repository at once. The first successful release validates the GitHub OIDC claim, the NuGet policy, and
the reusable-workflow permission propagation together.

## Troubleshooting

| Symptom | Likely Cause | Resolution |
| :--- | :--- | :--- |
| `NuGet/login@v1` cannot request an OIDC token | `id-token: write` is absent from the caller or publishing job | Add the permission at the consumer call job and retain it on the reusable publishing job. |
| NuGet.org rejects the OIDC exchange | Policy names the wrong repository or workflow | Check the owner, repository, and consumer workflow filename. Use `Prerelease.yaml` or `Release.yaml`, not the vm2.DevOps reusable workflow filename. |
| Policy is inactive | The initial private-repository activation window expired | Reactivate the policy in NuGet.org and complete a successful publish within seven days. |
| NuGet login fails for an otherwise valid policy | `NUGET_USERNAME` is missing or is an email address | Set the NuGet.org profile name in the repository variable. |
| `dotnet nuget push` reports 401 or 403 for `nuget` | Login output was not passed to the publish step | Set `NUGET_API_KEY` from `steps.nuget-login.outputs.NUGET_API_KEY` immediately before the push. |
| GitHub Packages publish fails after migration | The fallback API-key path or `packages: write` permission was removed | Retain an explicit API-key authentication path for `github` and custom servers. |

## Security Notes

- Trusted publishing eliminates a long-lived NuGet.org publishing secret and replaces it with a short-lived, job-scoped key.
- Use the narrowest possible trusted-publishing policy: one repository and one entry workflow per policy.
- Do not add an unneeded GitHub Actions environment. If one is used, include its name in the NuGet.org policy to bind the
  credential to that environment.
- Pin third-party actions such as `NuGet/login` to a full commit SHA once the migration is implemented. A mutable major tag is
  convenient during exploration but weakens the supply-chain boundary trusted publishing is intended to improve.
- `RELEASE_PAT` remains high-value because it bypasses branch protection. Keep it fine-grained, repository-scoped, short-
  lived, and assigned to a ruleset bypass actor only where necessary.

## References

- [NuGet.org trusted publishing](https://learn.microsoft.com/en-us/nuget/nuget-org/trusted-publishing)
- [NuGet/login GitHub Action](https://github.com/NuGet/login)
- [GitHub Actions reusable workflows](https://docs.github.com/en/actions/how-tos/sharing-automations/reusing-workflows)
