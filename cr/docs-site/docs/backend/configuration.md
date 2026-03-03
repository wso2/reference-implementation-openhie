---
sidebar_position: 4
title: Configuration
---

# Configuration Reference

All `cr-core` runtime settings live in `cr-core/config.toml`.

## Full Config File

```toml
# Audit Service
auditServiceUrl = "http://localhost:9093"
auditEnabled = true
sourceObserverName = "client-registry"

# Database
dbUrl = "jdbc:h2:file:./data/mpi;AUTO_SERVER=TRUE"
dbUser = "sa"
dbPassword = ""

# Base URL
baseUrl = "http://localhost:9090/fhir/r4"

# Matching thresholds
matchThreshold = 0.25       # minimum score for $match endpoint results
dedupThreshold = 0.50       # minimum score for dedup grouping

[gradeThresholds]
certain = 0.95              # >= 0.95 = certain match
probable = 0.80             # >= 0.80 = probable match
possible = 0.60             # >= 0.60 = possible match

[fields.identifier]
weight = 0.30
algorithm = "exact"

[fields.family]
weight = 0.20
algorithm = "soundex"
levenshteinThreshold = 0.80

[fields.given]
weight = 0.15
algorithm = "soundex"
levenshteinThreshold = 0.80

[fields.birthDate]
weight = 0.20
algorithm = "exact"

[fields.gender]
weight = 0.05
algorithm = "exact"

[fields.phone]
weight = 0.05
algorithm = "levenshtein"

[fields.postalCode]
weight = 0.05
algorithm = "exact"

[blocking]
enabled = true
refreshBatchSize = 5000
maxCandidatesPerMatch = 1000
```

## Service Settings

| Key | Default | Description |
|-----|---------|-------------|
| `auditServiceUrl` | `http://localhost:9093` | URL of the audit service |
| `auditEnabled` | `true` | Set to `false` to disable audit event emission |
| `sourceObserverName` | `client-registry` | Source observer name in AuditEvent resources |
| `dbUrl` | `jdbc:h2:file:./data/mpi;AUTO_SERVER=TRUE` | H2 JDBC URL. `AUTO_SERVER=TRUE` allows concurrent connections. |
| `dbUser` | `sa` | H2 database username |
| `dbPassword` | `""` | H2 database password (empty by default) |
| `baseUrl` | `http://localhost:9090/fhir/r4` | Self-referencing base URL used in FHIR responses |

## Matching Thresholds

| Key | Default | Description |
|-----|---------|-------------|
| `matchThreshold` | `0.25` | Minimum score for results returned by `$match` (ITI-119) |
| `dedupThreshold` | `0.50` | Minimum score for a pair to be included in dedup grouping |
| `gradeThresholds.certain` | `0.95` | Score threshold for "certain" match grade |
| `gradeThresholds.probable` | `0.80` | Score threshold for "probable" match grade |
| `gradeThresholds.possible` | `0.60` | Score threshold for "possible" match grade |

## Matching Algorithms

Four algorithms are available per field:

| Algorithm | Description | Best for |
|-----------|-------------|----------|
| `exact` | Case-insensitive exact match | Identifiers, gender, dates |
| `levenshtein` | Edit-distance fuzzy matching | Typos, transpositions (Jhon/John) |
| `soundex` | Phonetic code matching | Names that sound alike (Michel/Michael) |
| `jarowinkler` | Jaro-Winkler similarity | Short strings with prefix agreement |

### Levenshtein Parameters

```toml
[fields.family]
algorithm = "levenshtein"
levenshteinThreshold = 0.80   # min similarity ratio (default 0.80)
```

Strings below `levenshteinThreshold` score 0. Above it, actual similarity × field weight gives partial credit.

### Jaro-Winkler Parameters

```toml
[fields.family]
algorithm = "jarowinkler"
jaroWinklerThreshold = 0.85      # min similarity to count as match (default 0.85)
jaroWinklerPrefixScale = 0.1    # prefix bonus scaling factor (default 0.1, max 0.25)
```

## Field Weights

Weights across all fields **must sum to 1.0**. Default distribution:

| Field | Weight | Rationale |
|-------|--------|-----------|
| `identifier` | 0.30 | Strongest signal — exact ID match is highly deterministic |
| `family` | 0.20 | Important but subject to phonetic variation and typos |
| `birthDate` | 0.20 | Stable and highly discriminating |
| `given` | 0.15 | Less stable than family (nicknames, variations) |
| `gender` | 0.05 | Low information density |
| `phone` | 0.05 | Can change; useful for phonetic/typo tolerance |
| `postalCode` | 0.05 | Changes with relocation; limited discriminating power |

## Blocking Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `blocking.enabled` | `true` | Set to `false` to fall back to full-scan matching (debugging only) |
| `blocking.refreshBatchSize` | `5000` | Patients processed per batch during blocking key refresh |
| `blocking.maxCandidatesPerMatch` | `1000` | Safety cap on candidates returned per `$match` query |

### Blocking Passes

| Block Type | Key Formula | Catches |
|---|---|---|
| `SDX_FAM_DOB` | `soundex(family) \| birth_date` | Phonetic name variants with same DOB |
| `SDX_GIV_DOB_GEN` | `soundex(given) \| birth_date \| gender` | Given name variants |
| `DOB_GEN_ZIP` | `birth_date \| gender \| postal_code` | Name changes (e.g. marriage) in same area |
| `PHONE` | Normalized phone digits | Direct phone match |
| `IDENT` | `system \| value` | Exact identifier match |

Each patient produces 1–5 blocking keys depending on which fields are populated.
