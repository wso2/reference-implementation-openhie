import React from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import styles from './index.module.css';

const features = [
  {
    title: 'IHE Standards Compliant',
    icon: '📋',
    description:
      'Implements ITI-78 (PDQm), ITI-104 (PIXm), and ITI-119 patient match with full FHIR R4 resource support.',
  },
  {
    title: 'Blocking-Accelerated Matching',
    icon: '⚡',
    description:
      'Pre-computed blocking keys reduce candidate sets from millions to ~10–500, enabling sub-second $match queries at scale.',
  },
  {
    title: 'Incremental Deduplication',
    icon: '🔍',
    description:
      'Async dedup pipeline with Union-Find grouping. Only new patient pairs are scored on each run, making it fast even for large registries.',
  },
  {
    title: 'FHIR Audit Trail (ATNA)',
    icon: '🔒',
    description:
      'Every patient operation is logged as a FHIR AuditEvent via IHE ATNA ITI-20, with a queryable REST API.',
  },
  {
    title: 'Dual Authentication',
    icon: '🔑',
    description:
      'WSO2 Asgardeo (OIDC) in production, simulated auth in development. Role-based access: admin vs viewer.',
  },
  {
    title: 'Management UI',
    icon: '🖥️',
    description:
      'React 19 + WSO2 Oxygen UI frontend for patient CRUD, dedup review, match operations, and audit log viewing.',
  },
];

function Feature({ icon, title, description }) {
  return (
    <div className={clsx('col col--4', styles.featureItem)}>
      <div className={styles.featureIcon}>{icon}</div>
      <h3>{title}</h3>
      <p>{description}</p>
    </div>
  );
}

function HomepageHero() {
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <h1 className="hero__title">OpenHIE Client Registry</h1>
        <p className="hero__subtitle">
          A standards-based <strong>Master Patient Index (MPI)</strong> for health information exchanges.
          <br />
          FHIR R4 · IHE PDQm  · Ballerina + React
        </p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/docs/getting-started/quick-start">
            Quick Start →
          </Link>
          <Link
            className="button button--outline button--secondary button--lg"
            style={{ marginLeft: '1rem' }}
            to="/docs/api-reference/fhir-endpoints">
            API Reference
          </Link>
        </div>
        <div className={styles.componentPills}>
          <span className={styles.pill}>cr-core :9090</span>
          <span className={styles.pill}>audit-service :9093</span>
          <span className={styles.pill}>cr-frontend :5173</span>
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="Standards-based Master Patient Index for Health Information Exchange. FHIR R4, IHE PDQm/PIXm/ITI-119, Ballerina backend, React frontend.">
      <HomepageHero />
      <main>
        <section className={styles.features}>
          <div className="container">
            <div className="row">
              {features.map((props, idx) => (
                <Feature key={idx} {...props} />
              ))}
            </div>
          </div>
        </section>

        <section className={styles.callout}>
          <div className="container">
            <div className="row">
              <div className="col col--6">
                <h2>Get started in minutes</h2>
                <p>Three services, no external database setup required — H2 is embedded and auto-created on first run.</p>
                <pre className={styles.codeBlock}>
{`cd audit-service && bal run   # port 9093
cd cr-core && bal run          # port 9090
cd cr-frontend && npm run dev  # port 5173`}
                </pre>
                <Link className="button button--primary" to="/docs/getting-started/quick-start">
                  Full Setup Guide →
                </Link>
              </div>
              <div className="col col--6">
                <h2>Designed for HIEs</h2>
                <ul>
                  <li>Conditional PUT (identifier-based upsert) for cross-facility registration</li>
                  <li>Probabilistic $match with configurable field weights and algorithms</li>
                  <li>Soft-delete preserves historical records and audit trail</li>
                  <li>Scale-tested: seed scripts for up to 500,000 patients</li>
                </ul>
                <Link className="button button--outline button--primary" to="/docs/guides/demo-scenarios">
                  See Demo Scenarios →
                </Link>
              </div>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
