# Blog Feature Specification

## Overview
Add a personal blog to the website with single-user authentication, article management, and public article listing/viewing. Articles should support rich content via Action Text and be organized using tags.

## Inspiration
Layout and presentation inspired by [Simon Willison's blog](https://simonwillison.net/):
- Chronological listing with most recent articles first
- Article excerpts on the listing page with "read more" links
- Clean, readable layout with tags for organization
- Individual article pages with full content

## Implementation Status

- [x] **Authentication (Single User)** - COMPLETED
- [x] **Article Model** - COMPLETED
- [x] **Tag System** - COMPLETED
- [x] **Article-Tag Association** - COMPLETED
- [x] **Admin Interface** - COMPLETED
- [x] **Public Blog Pages** - COMPLETED
- [x] **RSS Feed** - COMPLETED
- [ ] **Search Functionality**

## Features

### 1. Authentication (Single User) ✅ COMPLETED

**Requirements:**
- ✅ Single admin user authentication for blog management
- ✅ Login/logout functionality
- ✅ Session-based authentication
- ⏭️ Password reset capability (deferred - not critical for MVP)
- ✅ Protected admin routes that require authentication

**Implementation notes:**
- ✅ Use `has_secure_password` from Rails
- ✅ Store single user credentials in the database
- ✅ Simple login form with email/password
- ✅ All admin routes protected with `require_authentication` before_action

**Implementation details:**
- User model created with email and password_digest
- SessionsController handles login/logout
- Authentication helpers: `current_user`, `logged_in?`, `require_authentication`
- Routes: `/login`, `POST /login`, `DELETE /logout`
- Admin dashboard at `/admin` (protected)
- Seed data: admin@simaobelchior.com / password123
- bcrypt gem added for password encryption

### 2. Article Model ✅ COMPLETED

**Attributes:**
- ✅ `title` (string, required) - Article title
- ✅ `body` (action_text, required) - Rich text content using Action Text
- ✅ `published_at` (datetime, optional) - Publication timestamp (nil = draft)
- ✅ `slug` (string, required, unique) - URL-friendly identifier
- ✅ Timestamps (`created_at`, `updated_at`)

**Validations:**
- ✅ Title must be present
- ✅ Title should be unique
- ✅ Slug must be present and unique
- ✅ Slug should be auto-generated from title if not provided

**Scopes:**
- ✅ `published` - Only articles with `published_at <= now`
- ✅ `drafts` - Articles with `published_at` as nil
- ✅ `recent` - Ordered by `published_at` descending

**Methods:**
- ✅ `published?` - Returns true if article is published
- ✅ `excerpt(length: 500)` - Returns truncated plain text version of body for listings
- ✅ Auto-generate slug from title before validation (if slug is blank)

**Implementation details:**
- Action Text installed and configured for rich text editing
- Active Storage tables created for image uploads
- Migration created with proper indexes (slug unique, published_at)
- Slug generation handles duplicates by appending counter (e.g., "title-1", "title-2")
- Optimized slug generation uses single database query with LIKE pattern for performance
- Excludes self when updating to avoid false conflicts
- 13 comprehensive tests covering validations, scopes, methods, and edge cases
- All tests passing

### 3. Tag System ✅ COMPLETED

**Tag Model:**
- ✅ `name` (string, required, unique)
- ✅ Timestamps
- ✅ Name normalization (lowercase, trimmed whitespace)

**Article-Tag Association:**
- ✅ Many-to-many relationship via `ArticleTag` join table
- ✅ Articles can have multiple tags
- ✅ Tags can belong to multiple articles
- ✅ Unique constraint on article_id + tag_id combination
- ✅ Cascading delete (article_tags destroyed when article is destroyed)

**Features:**
- ✅ Display tags on article listings and show pages
- ✅ Auto-create tags if they don't exist when assigning to articles
- ✅ Tag input via comma-separated string in admin form
- ✅ `Tag.from_list(string)` - Parse comma-separated tags
- ✅ `article.tag_list` - Get tags as comma-separated string
- ✅ `article.tag_list=(string)` - Set tags from comma-separated string

**Implementation details:**
- Tag names are normalized to lowercase and whitespace is stripped
- `Tag.from_list` handles duplicates, empty entries, and whitespace
- Uses `find_or_create_by` to avoid creating duplicate tags
- ArticleTag join table has unique index on [article_id, tag_id]
- 12 comprehensive tests for Tag model and associations
- 5 comprehensive tests for Article-Tag integration
- All 31 tests passing

### 4. Public Blog Pages ✅ COMPLETED

#### Blog Index (`/blog`)
**Layout:**
- ✅ List all published articles in reverse chronological order
- ✅ Pagination (15 articles per page using Kaminari)

**Each article entry shows:**
- ✅ Publication date and time (formatted as "Month Day, Year at H:MM AM/PM")
- ✅ Article title (linked to show page)
- ✅ Excerpt (first 2000 characters of plain text content)
- ✅ "Continue reading →" link (only shown if article is truncated)
- ✅ Tags (as clickable badges/links)

**Additional features:**
- ✅ Filter by tag (e.g., `/blog?tag=rails`)
- ✅ Tag filter indicator with "View all articles" link
- ✅ Responsive design matching the homepage aesthetic
- ✅ Empty state handling (no articles found)

#### Article Show Page (`/blog/:slug`)
**Content:**
- ✅ Full article title
- ✅ Publication date and time
- ✅ Full article body (rendered with Action Text formatting)
- ✅ Tags displayed at the bottom
- ✅ "Back to blog" link

**SEO:**
- ✅ Page title should be article title
- ✅ Meta description from excerpt (160 characters)

**Implementation details:**
- ArticlesController with index and show actions
- Routes: `/blog` (index), `/blog/:slug` (show), `/blog?tag=name` (filtered)
- Only published articles visible (published_at <= now)
- Draft articles return 404 on show page
- Article content styled with typography, code blocks, images, lists, blockquotes
- Centered 8-column layout on show page for readability
- Kaminari pagination with Bootstrap 4 theme
- `EXCERPT_LENGTH` constant (2000 chars) in Article model
- `truncated?` method checks if article exceeds excerpt length
- SEO implementation with `content_for` blocks for title and description
- Dynamic page titles: "Article Title - Simão Belchior"
- Meta descriptions use 160-character excerpts for optimal display
- Open Graph and Twitter Card meta tags update dynamically per article
- OG type changes to "article" for blog posts
- 6 comprehensive controller tests
- All 40 tests passing

### 5. Admin Interface ✅ COMPLETED

All admin routes are under `/admin` namespace and require authentication.

#### Admin Dashboard (`/admin`) ✅
- ✅ Stats cards showing total articles, published count, draft count
- ✅ Recent articles list (10 most recent) with status badges
- ✅ Quick action buttons (New Article, Manage Articles)
- ✅ Links to article management

#### Articles List (`/admin/articles`) ✅
**Display:**
- ✅ Responsive table view of all articles with pagination (25 per page)
- ✅ Shows: title (linked to edit), status badge, published date, tags, actions
- ✅ Sort by: published_at (default), title, created_at
- ✅ Filter by: status (all/published/drafts), tag

**Actions per article:**
- ✅ Edit button
- ✅ Delete button (with Turbo confirmation)
- ✅ Toggle publish/unpublish button (context-aware label)

#### Create Article (`/admin/articles/new`) ✅
**Form fields:**
- ✅ Title (text input with validation)
- ✅ Slug (text input, auto-generated from title if blank)
- ✅ Body (Action Text rich editor with Trix)
- ✅ Tags (text input with comma separation and hint text)
- ✅ Published at (datetime field, leave blank for draft)

**Buttons:**
- ✅ Save as Draft (clears published_at field via JavaScript)
- ✅ Create/Update Article (primary action)
- ✅ Cancel (returns to articles list)

#### Edit Article (`/admin/articles/:id/edit`) ✅
- ✅ Same form as create with pre-filled data
- ✅ Delete button in header (with confirmation)
- ✅ Shows creation and last updated timestamps
- ✅ Update button instead of Create

**Implementation details:**
- Admin::ArticlesController with full CRUD + toggle_publish action
- Admin navigation bar shown on all admin pages (Dashboard, Articles, New Article, Logout, View Site)
- Filter and sort options via form with GET parameters
- Kaminari pagination for article lists
- Status filtering: all (default), published, drafts
- Tag filtering via URL parameter
- Conditional rendering based on article state (published vs draft)
- Action Text integration for rich content editing
- Tag assignment via comma-separated string (tag_list attribute)
- All admin routes protected with `require_authentication` before_action
- Sorting logic uses database-agnostic approach with `Arel.sql("published_at IS NULL ASC, published_at DESC")` for nulls-last ordering
- "Save as Draft" button uses Stimulus controller (`article-form`) instead of inline onclick handler
- Stimulus controller clears published_at field when saving as draft
- 11 comprehensive controller tests covering CRUD, authentication, filtering, and toggle publish
- All 51 tests passing (114 assertions total)

### 6. Action Text Setup

**Requirements:**
- Install and configure Action Text
- Use Trix editor for rich content editing
- Support for:
  - Bold, italic, headings
  - Links
  - Lists (ordered/unordered)
  - Code blocks
  - Blockquotes
  - Images (via Active Storage)

**Styling:**
- Style Action Text content to match site design
- Ensure code blocks have syntax highlighting or at least monospace styling

### 7. Routes

```ruby
# Public routes
get '/blog', to: 'articles#index', as: :blog
get '/blog/feed', to: 'articles#feed', as: :blog_feed, defaults: { format: :rss }
get '/blog/:slug', to: 'articles#show', as: :article

# Admin routes (authentication required)
namespace :admin do
  root to: 'dashboard#index'
  resources :articles
  post 'articles/:id/toggle_publish', to: 'articles#toggle_publish'
end

# Authentication routes
get '/login', to: 'sessions#new'
post '/login', to: 'sessions#create'
delete '/logout', to: 'sessions#destroy'
```

### 8. RSS Feed ✅ COMPLETED

**Requirements:**
- ✅ RSS feed at `/blog/feed`
- ✅ Include last 20 published articles
- ✅ Standard RSS 2.0 format

**Feed content per article:**
- ✅ Title
- ✅ Link to article (full URL)
- ✅ Publication date
- ✅ Description (full article body as HTML in CDATA section)
- ✅ Author name
- ✅ Categories (from tags)
- ✅ GUID (unique identifier using article URL)

**Technical details:**
- ✅ Rails builder template (`feed.rss.builder`)
- ✅ Proper content-type header (`application/rss+xml`)
- ✅ HTML properly escaped in descriptions
- ✅ Site metadata included (title, description, link)
- ✅ Atom self-link for feed URL

**Discovery:**
- ✅ RSS feed auto-discovery link tag in HTML `<head>`
- ✅ Visible "RSS" link with icon on blog index page (top right)

**Implementation details:**
- ArticlesController#feed action at `/blog/feed`
- RSS builder template at `app/views/articles/feed.rss.builder`
- Feed includes channel metadata: title, description, link, language, lastBuildDate
- Each item includes: title, description (full HTML body), pubDate, link, guid, author, categories
- Full article content wrapped in CDATA section for proper HTML rendering in RSS readers
- Auto-discovery link tag added to application layout
- RSS link visible on blog index page with Bootstrap icon
- Feed limited to 20 most recent published articles
- 4 comprehensive tests covering feed generation, content, metadata, and article limit
- All 55 tests passing (171 assertions total)

### 9. Search Functionality

**Requirements:**
- Search across article titles and body content
- Search form on blog index page
- Display search results in same layout as blog index

**Search interface:**
- Search input field in prominent location on `/blog`
- "Search" button or submit on enter
- Clear indication when viewing search results
- Show search query and result count
- Link to clear search and return to full listing

**Search implementation:**
- Simple SQL-based search using `LIKE` or `ILIKE`
- Search published articles only
- Match against: title and plain text version of body
- Case-insensitive search
- Order results by relevance (exact title matches first, then by date)

**Search results page (`/blog?q=query`):**
- Same layout as blog index
- Show: "Search results for 'query'" heading
- Display matching articles with excerpts
- Highlight search terms in titles/excerpts (optional enhancement)
- Show "No results found" message if empty
- Pagination for search results

**Future enhancement considerations:**
- Full-text search with PostgreSQL or dedicated search engine
- Search within specific tags
- Search filters (date range, tags)

### 10. Navigation Updates

**Public navigation:**
- Add "Blog" link to main navigation (when implemented)

**Admin navigation:**
- Persistent admin nav when logged in
- Links to: Dashboard, Articles, New Article, Logout

## Implementation Order

1. **Authentication system**
   - User model with `has_secure_password`
   - Sessions controller
   - Login/logout views
   - Authentication helper methods

2. **Article model and migrations**
   - Create Article model
   - Set up Action Text
   - Add slug generation
   - Validations and scopes

3. **Tag system**
   - Tag model
   - ArticleTag join model
   - Tag assignment logic

4. **Admin interface**
   - Admin namespace and layout
   - Dashboard
   - Articles CRUD
   - Rich text editor integration

5. **Public blog pages**
   - Blog index with excerpts
   - Article show page
   - Tag filtering

6. **Search functionality**
   - Add search form to blog index
   - Implement search logic in controller
   - Display search results

7. **RSS feed**
   - Create RSS builder template
   - RSS controller action
   - Add auto-discovery link tags
   - Add subscribe link to blog index

8. **Styling and polish**
   - Match site design (light, simple, sharp)
   - Responsive design
   - Action Text content styling

## Technical Considerations

- Use Rails 8's built-in features where possible
- Ensure all forms use CSRF protection
- Add proper indexes on frequently queried columns (slug, published_at, tag names)
- Consider using Turbo for smoother page transitions
- Add tests for authentication, article publishing, and tag assignment

## Future Enhancements (Not in Initial Scope)

- Related articles
- Article series/collections
- Comments system
- Social sharing buttons
- Analytics integration
- Full-text search with PostgreSQL or dedicated search engine
- Advanced search filters (date range, multiple tags)
- Syntax highlighting for code blocks in articles
