# Troubleshooting Guide

Common issues and solutions based on real-world usage.

## Claude Automation Issues

### Claude creates branches but no PRs
**Root Cause**: Missing critical GitHub Actions configuration  
**Solution**: Verify both parameters are present in `.github/workflows/claude.yml`:
```yaml
github_token: ${{ secrets.GITHUB_TOKEN }}
allowed_tools: "mcp__github__create_pull_request,..."
```

### Workflow shows success but nothing happens
**Root Cause**: GitHub Actions success ≠ feature working  
**Solution**: Always verify end-to-end functionality by checking:
- Branch was created
- PR was actually created (not just "Create PR" link)
- PR has proper title and "Fixes #XXX" format

### @claude mentions don't trigger workflow
**Root Cause**: Usually missing GitHub app installation or ANTHROPIC_API_KEY secret  
**Solution**: 
1. **Install Claude Code GitHub Actions app**: https://github.com/marketplace/claude-code
2. **Check ANTHROPIC_API_KEY secret**: GitHub repository settings → Secrets and variables → Actions

## Quality Gate Failures

### ESLint fails with telemetry warnings
**Problem**: Next.js telemetry messages contain "warning" text  
**Root Cause**: Simple grep pattern catches telemetry messages  
**Solution**: Use specific grep pattern in pre-commit.yml:
```bash
# Bad (catches telemetry)
if grep -q "warning" eslint-output.txt; then

# Good (catches only ESLint warnings)  
if grep -E "warning\s+.*\s+eslint" eslint-output.txt; then
```

### Coverage reports not found
**Problem**: Jest coverage not generating properly  
**Common Causes**:
- Missing `jest.config.js` file
- Incorrect test file patterns
- Missing `@testing-library/jest-dom` setup

**Solution**: Verify jest configuration and test setup files exist

### TypeScript errors in strict mode
**Problem**: Existing code doesn't pass TypeScript strict mode  
**Solution**: Either fix TypeScript errors or temporarily adjust strictness in `tsconfig.json`

## Deployment Issues

### Vercel deployments not triggering
**Root Cause**: Git commit author email must match Vercel account email  
**Solution**: 
```bash
# Check current email
git config user.email

# Update to match Vercel account
git config user.email "your-vercel-email@domain.com"

# Force new commit with correct author
git commit --allow-empty -m "Deploy with correct author"
git push origin main
```

### Package lock mismatch errors
**Problem**: package-lock.json not updated after adding dependencies  
**Solution**: Always run `npm install` locally after editing package.json

## Setup Issues

### Claude workspace deployment fails
**Problem**: Network issues or repository access  
**Solution**: Manual deployment:
```bash
git clone https://github.com/dbmcco/claude-workspace.git temp-workspace
cp -r temp-workspace/./ .claude/
rm -rf temp-workspace
```

### Missing project type in CLAUDE.md
**Problem**: `[REPLACE-WITH-PROJECT-TYPE]` not updated  
**Solution**: Edit CLAUDE.md and choose appropriate project type:
- `personal.md` - Full-stack apps, finance tools
- `work.md` - Enterprise, compliance-focused
- `experiments.md` - AI research, prototypes  
- `lightforge.md` - Micro-applications

## GitHub Repository Issues

### Template repository not working
**Problem**: "Use this template" button issues  
**Solution**: Manual setup:
```bash
gh repo create your-project --public
git clone https://github.com/YOUR_USERNAME/your-project.git
cd your-project
# Copy files from template manually
```

### Branch protection not working
**Problem**: Repository settings override workflow protection  
**Solution**: Check repository Settings → Branches for conflicting rules

## Common Error Messages

### "ANTHROPIC_API_KEY is required"
Add the secret to GitHub repository settings.

### "github_token permission denied"
Verify repository has Actions enabled and permissions are correct.

### "No files changed" on quality gates
Usually means no source files to check - ensure you have actual code files.

## Getting Help

If you encounter issues not covered here:

1. Check the MoneyCommand repository for working examples
2. Review the claude-workspace documentation
3. Create an issue in the github-tdd-template repository

Remember: This is a work in progress and not everything works consistently!