/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  mainSidebar: [
    {
      type: 'doc',
      id: 'intro',
      label: 'Introduction',
    },
    {
      type: 'category',
      label: 'Getting Started',
      collapsed: false,
      items: [
        'getting-started/prerequisites',
        'getting-started/quick-start',
        'getting-started/docker',
        'getting-started/seeding-data',
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/overview',
        'architecture/database-schema',
      ],
    },
    {
      type: 'category',
      label: 'MPI Backend (cr-core)',
      items: [
        'backend/overview',
        'backend/authentication',
        'backend/deduplication',
        'backend/configuration',
      ],
    },
    {
      type: 'category',
      label: 'Frontend (cr-frontend)',
      items: [
        'frontend/overview',
        'frontend/getting-started',
        'frontend/authentication',
      ],
    },
    {
      type: 'category',
      label: 'Audit Service',
      items: [
        'audit-service/overview',
        'audit-service/configuration',
      ],
    },
    {
      type: 'category',
      label: 'API Reference',
      items: [
        'api-reference/fhir-endpoints',
        'api-reference/audit-api',
      ],
    },
    {
      type: 'category',
      label: 'Guides',
      items: [
        'guides/demo-scenarios',
        'guides/database-console',
      ],
    },
    {
      type: 'doc',
      id: 'contributing',
      label: 'Contributing',
    },
  ],
};

module.exports = sidebars;
