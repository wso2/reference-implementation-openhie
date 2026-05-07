// @ts-check
const { themes } = require('prism-react-renderer');
const lightTheme = themes.github;
const darkTheme = themes.dracula;

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'OpenHIE Client Registry',
  tagline: 'Standards-based Master Patient Index for Health Information Exchange',
  favicon: 'img/favicon.ico',

  url: 'http://localhost',
  baseUrl: '/',

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  themes: [
    [
      '@easyops-cn/docusaurus-search-local',
      {
        hashed: true,
        language: ['en'],
        highlightSearchTermsOnTargetPage: true,
        explicitSearchResultPath: true,
      },
    ],
  ],

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl:
            'https://github.com/your-org/openhie_cr/tree/main/docs-site/',
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/og-card.png',
      navbar: {
        title: 'OpenHIE Client Registry',
        logo: {
          alt: 'OpenHIE CR Logo',
          src: 'img/logo.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'mainSidebar',
            position: 'left',
            label: 'Docs',
          },
          {
            to: '/docs/api-reference/fhir-endpoints',
            label: 'API Reference',
            position: 'left',
          },
          {
            to: '/docs/guides/demo-scenarios',
            label: 'Demo',
            position: 'left',
          },
          {
            href: 'https://github.com/your-org/openhie_cr',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Getting Started',
            items: [
              { label: 'Prerequisites', to: '/docs/getting-started/prerequisites' },
              { label: 'Quick Start', to: '/docs/getting-started/quick-start' },
              { label: 'Demo Scenarios', to: '/docs/guides/demo-scenarios' },
            ],
          },
          {
            title: 'Architecture',
            items: [
              { label: 'System Overview', to: '/docs/architecture/overview' },
              { label: 'Database Schema', to: '/docs/architecture/database-schema' },
              { label: 'Deduplication', to: '/docs/backend/deduplication' },
            ],
          },
          {
            title: 'API Reference',
            items: [
              { label: 'FHIR Endpoints', to: '/docs/api-reference/fhir-endpoints' },
              { label: 'Audit API', to: '/docs/api-reference/audit-api' },
            ],
          },
          {
            title: 'Standards',
            items: [
              {
                label: 'IHE PDQm (ITI-78)',
                href: 'https://profiles.ihe.net/ITI/PDQm/',
              },
              {
                label: 'IHE PIXm (ITI-104)',
                href: 'https://profiles.ihe.net/ITI/PIXm/',
              },
              {
                label: 'IHE ATNA (ITI-20)',
                href: 'https://profiles.ihe.net/ITI/TF/Volume2/ITI-20.html',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} OpenHIE Client Registry. Built with Docusaurus.`,
      },
      prism: {
        theme: lightTheme,
        darkTheme: darkTheme,
        additionalLanguages: ['bash', 'json', 'toml', 'yaml'],
      },
      colorMode: {
        defaultMode: 'light',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
    }),
};

module.exports = config;
