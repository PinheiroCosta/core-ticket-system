# Core Ticket System — Copilot Instructions

## Project Overview

Core Ticket System is an open-source, self-hosted ticket management engine designed to be installed independently by each organization.

The project prioritizes simplicity, security, maintainability, and extensibility.

It follows a modular monolithic architecture with an API-first approach. The administrative interface is a first-party client of the API, not an integral dependency of the backend.

Each installation has its own database, storage resources, users, and configuration.

This project is NOT a multi-tenant SaaS.

## Technology Stack

- Language: TypeScript
- Frontend: Astro
- Backend: Cloudflare Pages Functions
- Database: Cloudflare D1 (SQLite)
- File storage: Cloudflare R2
- Validation: Zod
- Testing: Vitest
- Package manager: npm
- Deployment: Cloudflare Pages
- CI: GitHub Actions

Prefer native Web APIs and Cloudflare runtime capabilities over Node.js-specific dependencies.

Use compatible, actively maintained dependencies only.

## Architecture Principles

1. Keep the application modular without introducing unnecessary architectural abstractions.
2. Maintain strict separation between HTTP handlers, business logic, data access, and infrastructure.
3. The backend must remain independent of the frontend.
4. All business functionality must be accessible through a documented REST API.
5. Version API routes using `/api/v1`.
6. Keep database access centralized in repositories or equivalent data-access modules.
7. Use dependency injection where it improves testability, but avoid unnecessary frameworks.
8. Prefer explicit implementations over generic abstractions.
9. Do not introduce microservices, event buses, or complex distributed architectures.

## Database Guidelines

- Use relational SQL modeling as the default.
- Use explicit foreign keys and appropriate indexes.
- Enable and verify SQLite foreign-key enforcement.
- Use migrations for every schema change.
- Never modify an existing migration that may already have been applied.
- Use prepared statements and parameterized queries.
- Avoid storing relational information as JSON.
- JSON columns are permitted only for genuinely variable metadata, with mandatory schema validation.
- Store file metadata and references in D1, not file contents.
- Use ISO 8601 timestamps consistently.

## Authentication and Authorization

The application has two initial roles:

- `admin`
- `customer`

Requirements:

- Authentication uses email and password.
- Passwords must never be stored in plaintext.
- Use a password hashing implementation compatible with Cloudflare Workers.
- Prefer Web Crypto APIs when appropriate.
- Never use fast general-purpose hashes such as SHA-256 alone for password storage.
- Store sessions server-side in D1.
- Session identifiers must be cryptographically random.
- Store only hashed session identifiers in the database.
- Use HttpOnly, Secure, and appropriate SameSite cookie attributes.
- Implement session expiration and revocation.
- Protect authentication endpoints against brute-force attacks.
- Never allow public administrator registration.
- Never trust role information supplied by the client.
- Authorization must always be enforced server-side.

Customers must only access their own tickets, messages, and attachments.

Administrators can access tickets belonging to all customers.

## Security Requirements

- Validate all external inputs using Zod or equivalent schemas.
- Never trust client-provided identifiers or permissions.
- Prevent SQL injection through prepared statements.
- Prevent cross-site scripting through appropriate output handling.
- Implement CSRF protection for cookie-authenticated state-changing requests.
- Apply appropriate security headers.
- Restrict upload size, file types, and attachment permissions.
- Never expose public R2 object URLs for private attachments.
- Use authenticated download endpoints.
- Avoid leaking internal errors, secrets, stack traces, or sensitive information.
- Never commit credentials, API tokens, or environment secrets.
- Treat CORS as a browser access policy, not an authentication mechanism.

## Frontend Guidelines

- Use Astro for the administrative interface.
- Prefer native HTML and CSS for simple interactions.
- Use client-side TypeScript only where interactivity requires it.
- Do not introduce React unless a concrete requirement justifies it.
- Keep frontend components independent from backend implementation details.
- Communicate with the backend exclusively through the REST API.
- Keep the interface minimal, accessible, and responsive.

The frontend must not contain authorization logic that is relied upon for security.

## Code Quality

- Use strict TypeScript.
- Avoid `any` unless explicitly justified.
- Prefer small, focused modules.
- Use descriptive names.
- Avoid unnecessary dependencies.
- Keep functions reasonably small and single-purpose.
- Document non-obvious security and architectural decisions.
- Do not duplicate business rules across API handlers.

## Testing

- Write unit tests for business logic.
- Write integration tests for database repositories and API endpoints.
- Test authorization boundaries explicitly.
- Test that customers cannot access other customers' resources.
- Test authentication failures and session expiration.
- Test file upload and download authorization.
- Run lint, type checking, and tests before considering a task complete.

## Development Workflow

Before implementing a feature:

1. Inspect the existing project structure.
2. Read relevant architecture documentation.
3. Identify affected modules.
4. Explain significant architectural changes before implementing them.
5. Prefer incremental changes.

After implementation:

1. Run relevant tests.
2. Run TypeScript checks.
3. Run linting.
4. Update documentation when necessary.

Do not silently introduce architectural changes.

Do not implement unrelated features while working on a specific task.

Do not generate placeholder implementations that appear functional but contain missing security or business logic.

When a requirement is ambiguous, explain the ambiguity and request clarification rather than inventing behavior.

## Scope Management

The initial goal is a minimal, secure, executable foundation.

Do not prematurely implement:

- Multi-tenancy.
- Billing or subscription management.
- Email notification infrastructure.
- Complex permission systems.
- Plugin systems.
- External identity providers.
- Advanced workflow engines.
- Real-time messaging.

Future extensibility is desirable, but simplicity is the primary architectural constraint.
