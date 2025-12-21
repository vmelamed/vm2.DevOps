# PR Gates and Checks Setup Guide

## Overview

This repository now has GitHub Checks integrated for tests and benchmarks that can be used as PR merge gates.

## What Was Added

### 1. Test Workflow Enhancements

See [_test.yaml](.github/workflows/_test.yaml)

**Added permissions:**

```yaml
permissions:
  contents: read
  checks: write # Creates test result checks
  pull-requests: write # Adds PR comments with results
```

**Added step:**

- **Publish test results** - Creates GitHub Check and PR comments with:
  - Test pass/fail status
  - Failed test details
  - Comparison to previous runs
  - Individual test run reports

### 2. Benchmark Workflow Enhancements

See [_benchmarks-bencher.yaml](.github/workflows/_benchmarks-bencher.yaml)

**Added permissions:**

```yaml
permissions:
  contents: read
  checks: write # Creates Bencher checks
  pull-requests: write # Adds PR comments with benchmark results
```

**Bencher features:**

- Creates GitHub Check with pass/fail based on thresholds
- Posts PR comment with benchmark comparison table
- Shows performance regressions/improvements
- Links to detailed Bencher dashboard

## GitHub Check Names

When setting up branch protection rules, you'll need these check names.

### From Glob.Api.CI workflow

1. **Setup Job:** `Parameters validation / get-params`
2. **Build Job:** `Build / build (ubuntu-latest)` (or other OS)
3. **Test Jobs (per test project per OS):**
   - `Tests / test (ubuntu-latest, test/Glob.Api.Tests/Glob.Api.Tests.csproj)`
   - `Tests / test (ubuntu-latest, test/Glob.Api.FakeFileSystem.Tests/Glob.Api.FakeFileSystem.Tests.csproj)`
   - **Test Result Checks:**
     - `Test Results (Glob.Api.Tests on ubuntu-latest)`
     - `Test Results (Glob.Api.FakeFileSystem.Tests on ubuntu-latest)`
4. **Benchmark Job:**
   - `Benchmarks / benchmarks (ubuntu-latest, benchmarks/Glob.Api.Benchmarks/Glob.Api.Benchmarks.csproj)`
   - **Bencher Check:** Will appear as `Bencher` or similar

## Setting Up Branch Protection Rules

### Step 1: Go to Repository Settings

1. Navigate to your repository on GitHub
2. Click **Settings** tab
3. Click **Branches** in the left sidebar
4. Find **Branch protection rules** section
5. Click **Add rule** or edit existing rule for `main`

### Step 2: Configure Protection for `main`

**Branch name pattern:** `main`

**Recommended settings:**

```text
☑ Require a pull request before merging
  ☑ Require approvals (optional, based on your workflow)

☑ Require status checks to pass before merging
  ☑ Require branches to be up to date before merging

  Search for and add these checks:
  ☑ Build / build (ubuntu-latest)
  ☑ Tests / test (ubuntu-latest, test/Glob.Api.Tests/Glob.Api.Tests.csproj)
  ☑ Tests / test (ubuntu-latest, test/Glob.Api.FakeFileSystem.Tests/Glob.Api.FakeFileSystem.Tests.csproj)
  ☑ Test Results (Glob.Api.Tests on ubuntu-latest)
  ☑ Test Results (Glob.Api.FakeFileSystem.Tests on ubuntu-latest)
  ☑ Benchmarks / benchmarks (ubuntu-latest, ...)

☑ Do not allow bypassing the above settings (optional, stricter)
```

### Step 3: Save

Click **Create** or **Save changes**

## How It Works

### On Push to Feature Branch

1. **CI runs** automatically
2. **Checks appear** on commit
3. **No PR comment** (only on PRs)
4. **Fast feedback** during development

### On Pull Request

1. **CI runs** on PR
2. **Checks appear** in PR "Checks" tab
3. **Comments posted** with:
   - Test results summary
   - Benchmark comparison table
   - Links to detailed reports
4. **Merge button** shows check status:
   - All checks passed - can merge
   - Checks failed - blocked (if required)
   - Checks pending - wait

### When Checks Fail

**Tests:**

- Check fails if any test fails
- PR comment shows which tests failed
- Click check for detailed logs

**Benchmarks:**

- Check fails if regression exceeds threshold (10% by default)
- PR comment shows performance comparison
- Links to Bencher dashboard for analysis

## Finding Check Names

If you cannot find the exact check names.

### Method 1: Run Workflow Once

1. Create a test PR
2. Let workflow run
3. Go to PR and click **Checks** tab
4. See all check names listed there
5. Use those exact names in branch protection

### Method 2: Look at Recent Runs

1. Go to **Actions** tab
2. Click on a recent workflow run
3. See job names in left sidebar
4. Format: `<Job Display Name> / <job-id> (<matrix values>)`

### Method 3: Check Workflow Files

Look for `name:` fields under `jobs:` in workflow YAML files.

## Customization

### Adjust Test Report Behavior

Edit [_test.yaml](.github/workflows/_test.yaml), line ~193:

```yaml
- name: Publish test results
  uses: EnricoMi/publish-unit-test-result-action@v2
  with:
    check_name: Test Results (...)  # Customize check name
    comment_mode: always  # Options: always, off, failures, changes
    compare_to_earlier_commit: true  # Show comparison
    report_individual_runs: true  # Individual test details
```

### Adjust Benchmark Thresholds

Edit [Glob.Api.CI.yaml](.github/workflows/Glob.Api.CI.yaml), line ~100+:

```bash
# In get-params job, change default
max-regression-pct="10"  # Change to desired threshold
```

Or override when manually triggering via workflow_dispatch.

### Disable PR Comments

If you only want checks, not comments.

**Tests:**

```yaml
comment_mode: off  # In _test.yaml
```

**Benchmarks:**

Remove `--github-actions` flag from bencher command (not recommended).

## Troubleshooting

### Checks Not Appearing

**Possible causes:**

1. **Permissions missing** - Check `permissions:` section has `checks: write`
2. **Workflow not on base branch** - Checks only work if workflow exists on target branch (`main`)
3. **First run** - May take one run to register checks

**Solution:** Merge this PR to `main` first, then checks will work on future PRs.

### PR Comments Not Posting

**Possible causes:**

1. **Permissions missing** - Check `pull-requests: write` permission
2. **Not a PR event** - Comments only appear on PRs, not direct pushes
3. **Token issue** - Ensure `GITHUB_TOKEN` is passed correctly

### Cannot Find Check in Branch Protection

**Wait for first run:**

- GitHub only shows checks that have run at least once
- Create a test PR and let it run
- Then the check will appear in the branch protection search

## Benefits

- **Automated quality gates** - No manual review needed for basic failures
- **Visible progress** - See check status directly in PR
- **Clear feedback** - Comments explain what failed
- **Prevent regressions** - Block merging if benchmarks degrade
- **Historical tracking** - Bencher tracks all benchmark history
- **Developer friendly** - Fast feedback on every push

## Next Steps

1. **Merge this PR** to get workflows on `main` branch
2. **Set up branch protection** following guide above
3. **Test with a new PR** to verify checks work
4. **Monitor Bencher dashboard** at <https://bencher.dev/console/projects/vm2-devops>
5. **Adjust thresholds** as needed based on real data

## Resources

- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Bencher Documentation](https://bencher.dev/docs/)
- [EnricoMi/publish-unit-test-result-action](https://github.com/EnricoMi/publish-unit-test-result-action)
- [Codecov](<https://app.codecov.io/gh/${{> github.repository }})
