# OpenHIE Client Registry — Documentation Site

This is the documentation site for the OpenHIE Client Registry, built with [Docusaurus](https://docusaurus.io/) — a static site generator that turns Markdown files into a searchable, versioned documentation website.

## Prerequisites

- [Node.js](https://nodejs.org/) v18 or higher
- npm (bundled with Node.js)

## Running locally

```bash
cd cr/documentation
npm install
npm start
```

The site opens at `http://localhost:3000` with live reload — any saved change to a `.md` file is reflected immediately in the browser.

## Building for production

```bash
npm run build     # outputs static files to the build/ directory
npm run serve     # preview the production build at http://localhost:3000
```

## Available scripts

| Script | What it does |
|--------|-------------|
| `npm start` | Start dev server with hot reload |
| `npm run build` | Build static site for deployment |
| `npm run serve` | Serve the production build locally |
| `npm run clear` | Clear Docusaurus cache (use when changes don't appear) |

## Project structure

```
docs-site/
├── docs/                   # All documentation pages (Markdown)
│   ├── intro.md
│   ├── getting-started/
│   ├── architecture/
│   ├── backend/
│   ├── frontend/
│   ├── audit-service/
│   ├── api-reference/
│   └── guides/
├── src/
│   ├── css/custom.css      # Global style overrides
│   └── pages/index.js      # Custom landing page
├── static/                 # Static assets (images, favicons)
├── docusaurus.config.js    # Site title, navbar, footer, plugins
├── sidebars.js             # Sidebar navigation order and grouping
└── package.json
```

## Making corrections

### Edit a page
All documentation lives in `docs/` as standard Markdown files. Open the relevant `.md` file, make your changes, and save. The dev server hot-reloads automatically.

### Add a new page
1. Create a `.md` file under the appropriate `docs/` subfolder.
2. Add a front matter block at the top:
   ```md
   ---
   id: my-page
   title: My Page Title
   sidebar_position: 3
   ---
   ```
3. If the page should appear in the sidebar, add its `id` to `sidebars.js` under the correct category.

### Reorder or restructure the sidebar
Edit [sidebars.js](sidebars.js). Each category is an object with a `label` and an `items` array of page IDs.

### Change the site title, navbar, or footer
Edit [docusaurus.config.js](docusaurus.config.js). The `themeConfig.navbar` and `themeConfig.footer` sections control the top bar and footer links.
