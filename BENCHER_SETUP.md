# Bencher.dev Integration Guide

## Overview

This integration replaces the manual baseline artifact management with Bencher.dev's automated benchmark tracking and analysis.

## What Changed

### Removed Complexity

- ❌ No more downloading/uploading baseline artifacts
- ❌ No more manual baseline comparison logic
- ❌ No more `download-artifact.sh` script
- ❌ No more `force-new-baseline` workflow logic

### Added Capabilities

- ✅ Automatic historical tracking of all benchmark runs
- ✅ Statistical analysis (not just simple mean comparison)
- ✅ Web dashboard with trends and graphs
- ✅ Automatic PR comments with benchmark results
- ✅ Multi-dimensional analysis (testbed, branch, etc.)

## Setup Steps

### 1. Add Bencher API Token to GitHub Secrets

1. Go to [Bencher Tokens](https://bencher.dev/console/users/tokens)
2. Create a new API token (or use existing)
3. In your GitHub repo: Settings → Secrets and variables → Actions
4. Create new secret: `BENCHER_API_TOKEN` = `<your-token>`

### 2. Configure Bencher Project

You mentioned you already have:

- ✅ Account created
- ✅ Project: `vm2.DevOps`
- ✅ API token

Now configure thresholds in Bencher:

```bash
# Install Bencher CLI locally (optional, for setup)
cargo install bencher_cli

# Or use the web interface at https://bencher.dev/console/projects/vm2.DevOps
```

#### Create a Threshold via Web UI

1. Go to [Bencher Thresholds](https://bencher.dev/console/projects/vm2.DevOps/thresholds)
2. Click "Create Threshold"
3. Configure:
   - **Branch**: `main` (or `*` for all branches)
   - **Testbed**: `ubuntu-latest` (or match your OS inputs)
   - **Measure**: `latency` (or appropriate measure from BenchmarkDotNet)
   - **Test**: `percentage`
   - **Upper Boundary**: `10.0` (10% regression threshold)
   - **Lower Boundary**: Leave empty (or set if you want to catch improvements too)

### 3. Update CI Workflow

In `.github/workflows/_ci.yaml`, change the benchmarks job to use the new workflow:

```yaml
benchmarks:
  name: Benchmarks
  if: ${{ fromJSON(needs.setup.outputs.benchmark-projects) != '' }}
  needs:
    - setup
    - build
  strategy:
    matrix:
      os: ${{ fromJSON(inputs.os) }}
      benchmark-project: ${{ fromJSON(inputs.benchmark-projects) }}
  uses: ./.github/workflows/_benchmarks-bencher.yaml  # Changed!
  secrets: inherit  # Required for BENCHER_API_TOKEN
  with:
    os: ${{ matrix.os }}
    dotnet-version: ${{ needs.setup.outputs.dotnet-version }}
    configuration: ${{ needs.setup.outputs.configuration }}
    preprocessor-symbols: ${{ needs.setup.outputs.preprocessor-symbols }}
    benchmark-project: ${{ matrix.benchmark-project }}
    max-regression-pct: ${{ fromJSON(needs.setup.outputs.max-regression-pct) }}
    cached-dependencies: ${{ fromJSON(inputs.cached-dependencies) }}
    cached-artifacts: ${{ fromJSON(inputs.cached-artifacts) }}
    verbose: ${{ fromJSON(needs.setup.outputs.verbose) }}
```

### 4. Remove Old Inputs (Optional)

In `_ci.yaml` and `Glob.Api.CI.yaml`, you can remove:

- `force-new-baseline` input (no longer needed)

## How It Works

### Workflow Flow

1. **Build** → Cached build artifacts from build job
2. **Run Benchmarks** → `run-benchmarks-bencher.sh` runs BenchmarkDotNet, exports JSON
3. **Upload to Bencher** → `bencherdev/bencher@main` action:
   - Uploads results to Bencher API
   - Bencher compares against baseline (main branch historical data)
   - Applies threshold rules
   - Returns pass/fail
4. **PR Comment** → If on PR, Bencher comments with results
5. **Artifact Upload** → JSON results uploaded for manual inspection

### Bencher Concepts

- **Project**: `vm2.DevOps` - Your project container
- **Branch**: Git branch name (e.g., `main`, `feature/xyz`)
- **Testbed**: Runner OS (e.g., `ubuntu-latest`, `windows-latest`)
- **Benchmark**: Individual test from BenchmarkDotNet
- **Measure**: Metric type (latency, throughput, memory, etc.)
- **Threshold**: Pass/fail rules per branch/testbed

### Baseline Logic

- Bencher automatically uses historical data from the **same branch** as baseline
- For PRs, it compares against the **target branch** (e.g., `main`)
- No manual baseline management needed!

## Testing

### Local Testing (Optional)

```bash
# Install Bencher CLI
cargo install bencher_cli
# or
curl --proto '=https' --tlsv1.2 -sSfL https://bencher.dev/install.sh | sh

# Run benchmarks locally
./scripts/bash/run-benchmarks-bencher.sh \
    ./benchmarks/Glob.Api.Benchmarks/Glob.Api.Benchmarks.csproj \
    --configuration Release

# Upload to Bencher manually
bencher run \
    --project vm2.DevOps \
    --token "$BENCHER_API_TOKEN" \
    --branch main \
    --testbed local \
    --adapter json \
    --file ./BmArtifacts/results/*-report.json
```

### First CI Run

1. Push changes to a feature branch
2. First run will **create the baseline** (won't fail)
3. Subsequent runs will compare against this baseline
4. Check results at: <https://bencher.dev/console/projects/vm2.DevOps>

## Migration Path

### Phase 1: Parallel Running (Recommended)

Keep both workflows running in parallel:

- `_benchmarks.yaml` → Old way (with baseline artifacts)
- `_benchmarks-bencher.yaml` → New way (with Bencher)

This allows you to:

1. Verify Bencher results match your expectations
1. Build up historical data in Bencher
1. Get comfortable with the new workflow

### Phase 2: Switch Over

After you're confident:

1. Update `_ci.yaml` to use `_benchmarks-bencher.yaml`
2. Delete/archive old files:
   - `_benchmarks.yaml`
   - `run-benchmarks.sh`
   - `download-artifact.sh`
   - `download-artifact.utils.sh`
   - `download-artifact.usage.sh`

## Troubleshooting

### Bencher Action Fails

- Check API token is set correctly in GitHub secrets
- Verify project name is `vm2.DevOps` (case-sensitive)
- Check JSON files are being generated in results directory

### No Baseline to Compare Against

- First run on a new branch creates baseline (won't fail)
- Ensure `main` branch has been run at least once
- Check Bencher web UI for historical data

### Threshold Too Strict/Loose

- Adjust threshold in Bencher web UI
- Changes take effect immediately (no code changes needed)
- Can have different thresholds per branch/testbed

## Benefits Summary

| Old Way                   | New Way (Bencher)             |
|---------------------------|-------------------------------|
| Manual baseline artifacts | Automatic historical tracking |
| Simple mean comparison    | Statistical analysis          |
| Local threshold logic     | Centralized threshold config  |
| No visualization          | Rich web dashboard            |
| No PR integration         | Automatic PR comments         |
| Binary pass/fail          | Detailed regression analysis  |
| Manual baseline updates   | Automatic baseline evolution  |

## Next Steps

1. ✅ Add `BENCHER_API_TOKEN` to GitHub secrets
2. ✅ Configure thresholds in Bencher web UI
3. ✅ Update `_ci.yaml` to use new workflow
4. ✅ Test on a feature branch
5. ✅ Review results in Bencher dashboard
6. ✅ (Optional) Clean up old benchmark files

## Resources

- Bencher Documentation: <https://bencher.dev/docs>
- Your Project Dashboard: <https://bencher.dev/console/projects/vm2.DevOps>
- GitHub Action: <https://github.com/bencherdev/bencher>
- BenchmarkDotNet Adapter: <https://bencher.dev/docs/explanation/adapters#-benchmarkdotnet>
