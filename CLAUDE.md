# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Tech Stack

Rails 8.0.2 application using:
- Ruby 3.3.2
- SQLite3 (database)
- Solid Cache (database-backed caching)
- Solid Queue (database-backed Active Job adapter)
- Solid Cable (database-backed Action Cable adapter)
- Hotwire (Turbo + Stimulus)
- Bootstrap 5.3 (with Dart Sass)
- Importmap for JavaScript
- Kamal for deployment

## Development Commands

### Setup
```bash
bin/setup              # Initial setup
bin/dev                # Start development server (with CSS watching)
bin/rails server       # Start Rails server only
```

### Testing
```bash
bin/rails test                    # Run all tests
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

These use separate SQLite databases defined in `config/cache.yml`, `config/queue.yml`, and `config/cable.yml`.

### Frontend Architecture
- Hotwire (Turbo + Stimulus) for SPA-like interactivity without complex JavaScript
- Stimulus controllers in `app/javascript/controllers/`
- Dart Sass for CSS compilation (`bin/rails dartsass:watch`)
- Bootstrap 5.3 for styling
- Importmap for JavaScript dependencies (no webpack/node build step required)

### Deployment
Uses Kamal for containerized deployment to DigitalOcean (165.227.145.143):
- Docker image: `lethird/simaobelchior`
- Hosts: simaobelchior.com, www.simaobelchior.com
- SSL via Let's Encrypt
- Configuration in `config/deploy.yml`
- Secrets managed via `.kamal/secrets`

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on PRs and pushes to main:
1. **Security scan**: `bin/brakeman`
2. **Lint**: `bin/rubocop`
3. **Tests**: `bin/rails db:test:prepare test test:system`

All three must pass for CI to succeed.

## Current Application Structure

Simple personal website with:
- Home page (root route)
- About page (`/about`)
- Health check endpoint (`/up`)
- HomeController in `app/controllers/home_controller.rb`

The application is currently minimal - most of the codebase is standard Rails 8 boilerplate.
