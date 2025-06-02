# GitHub Actions Workflow Optimization Guide

## Current Issue
The `generate-xcode-project` workflow is taking approximately 20 minutes to complete, with the majority of time (18 minutes) spent on the "Install bootstrap mint" step.

## Implemented Optimizations

### 1. Direct Mint Binary Caching
Instead of using the `setup-mint` action, we now:
- Cache the mint binary directly at `/usr/local/bin/mint`
- Install mint via Homebrew only if not cached
- This avoids potential overhead from the setup action

### 2. Improved Mint Packages Caching
- Cache the `~/.mint` directory separately
- Use content-based cache keys with `hashFiles('**/Mintfile')`
- Added version suffix (`-v2`) to cache key for cache busting when needed

### 3. Timeout Protection
- Added `timeout-minutes: 10` to the mint bootstrap step
- Prevents the job from hanging indefinitely

### 4. Using `--link` Flag
- Added `--link` flag to `mint bootstrap` command
- Creates symlinks instead of copying binaries, which is faster

## Additional Optimization Strategies

### 1. Pre-built Docker Image
Consider creating a custom Docker image with mint and dependencies pre-installed:
```yaml
runs-on: ubuntu-latest
container:
  image: your-org/ios-build-image:latest
```

### 2. Self-hosted Runners
For frequently run workflows, consider using self-hosted runners with pre-installed dependencies.

### 3. Parallel Installation
If you have multiple independent dependencies, install them in parallel:
```yaml
- name: Install dependencies
  run: |
    mint install realm/SwiftLint@0.53.0 &
    mint install yonaskolb/xcodegen@2.38.0 &
    mint install bloomberg/xcdiff@0.11.0 &
    wait
```

### 4. Conditional Execution
Only run the workflow when necessary:
```yaml
on:
  push:
    paths:
      - '**/*.swift'
      - '**/project.yml'
      - '**/Mintfile'
```

### 5. Cache Warming
Create a scheduled workflow to warm caches:
```yaml
on:
  schedule:
    - cron: '0 0 * * 0' # Weekly
```

## Monitoring Performance

Add timing information to track improvements:
```yaml
- name: Bootstrap mint packages
  run: |
    echo "::group::Mint Bootstrap Timing"
    time mint bootstrap --link
    echo "::endgroup::"
```

## Expected Results
With these optimizations, the workflow should complete in:
- First run: ~5-10 minutes (building caches)
- Subsequent runs: ~2-3 minutes (using caches)

## Troubleshooting

### Cache Misses
If caches are frequently missing:
1. Check cache key stability
2. Verify runner OS consistency
3. Monitor cache size limits (10GB per repository)

### Slow Network
If downloads are slow:
1. Consider using GitHub's package registry
2. Use a CDN for binary distribution
3. Implement retry logic with exponential backoff 