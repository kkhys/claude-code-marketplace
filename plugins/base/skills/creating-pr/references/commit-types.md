# Conventional Commits Types

## Type Selection Guidelines

Analyze the changes and select the most appropriate type based on the primary purpose of the changes.

### Types

**feat**: New feature or functionality
- Adding new endpoints, components, or capabilities
- Implementing user-facing features
- Adding new configuration options or settings
- Example: "Add user authentication system", "Add dark mode support"

**fix**: Bug fixes
- Fixing crashes, errors, or incorrect behavior
- Resolving issues reported by users or tests
- Correcting logic errors
- Example: "Fix null pointer exception in login", "Fix incorrect calculation"

**chore**: Maintenance tasks without code changes
- Dependency updates
- Build configuration changes
- CI/CD pipeline updates
- Tooling configuration
- Example: "Update dependencies", "Configure ESLint", "Update .gitignore"

**docs**: Documentation only
- README updates
- API documentation
- Code comments (when that's the only change)
- Example: "Update installation guide", "Add API usage examples"

**refactor**: Code restructuring without behavior change
- Code cleanup, reorganization
- Performance improvements without new features
- Renaming variables/functions for clarity
- Example: "Extract validation logic", "Simplify error handling"

**test**: Test additions or modifications
- Adding new test cases
- Fixing broken tests
- Improving test coverage
- Example: "Add unit tests for auth module", "Fix failing integration tests"

**perf**: Performance improvements
- Optimizations that measurably improve performance
- Caching implementations
- Query optimizations
- Example: "Optimize database queries", "Add caching layer"

**style**: Code style/formatting changes
- Formatting changes (indentation, whitespace)
- Linting fixes
- Code style adjustments
- Example: "Format code with Prettier", "Fix linting warnings"

**ci**: CI/CD changes
- GitHub Actions, CircleCI, Travis updates
- Deployment pipeline changes
- Build automation
- Example: "Add automated deployment", "Update CI workflow"

**build**: Build system changes
- Webpack, Rollup, Vite configuration
- Build script modifications
- Package.json scripts
- Example: "Update build configuration", "Add production build script"

**revert**: Reverting previous commits
- Reverting a previous commit
- Example: "Revert 'Add experimental feature'"

## Selection Priority

When changes span multiple types, choose based on this priority:

1. **feat** - If adding any new functionality
2. **fix** - If fixing a bug (even with refactoring)
3. **perf** - If primary goal is performance
4. **refactor** - If restructuring existing code
5. **test** - If only test changes
6. **docs** - If only documentation
7. **chore** - For everything else

## Examples

### Multiple file types
- Added feature + tests → **feat**
- Bug fix + refactoring → **fix**
- Refactor + new tests → **refactor**

### Common scenarios
- Added new API endpoint with tests → **feat**
- Fixed bug and added test for it → **fix**
- Updated dependencies and fixed breaking changes → **chore**
- Reorganized code structure → **refactor**
