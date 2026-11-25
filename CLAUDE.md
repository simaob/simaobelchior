# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Tech Stack

Rails 8.1 application using:
- Ruby 4.0.10
- SQLite3 (database)
- Solid Cache (database-backed caching)
- Solid Queue (database-backed Active Job adapter)
- Solid Cable (database-backed Action Cable adapter)
- Hotwire (Turbo + Stimulus)
- Bootstrap 5.3 (with Dart Sass)
- Importmap for JavaScript
- Action Text with Lexxy as the editor (replacing Trix), and Active Storage on local disk
- Kamal for deployment

Gems have a 14-day cooldown, set in the `Gemfile` and for Bundler in `.github/dependabot.yml`.

To change the Ruby version, update `.ruby-version` (which CI reads), `.tool-versions`, `Dockerfile`, `Gemfile`, `Gemfile.lock` and this file. Each `ruby/setup-ruby` release knows a fixed list of Ruby versions, so check that the one pinned in `.github/workflows/ci.yml` includes the new version.

## Development Commands

### Setup
```bash
bin/setup              # Initial setup
bin/dev                # Start development server (with CSS watching)
bin/rails server       # Start Rails server only
```

### Testing
```bash
bin/rails test                    # Run all tests except system tests
bin/rails test:system            # Run system tests only
bin/rails test test/models       # Run specific test directory
bin/rails test test/path/to/file_test.rb  # Run single test file
bin/rails db:test:prepare        # Prepare test database
```

### Code Quality
```bash
bin/rubocop            # Run RuboCop linter (uses rubocop-rails-omakase)
bin/brakeman           # Security vulnerability scanning
```

### Database
```bash
bin/rails db:setup     # Create and seed database
bin/rails db:migrate   # Run migrations
bin/rails db:seed      # Seed database
bin/rails tags:lookalikes  # List tags that look like the same tag written two ways
```

### Deployment
```bash
bin/kamal deploy       # Deploy to production using Kamal
bin/kamal app logs     # View production logs
```

## Architecture

### Solid* Stack
This application uses Rails 8's "Solid" adapters for infrastructure components, storing everything in SQLite databases instead of requiring separate services:

- **Solid Cache** (`db/cache_schema.rb`): Replaces Redis/Memcached for caching
- **Solid Queue** (`db/queue_schema.rb`): Replaces Sidekiq/Resque for background jobs
- **Solid Cable** (`db/cable_schema.rb`): Replaces Redis for Action Cable WebSocket connections

These are only used in production, where each has its own SQLite database, defined in `config/database.yml` and kept in `storage/`. Development caches in memory.

Solid Queue runs inside Puma in production (`SOLID_QUEUE_IN_PUMA`), in async mode, see `config/puma.rb`. Recurring jobs are in `config/recurring.yml`.

### Frontend Architecture
- Hotwire (Turbo + Stimulus) for SPA-like interactivity without complex JavaScript
- Stimulus controllers in `app/javascript/controllers/`
- Dart Sass for CSS compilation (`bin/rails dartsass:watch`)
- Bootstrap 5.3 for styling, with the site's palette and styles in `app/assets/stylesheets/application.scss`
- Importmap for JavaScript dependencies (no webpack/node build step required)

### Deployment
Uses Kamal for containerized deployment to a single Hetzner server (address in `config/deploy.yml`):
- Docker image: `simaobelchior`, built locally and pushed via a Kamal local registry (`localhost:5555`, tunnelled over SSH). No remote registry.
- Hosts: simaobelchior.com and simaobelchior.net, each with www. The .net hosts redirect to simaobelchior.com (`config/routes.rb`).
- SQLite databases and uploads are in the `storage` volume. `bin/docker-entrypoint` runs `db:prepare` when the server starts.
- SSL via Let's Encrypt
- Configuration in `config/deploy.yml`
- Secrets managed via `.kamal/secrets`

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on PRs and pushes to master:
1. **Security scan**: `bin/brakeman`
2. **Lint**: `bin/rubocop`
3. **Tests**: `bin/rails db:test:prepare test test:system`

All three must pass for CI to succeed. CI doesn't build the Docker image.

## Current Application Structure

Personal website with a blog, first-party visit counting and an admin. Times are in Lisbon time. Many models and controllers open with a comment explaining what they do, so read that first.

### Public pages
- Home (`/`), About (`/about`) and Games (`/games`): `HomeController`
- Blog (`/blog`, `/blog/:slug`, RSS at `/blog/feed`): `ArticlesController`. Search (`?q=`) matches `Article#search_text`, which is filled in on save. `?tag=` filters by tag.
- Blogroll (`/blogroll`, also as OPML): `LinksController` and `Link`
- Login (`/login`): `SessionsController`, with an optional "remember me" cookie
- Health check (`/up`)

### Admin (`/admin`)
Every controller under `Admin::` needs `before_action :require_authentication`. It isn't inherited.
- Dashboard, articles and links (blogroll)
- Visits: `VisitStats`
- Games: `GameStats`

### Visit counting
Visits are counted on the server with no cookies, no third-party scripts, and no IP addresses or user agents stored. The footer tells visitors so (`app/views/shared/_privacy_note.html.erb`), so keep it true.
- `PageView`: public pages, counted by the `CountsPageViews` concern. A new public controller needs to include it.
- `VisitorSalt`: a daily salt for the visitor hash, deleted after its day by `DeleteOldVisitorSaltsJob`
- `FeedFetch`: feed readers, to estimate subscribers

### Games
The games themselves are static pages on games.simaobelchior.com, not in this repository. They report back with beacons, limited to that origin by the `GameBeacon` concern:
- `POST /games/opened`: `GameVisitsController`, stored as a `PageView`
- `POST /games/events`: `GameEventsController`, stored as a `GameEvent`
