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
- [ ] **Tag System**
- [ ] **Article-Tag Association**
- [ ] **Admin Interface**
- [ ] **Public Blog Pages**
- [ ] **RSS Feed**
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

### 3. Tag System

**Tag Model:**
- `name` (string, required, unique)
- Timestamps

**Article-Tag Association:**
- Many-to-many relationship via `ArticleTag` join table
- Articles can have multiple tags
- Tags can belong to multiple articles

**Features:**
- Display tags on article listings and show pages
- Auto-create tags if they don't exist when assigning to articles
- Tag input should be comma-separated in the admin form

### 4. Public Blog Pages

#### Blog Index (`/blog`)
**Layout:**
- List all published articles in reverse chronological order
- Pagination (10-15 articles per page)

**Each article entry shows:**
- Publication date (formatted as "Month Day, Year")
- Article title (linked to show page)
- Excerpt (first ~500 characters of plain text content)
- "Continue reading →" link to full article
- Tags (as clickable badges/links)

**Additional features:**
- Filter by tag (e.g., `/blog?tag=rails`)
- Responsive design matching the homepage aesthetic

#### Article Show Page (`/blog/:slug`)
**Content:**
- Full article title
- Publication date
- Full article body (rendered with Action Text formatting)
- Tags displayed at the bottom
- Link back to blog index

**SEO:**
- Page title should be article title
- Meta description from excerpt

### 5. Admin Interface

All admin routes should be under `/admin` namespace and require authentication.

#### Admin Dashboard (`/admin`)
- List all articles (published and drafts)
- Quick stats: total articles, published count, draft count
- Links to create new article

#### Articles List (`/admin/articles`)
**Display:**
- Table/list view of all articles
- Show: title, status (published/draft), published date, actions
- Sort by: created_at, published_at, title
- Filter by: status (all/published/drafts), tag

**Actions per article:**
- Edit
- Delete (with confirmation)
- Toggle publish/unpublish

#### Create Article (`/admin/articles/new`)
**Form fields:**
- Title (text input)
- Slug (text input, auto-filled from title with JS)
- Body (Action Text rich editor)
- Tags (text input with comma separation, hint text)
- Published at (datetime picker, or checkbox for "Save as draft")

**Buttons:**
- Save as draft
- Publish
- Cancel

#### Edit Article (`/admin/articles/:id/edit`)
- Same form as create
- Additional "Delete" button
- Show creation and last updated timestamps

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

### 8. RSS Feed

**Requirements:**
- RSS feed at `/blog/feed.xml` or `/blog.rss`
- Include last 20 published articles
- Standard RSS 2.0 format

**Feed content per article:**
- Title
- Link to article (full URL)
- Publication date
- Description (article excerpt or full body)
- Author name
- Categories (from tags)
- GUID (unique identifier)

**Technical details:**
- Use Rails builder template (`.rss.builder`)
- Proper content-type header (`application/rss+xml`)
- Escape HTML properly in descriptions
- Include site metadata (title, description, link)

**Discovery:**
- Add RSS feed link tag in HTML `<head>` for auto-discovery
- Add visible "Subscribe via RSS" link on blog index page

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
