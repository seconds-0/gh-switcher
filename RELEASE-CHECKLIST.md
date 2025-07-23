# Release Checklist

Use this checklist before publishing to npm.

## Pre-Release Checks

- [ ] All tests passing locally (`npm test`)
- [ ] Linting passes (`npm run lint`)
- [ ] CI checks passing on GitHub
- [ ] README.md is accurate and up-to-date
- [ ] CHANGELOG.md updated with new changes
- [ ] Version in package.json is correct
- [ ] No sensitive data in code (CLAUDE.md, etc.)
- [ ] Package contents verified (`npm pack --dry-run`)

## Release Process

1. **When ready to release from develop**:
   ```bash
   # Make sure develop is clean
   git checkout develop
   git pull
   npm run ci-check
   
   # Create PR: develop → main on GitHub
   ```

2. **After PR is merged, publish from main**:
   ```bash
   git checkout main
   git pull origin main
   
   # Publish to npm
   npm publish
   
   # Tag the release
   git tag v0.1.0
   git push origin v0.1.0
   ```

4. **Update develop branch**:
   ```bash
   git checkout develop
   git pull origin develop
   git merge main
   git push origin develop
   ```

5. **Clean up**:
   ```bash
   # Delete local release branch
   git branch -d release/v0.1.0
   
   # Delete remote release branch (optional)
   git push origin --delete release/v0.1.0
   ```

## Post-Release

- [ ] Verify package on npmjs.com
- [ ] Test installation: `npm install -g gh-switcher`
- [ ] Create GitHub release with changelog
- [ ] Tweet/announce if desired

## Version Bumping for Next Release

After release, bump version in develop for next iteration:
```bash
git checkout develop
npm version preminor --preid=dev --no-git-tag-version
git add package.json package-lock.json
git commit -m "chore: bump version for next development cycle"
git push origin develop
```