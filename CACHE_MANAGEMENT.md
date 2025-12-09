# NuGet Dependency Cache Management Strategy

## Document Purpose

This document outlines strategies to prevent stale NuGet dependency caches in the vm2.DevOps CI/CD pipeline while maintaining build performance. Implement these strategies after the initial CI/CD setup is complete.

## Current State (As of Implementation)

### Existing Cache Configuration

All workflows (`_build.yaml`, `_test.yaml`, `_benchmarks.yaml`) currently use:

    - name: Setup .NET
      uses: actions/setup-dotnet@v5
      with:
        dotnet-version: ${{ inputs.dotnet-version }}
        cache: true
        cache-dependency-path: |+
          **/packages.lock.json
          **/*.csproj

**Current Behavior:**
- ✅ Cache updates when `packages.lock.json` changes
- ✅ Cache updates when any `.csproj` file changes
- ❌ Cache does NOT update if package versions stay the same (even if packages are months old)

## Problem Statement

NuGet package caches can become stale over time, potentially leading to:
- Security vulnerabilities in outdated packages
- Missing bug fixes and performance improvements
- Compatibility issues with newer .NET versions
- Inconsistent behavior between local dev and CI environments

## Recommended Solutions (Multi-Layered Approach)

### Layer 1: Package Lock File (Immediate - High Priority)

**What:** Enforce deterministic package versions using `packages.lock.json`

**Implementation:**

Update `Directory.Build.props`:

    <PropertyGroup>
      <!-- Force generation and validation of packages.lock.json -->
      <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>

      <!-- In CI, fail if lock file is out of date -->
      <RestoreLockedMode Condition="'$(CI)' == 'true'">true</RestoreLockedMode>
    </PropertyGroup>

**Benefits:**
- Ensures exact same package versions across all environments
- CI fails if someone forgets to update lock file
- Clear audit trail of package version changes

**Maintenance:**
- Update lock files: `dotnet restore --force-evaluate`
- Commit updated `packages.lock.json` files

---

### Layer 2: Dependabot (High Priority)

**What:** Automated weekly dependency update PRs

**Implementation:**

Create `.github/dependabot.yml`:

    version: 2
    updates:
      # Update NuGet packages
      - package-ecosystem: "nuget"
        directory: "/"
        schedule:
          interval: "weekly"
          day: "monday"
          time: "09:00"
          timezone: "America/New_York"
        open-pull-requests-limit: 10

        # Group minor and patch updates together
        groups:
          minor-and-patch:
            patterns:
              - "*"
            update-types:
              - "minor"
              - "patch"

        # Review major updates separately
        ignore:
          - dependency-name: "*"
            update-types: ["version-update:semver-major"]

        commit-message:
          prefix: "deps"
          include: "scope"

        # Add reviewers (adjust to your team)
        reviewers:
          - "vmelamed"

        labels:
          - "dependencies"
          - "automated"

      # Also update GitHub Actions
      - package-ecosystem: "github-actions"
        directory: "/"
        schedule:
          interval: "weekly"
        commit-message:
          prefix: "ci"
        labels:
          - "github-actions"
          - "automated"

**Benefits:**
- Automatic PRs for package updates
- Forces cache refresh when PRs are merged
- Security vulnerability alerts
- Zero manual effort

**Maintenance:**
- Review and merge Dependabot PRs weekly
- Configure auto-merge for patch updates (optional)

---

### Layer 3: Time-Based Cache Invalidation (Medium Priority)

**What:** Add weekly rotation to cache keys to force periodic refresh

**Implementation:**

Add to `_build.yaml`, `_test.yaml`, and `_benchmarks.yaml` before "Setup .NET" step:

    - name: Get cache timestamp (weekly rotation)
      id: cache-timestamp
      shell: bash
      run: |
        # Generate cache key based on calendar week
        CACHE_WEEK=$(date +%Y-W%V)
        echo "week=$CACHE_WEEK" >> $GITHUB_OUTPUT
        echo "Cache rotation key: $CACHE_WEEK"

Then optionally add explicit cache with time-based rotation:

    - name: Setup .NET
      uses: actions/setup-dotnet@v5
      with:
        dotnet-version: ${{ inputs.dotnet-version }}
        cache: true
        cache-dependency-path: |+
          **/packages.lock.json
          **/*.csproj

    # Optional: Additional explicit cache with time-based rotation
    - name: Cache NuGet packages (weekly rotation)
      uses: actions/cache@v4
      with:
        path: ~/.nuget/packages
        key: nuget-${{ runner.os }}-${{ steps.cache-timestamp.outputs.week }}-${{ hashFiles('**/packages.lock.json') }}
        restore-keys: |
          nuget-${{ runner.os }}-${{ steps.cache-timestamp.outputs.week }}-
          nuget-${{ runner.os }}-

**Benefits:**
- Guarantees cache refresh at least weekly
- Automatic security vulnerability remediation
- No manual intervention required

**Trade-offs:**
- First build of week will be slower (full package download)
- Subsequent builds in same week use cache (fast)

---

### Layer 4: Cache Age Monitoring (Low Priority - Nice to Have)

**What:** Add warnings when cache contains old packages

**Implementation:**

Add to `_test.yaml` or `_build.yaml` after "Restore dependencies" step:

    - name: Validate dependency freshness
      shell: bash
      run: |
        CACHE_DIR=~/.nuget/packages

        if [ -d "$CACHE_DIR" ]; then
          # Find files older than 60 days
          OLD_FILES=$(find "$CACHE_DIR" -type f -mtime +60 2>/dev/null | wc -l)

          if [ "$OLD_FILES" -gt 10 ]; then
            echo "::warning::NuGet cache contains $OLD_FILES files older than 60 days."
            echo "::warning::Consider updating dependencies or clearing cache."
            echo "📦 Cache age warning: $OLD_FILES files > 60 days old" >> $GITHUB_STEP_SUMMARY
          else
            echo "✅ NuGet cache is relatively fresh (< 60 days old)"
            echo "✅ Cache freshness: OK" >> $GITHUB_STEP_SUMMARY
          fi
        fi

**Benefits:**
- Visibility into cache staleness
- Proactive warning before problems occur
- No impact on build performance

---

### Layer 5: Manual Cache Clear Workflow (Low Priority - Emergency Use)

**What:** On-demand workflow to clear all NuGet caches

**Implementation:**

Create `.github/workflows/clear-cache.yaml`:

    name: Clear NuGet Cache

    on:
      workflow_dispatch:
        inputs:
          reason:
            description: 'Reason for clearing cache'
            required: true
            type: string
          cache-pattern:
            description: 'Cache key pattern to delete (default: nuget-*)'
            required: false
            type: string
            default: 'nuget-'

    permissions:
      actions: write

    jobs:
      clear-cache:
        name: Clear NuGet Cache
        runs-on: ubuntu-latest
        steps:
          - name: Checkout
            uses: actions/checkout@v6

          - name: Delete matching caches
            shell: bash
            env:
              GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
              CACHE_PATTERN: ${{ inputs.cache-pattern }}
              REASON: ${{ inputs.reason }}
            run: |
              echo "Clearing caches matching pattern: $CACHE_PATTERN"
              echo "Reason: $REASON"
              echo ""

              # List all caches
              echo "Current caches:"
              gh cache list --repo ${{ github.repository }}
              echo ""

              # Delete matching caches
              DELETED=0
              gh cache list --repo ${{ github.repository }} | \
                grep "$CACHE_PATTERN" | \
                awk '{print $1}' | \
                while read cache_id; do
                  echo "Deleting cache: $cache_id"
                  gh cache delete "$cache_id" --repo ${{ github.repository }} || true
                  DELETED=$((DELETED + 1))
                done

              echo ""
              echo "✅ Cleared $DELETED cache(s) matching pattern: $CACHE_PATTERN"

              {
                echo "## Cache Cleanup Summary"
                echo ""
                echo "- **Pattern:** \`$CACHE_PATTERN\`"
                echo "- **Reason:** $REASON"
                echo "- **Caches deleted:** $DELETED"
                echo ""
                echo "Next builds will download fresh packages."
              } >> $GITHUB_STEP_SUMMARY

**Usage:**
1. Go to Actions tab in GitHub
2. Select "Clear NuGet Cache" workflow
3. Click "Run workflow"
4. Enter reason for cache clear
5. Click "Run workflow" button

**Benefits:**
- Emergency cache invalidation when needed
- Useful after major package updates
- Helpful for debugging cache-related issues

---

### Layer 6: Scheduled Cache Cleanup (Optional - Advanced)

**What:** Automatically delete caches older than a threshold

**Implementation:**

Create `.github/workflows/cache-cleanup-scheduled.yaml`:

    name: Scheduled Cache Cleanup

    on:
      schedule:
        # Run every Sunday at 2 AM UTC
        - cron: '0 2 * * 0'
      workflow_dispatch:

    permissions:
      actions: write

    jobs:
      cleanup:
        name: Clean old caches
        runs-on: ubuntu-latest
        steps:
          - name: Checkout
            uses: actions/checkout@v6

          - name: Cleanup caches older than 7 days
            shell: bash
            env:
              GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
            run: |
              echo "Cleaning up caches older than 7 days..."
              DELETED=0

              # Get all caches
              gh cache list --repo ${{ github.repository }} --limit 100 --json id,key,createdAt | \
                jq -r '.[] | [.id, .key, .createdAt] | @tsv' | \
                while IFS=$'\t' read -r cache_id cache_key created_at; do
                  # Calculate age in days
                  created_epoch=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" +%s)
                  now_epoch=$(date +%s)
                  age_days=$(( (now_epoch - created_epoch) / 86400 ))

                  if [ "$age_days" -gt 7 ]; then
                    echo "Deleting cache (age: ${age_days}d): $cache_key"
                    gh cache delete "$cache_id" --repo ${{ github.repository }} || true
                    DELETED=$((DELETED + 1))
                  fi
                done

              echo "✅ Deleted $DELETED cache(s) older than 7 days"

              {
                echo "## Scheduled Cache Cleanup"
                echo ""
                echo "- **Threshold:** 7 days"
                echo "- **Caches deleted:** $DELETED"
                echo "- **Run date:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
              } >> $GITHUB_STEP_SUMMARY

**Benefits:**
- Automatic housekeeping
- Prevents cache bloat (10GB repo limit)
- Ensures regular cache refresh

**Considerations:**
- May slow down first build after cleanup
- Adjust age threshold based on needs (7, 14, or 30 days)

---

## Implementation Roadmap

### Phase 1: Immediate (Do After CI/CD Setup Complete)

1. ✅ Add `RestorePackagesWithLockFile` to `Directory.Build.props`
2. ✅ Generate `packages.lock.json` files: `dotnet restore --force-evaluate`
3. ✅ Commit all `packages.lock.json` files
4. ✅ Test CI pipeline with locked mode

### Phase 2: Week 1

1. ✅ Create `.github/dependabot.yml`
2. ✅ Merge initial Dependabot PRs
3. ✅ Establish PR review process for dependency updates

### Phase 3: Week 2

1. ✅ Add time-based cache invalidation to workflows
2. ✅ Add cache age monitoring step
3. ✅ Monitor first weekly cache rotation

### Phase 4: Month 1 (Optional)

1. ⚠️ Create manual cache clear workflow
2. ⚠️ Create scheduled cleanup workflow (if needed)
3. ⚠️ Document procedures in team wiki

## Monitoring and Maintenance

### Weekly Tasks

- Review and merge Dependabot PRs
- Check for failed builds due to dependency issues
- Monitor cache hit rates in workflow logs

### Monthly Tasks

- Review cache size in repository settings
- Audit package versions for security vulnerabilities
- Update dependency update schedule if needed

### Quarterly Tasks

- Review effectiveness of cache strategy
- Adjust cache rotation period if needed
- Update this document based on lessons learned

## Troubleshooting

### Problem: Builds failing with "restore failed in locked mode"

**Cause:** `packages.lock.json` is out of date

**Solution:**

    # Update lock files
    dotnet restore --force-evaluate

    # Commit changes
    git add **/packages.lock.json
    git commit -m "deps: update package lock files"

### Problem: Cache size approaching 10GB limit

**Cause:** Too many old caches accumulating

**Solution:**
1. Run manual cache clear workflow
2. Implement scheduled cleanup workflow
3. Reduce cache retention period

### Problem: Dependabot PRs failing tests

**Cause:** Breaking changes in package updates

**Solution:**
1. Review changelog for breaking changes
2. Update code to handle breaking changes
3. Consider pinning major version in `.csproj`

### Problem: Build slower than expected

**Cause:** Cache miss or cache invalidation

**Solution:**
1. Check if weekly rotation just occurred
2. Verify cache hit rate in workflow logs
3. Ensure `packages.lock.json` hasn't changed unnecessarily

## References

- [GitHub Actions Caching Documentation](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [NuGet Package Lock Files](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#locking-dependencies)
- [.NET Restore Command](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-restore)

## Document Metadata

- **Created:** December 2025
- **Author:** GitHub Copilot (for vm2.DevOps project)
- **Version:** 1.0
- **Status:** Draft - For Implementation After CI/CD Setup

---

**NEXT STEPS:** Save this document as `docs/ci-cd/dependency-cache-management.md` for future reference.