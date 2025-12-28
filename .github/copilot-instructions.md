# OpenProject Coding Agent Instructions

## Repository Overview

**OpenProject** is a web-based, open-source project management software written in Ruby on Rails. It uses PostgreSQL for data persistence and supports features like project planning, task management, Agile/Scrum, time tracking, wikis, and forums.

- **Size**: Large monorepo (~840MB, ~1M+ lines of code)
- **History**: Originally forked from Redmine over a decade ago, evolved significantly as an independent project
- **Backend**: Ruby 3.4.5, Rails ~8.0.3
- **Frontend**: Node.js 22.21.0, npm 10.1.0+, TypeScript
- **Database**: PostgreSQL (required)
- **Architecture**: Server-rendered HTML with Hotwire (Turbo + Stimulus). Legacy Angular components exist and are being migrated to custom elements. Uses GitHub's Primer Design System via ViewComponent.
- **Editions**: OpenProject comes in Community and Enterprise editions
  - **Enterprise Edition**: Includes additional features like Single sign-on (OIDC & SAML), LDAP, Nextcloud integration, SCIM API, and more (requires token for development)
  - **BIM Edition**: Tailored for construction industry needs. Code in `modules/bim/`, docs in `docs/bim-guide/`. Existing instances can be switched to BIM edition.

## Critical Setup Requirements

### Ruby and Node Versions
**ALWAYS verify versions before building:**
- Ruby: `3.4.5` (see `.ruby-version`)
- Node: `^22.21.0` (see `package.json` engines)
- Bundler: Latest 2.x

### Development Environment Options

**Docker (Recommended for Quick Start)**
```bash
# ALWAYS run these commands in sequence:
cp .env.example .env
cp docker-compose.override.example.yml docker-compose.override.yml
docker compose run --rm backend setup
docker compose run --rm frontend npm install
docker compose up -d backend
# Access at http://localhost:3000
```

**Local Development Setup**
```bash
# Install dependencies (ALWAYS run in this order):
bundle install                    # Install Ruby gems
cd frontend && npm ci && cd ..   # Install Node packages (use 'ci' not 'install' for reproducibility)
bundle exec rake db:migrate      # Setup database
bundle exec rails openproject:plugins:register_frontend assets:export_locales

# Start services (use bin/dev for all-in-one):
bin/dev                          # Starts Rails, frontend dev server, and Good Job worker
# OR manually:
# Terminal 1: bundle exec rails server
# Terminal 2: npm run serve
# Terminal 3: bundle exec good_job start
```

**Important**: The `config/database.yml` file MUST NOT exist when using Docker. Delete or rename it if present.

## Building and Testing

### Linting (Run Before Committing)

**Ruby (Rubocop)**
```bash
bundle exec rubocop                          # Check all files
bin/dirty-rubocop --uncommitted              # Check only uncommitted changes
bin/dirty-rubocop --uncommitted --force-exclusion {files}  # Check specific files
```

**JavaScript/TypeScript (ESLint)**
```bash
cd frontend
npx eslint src/                              # Lint all frontend code
cd ..
```

**ERB Templates (erb_lint)**
```bash
erb_lint {files}                             # Lint ERB template files
```

**Install Git Hooks** (optional but recommended):
```bash
bundle exec lefthook install                 # Sets up pre-commit hooks for linting
```

### Running Tests

**Backend Tests (RSpec)**
```bash
# Run specific tests (ALWAYS preferred over running all tests):
bundle exec rspec spec/models/user_spec.rb              # Single file
bundle exec rspec spec/models/user_spec.rb:42           # Single line
bundle exec rspec spec/features                         # Directory

# Run all tests (slow, ~40 minutes on CI):
bundle exec rspec

# Parallel execution (faster):
bundle exec rake parallel:spec

# With Docker:
docker compose run --rm backend-test "bundle exec rspec spec/features/work_package_show_spec.rb"
```

**Frontend Tests (Jasmine/Karma)**
```bash
cd frontend
npm test                                     # Run all frontend unit tests
npm run test:ci                             # Run in CI mode (single run)
cd ..
```

**Debugging Failed GitHub Actions Tests**
```bash
# Extract and run all failed tests from CI:
./script/github_pr_errors
./script/github_pr_errors | xargs bundle exec rspec

# Run flaky tests multiple times:
./script/bulk_run_rspec spec/path/to/flaky_spec.rb
```

### Running the Application Locally

**Development Mode**
```bash
bin/dev                                      # Uses Overmind or Foreman to start all services
# Access at http://localhost:3000
```

**Individual Services**
```bash
bundle exec rails server                    # Rails backend (port 3000)
npm run serve                               # Frontend dev server (proxied through Rails)
bundle exec good_job start                  # Background job worker
```

## Project Structure

### Key Directories
- `app/` - Rails application code (models, controllers, services, views, components)
  - `app/components/` - ViewComponent-based UI components (Ruby + ERB)
  - `app/contracts/` - Validation and authorization contracts
  - `app/controllers/` - Rails controllers
  - `app/models/` - ActiveRecord models
  - `app/services/` - Service objects (business logic)
  - `app/workers/` - Background job workers
- `config/` - Rails configuration
  - `config/application.rb` - Application configuration
  - `config/locales/` - I18n translations
  - `config/routes.rb` - Rails routes
- `db/` - Database migrations and seeds
- `docker/` - Docker build contexts
- `frontend/src/` - Frontend
  - `frontend/src/app/` - Angular modules, components, services (legacy Angular code)
  - `frontend/src/main.ts` - Angular Application bootstrap entry point
  - `frontend/src/react` - React components (currently only used for experimental BlockNote integration)
  - `frontend/src/stimulus` - Stimulus controllers, helpers
  - `frontend/src/turbo` - Turbo integration (e.g. custom Turbo Stream actions)
- `lib/` - Ruby libraries and extensions
- `lookbook/` - Lookbook component previews for ViewComponents (see https://github.com/lookbook-hq/lookbook)
- `modules/` - OpenProject plugin modules
- `spec/` - RSpec test suite
  - `spec/features/` - System/feature tests (Capybara)
  - `spec/models/` - Model unit tests
  - `spec/requests/` - API/integration tests
  - `spec/services/` - Service tests

### Configuration Files
- `.erb_lint.yml` - ERB template linting
- `.rubocop.yml` - Ruby linting rules
- `.ruby-version` - Ruby version (check this file for current version)
- `docker-compose.yml` - Docker development environment
- `frontend/eslint.config.mjs` - JavaScript/TypeScript linting
- `Gemfile` / `Gemfile.lock` - Ruby dependencies
- `lefthook.yml` - Git hooks configuration
- `package.json` / `frontend/package.json` - Node.js dependencies
- `Procfile.dev` - Services for `bin/dev`

## GitHub Actions CI/CD

### Main Workflows
- **test-core.yml** - Main test suite (units + features, ~40 min, runs on all PRs)
- **rubocop-core.yml** - Ruby linting (runs on all PRs with Ruby changes)
- **eslint-core.yml** - JS/TS linting (runs on all PRs with JS/TS changes)
- **test-frontend-unit.yml** - Frontend unit tests
- **brakeman-scan-core.yml** - Security scanning
- **codeql-scan-core.yml** - Code quality/security analysis

### CI Requirements for Merge
- All linting checks must pass (Rubocop, ESLint, erb_lint)
- Test suite must be green
- No security vulnerabilities introduced (Brakeman, CodeQL)

**Skip CI**: Add `[ci skip]` to commit message to skip CI (use sparingly).

## Common Issues and Workarounds

### Database Configuration
- **Issue**: Docker fails with "database.yml exists"
- **Fix**: Delete or rename `config/database.yml` when using Docker

### Memory Issues in Docker
- **Issue**: Frontend container exits with status 137
- **Fix**: Increase Docker memory limit to at least 4GB

### Test Failures on CI but Passing Locally
- Run with `CI=true` environment variable (eager loads app)
- Check for `OPENPROJECT_*` environment variables
- Match the random seed: `bundle exec rspec --seed 18352`
- Use `--bisect` to find order-dependent failures
- View browser tests with `OPENPROJECT_TESTING_NO_HEADLESS=1`

### Frontend Build Issues
- **Issue**: "jQuery not defined", frontend asset errors, or blank page
- **Fix**: Run `bin/setup_dev` to rebuild frontend completely

### Parallel Test Failures
- Tests run in parallel on CI with different random seeds per group
- Check `tmp/parallel_runtime.log` for execution times
- **Flaky specs**: Some tests may fail randomly; see `docs/development/running-tests/` for handling flaky tests
  - Use `script/bulk_run_rspec` to run tests multiple times to identify flaky behavior

## Code Style Guidelines

### Ruby
- Follow [Ruby community style guide](https://github.com/bbatsov/ruby-style-guide)
- Use service objects for complex business logic
  - Return results using the `ServiceResult` class (well-documented in codebase)
  - Some services use monads via [dry-monads](https://github.com/dry-rb/dry-monads) for result modeling
- Use contracts for validation and authorization
- Keep controllers thin, models focused
- Document code units and patterns with [YARD](https://yardoc.org/)
- Write tests for all new features (RSpec)
  - Unit tests for models, services, and other components
  - Feature specs use Capybara (with Cuprite and Selenium WebDriver)
  - Feature specs can use A11y selectors ([capybara_accessible_selectors](https://github.com/citizensadvice/capybara_accessible_selectors)), test IDs, or page objects (in `spec/support/pages/`)

### Database Migrations
- Follow Rails migration conventions
- OpenProject implements migration "squashing" between major releases
- See `docs/development/migrations/` for details on the squashing process
- Migrations are consolidated to manage database changes across major versions
- OpenProject does not currently aim for zero downtime migrations

### JavaScript/TypeScript
- **New development**: Use Hotwire (Turbo + Stimulus) with server-rendered HTML
- **Legacy code**: Follow ESLint recommended rules (eslint, typescript-eslint, Angular ESLint)
- Prefer TypeScript over JavaScript
- **Design system**: Use GitHub's [Primer Design System](https://primer.style/product/) via ViewComponent
  - [primer_view_components](https://github.com/opf/primer_view_components) - OpenProject's fork of Primer Rails/ViewComponent
  - [openproject-octicons](https://github.com/opf/openproject-octicons) - OpenProject's fork of Primer Octicons
  - [commonmark-ckeditor-build](https://github.com/opf/commonmark-ckeditor-build) - Custom CKEditor build with CommonMark Markdown support
- Write unit tests for components (Jasmine for legacy Angular, RSpec for ViewComponents)

### Templates
- Use ERB for server-rendered views
- Use ViewComponents for reusable UI components
  - Document new ViewComponents with API/Yard docs and Lookbook previews
  - Lookbook deployed at: https://qa.openproject-edge.com/lookbook/
  - See https://github.com/lookbook-hq/lookbook for Lookbook documentation
- Lint with erb_lint before committing

### Commit Messages
- First line: < 72 characters
- Blank line
- Detailed description wrapped to 72 characters
- Reference work packages when applicable
- See [code review guidelines](docs/development/code-review-guidelines/) for more details
- **Merge strategy**: Use "Merge pull request" (not squash) to retain commit history, except for single-commit PRs which can use "Rebase and merge"

### Translations
- OpenProject is a multilingual product with officially supported and community-supported languages
- UI translations are managed via [Crowdin](https://crowdin.com/)
- Don't modify translation files directly; contributions should go through Crowdin
  - Exception: Source translations in `**/config/locales/en.yml` can be modified directly
- UI strings should never be hard-coded; always use translation keys for accessibility and internationalization

## Performance Considerations

### CI Timeouts
- Main test suite: 40 minutes timeout
- Individual jobs: varies by type
- Use parallel execution when available

### Build Times
- Full Docker build: ~10-15 minutes (first time)
- Bundle install: ~2-5 minutes
- npm install: ~3-7 minutes
- Database setup: ~1-2 minutes
- Asset compilation: ~30-40 seconds

## Important Commands Reference

```bash
# Setup
bin/setup              # Initial Rails setup (creates DB, runs migrations)
bin/setup_dev          # Full dev environment setup (backend + frontend)

# Database
bundle exec rake db:migrate              # Run pending migrations
bundle exec rake db:rollback             # Rollback last migration
bundle exec rake db:seed                 # Seed database with sample data
bundle exec rake db:migrate:status       # Check migration status

# Testing
bundle exec rspec                        # Run RSpec tests
bundle exec rake parallel:spec           # Run tests in parallel
cd frontend && npm test                  # Run frontend tests

# Linting
bundle exec rubocop                      # Ruby linting
cd frontend && npx eslint src/           # JavaScript/TypeScript linting
erb_lint {files}                         # ERB template linting

# Development
bin/dev                                  # Start all services
bundle exec rails console                # Rails console
bundle exec rails routes                 # List all routes

# Docker
bin/compose setup                        # Setup Docker environment
bin/compose start                        # Start Docker services
bin/compose run                          # Run with backend in foreground
bin/compose rspec {test_file}            # Run tests in Docker
```

## Trust These Instructions

These instructions are comprehensive and validated. Only search for additional information if:
1. You encounter an error not documented here
2. You need specific implementation details for a feature
3. The instructions appear outdated (e.g., version mismatches)

For any issues, consult:
- `docs/development/` - Development documentation
- `docs/development/running-tests/` - Testing guide
- `docs/development/code-review-guidelines/` - Code review standards
- `CONTRIBUTING.md` - Contribution workflow
