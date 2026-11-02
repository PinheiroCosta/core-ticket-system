# Core Ticket System — Architecture

## 1. Project Philosophy

Core Ticket System is an open-source, self-hosted ticket management system.

Its purpose is to provide a minimal, secure, and extensible ticket management engine that can be integrated into different business environments.

Each organization operates its own independent installation.

The project does not implement centralized multi-tenancy.

### Core principles

- Simplicity over unnecessary abstraction.
- Security by default.
- API-first development.
- Relational data modeling.
- Minimal operational dependencies.
- Independent frontend and backend.
- Community-friendly development.

## 2. Deployment Architecture

The application runs on Cloudflare Pages with Pages Functions.

### Components

**Frontend**
- Astro.
- Static generation.
- TypeScript for browser interactions.
- Communicates with the backend through REST.

**Backend**
- Cloudflare Pages Functions.
- TypeScript.
- REST API under `/api/v1`.
- Business logic separated from HTTP handlers.

**Database**
- Cloudflare D1.
- SQLite relational model.
- Schema migrations.

**Object Storage**
- Cloudflare R2.
- Private storage for ticket attachments.

### Runtime Architecture

The initial deployment uses Astro as a static site generator.

Pages Functions handle dynamic backend operations independently.

The project must not depend on Astro server-side rendering or a frontend-specific runtime for its API.

This separation keeps the backend accessible to alternative frontend implementations.

## 3. Application Modules

The backend should be organized around the following responsibilities:

### Authentication

Responsible for:
- Login.
- Logout.
- Password verification.
- Session creation.
- Session expiration.
- Session revocation.
- Password changes.

### Authorization

Responsible for:
- Role verification.
- Resource ownership validation.
- Administrative permissions.
- Customer access restrictions.

### Users

Responsible for:
- User registration by administrators.
- Customer account management.
- Administrator account management.
- Account activation and deactivation.

### Tickets

Responsible for:
- Ticket creation.
- Ticket listing.
- Ticket details.
- Status changes.
- Priority management.
- Ticket ownership.

### Messages

Responsible for:
- Customer messages.
- Administrator responses.
- Message history.
- Author identification.

### Attachments

Responsible for:
- Upload validation.
- R2 storage.
- Attachment metadata.
- Authorized downloads.
- Attachment deletion policies.

## 4. Authentication Model

The system uses email and password authentication.

Two roles are initially supported:

| Role | Description |
|---|---|
| admin | Full administrative access. |
| customer | Access restricted to owned resources. |

Administrator accounts must be provisioned through a secure installation procedure.

Public administrator registration is forbidden.

### Password Security

Passwords must use a dedicated password hashing algorithm.

The implementation must be compatible with the Cloudflare Workers runtime.

The algorithm, parameters, salt, and hash format must be versioned to allow future migration.

Passwords must never be stored or logged in plaintext.

### Sessions

Sessions are persisted in D1.

A session consists of:
- Random session identifier.
- Associated user.
- Creation timestamp.
- Expiration timestamp.
- Optional revocation timestamp.

Only a cryptographic hash of the session identifier should be stored in D1.

The browser receives the original identifier through a secure cookie.

Session cookies must use:
- HttpOnly.
- Secure in production.
- SameSite protection.
- An appropriate Path.
- Explicit expiration.

State-changing authenticated requests must implement CSRF protection.

## 5. Authorization Model

Authorization is enforced by the backend.

### Administrator

An administrator can:
- View all tickets.
- View all customers.
- Create customer accounts.
- Respond to tickets.
- Change ticket status.
- Manage ticket priorities.
- View ticket attachments.

### Customer

A customer can:
- Create tickets.
- View their own tickets.
- View messages belonging to their tickets.
- Reply to their own tickets.
- Upload attachments.
- Download authorized attachments.

Customers must never access resources belonging to another customer.

Ownership verification must happen inside the backend data-access or service layer, not exclusively in the frontend.

## 6. Database Model

The database uses a relational model.

Initial tables:

### users

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| name | TEXT | User name |
| email | TEXT | Unique email |
| password_hash | TEXT | Password hash |
| role | TEXT | admin or customer |
| is_active | INTEGER | Account status |
| created_at | TEXT | Creation timestamp |
| updated_at | TEXT | Last update |

### tickets

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| customer_id | TEXT | Owner |
| category_id | TEXT | Optional category |
| subject | TEXT | Ticket subject |
| description | TEXT | Initial description |
| status | TEXT | Current status |
| priority | TEXT | Ticket priority |
| metadata | TEXT | Optional validated JSON |
| created_at | TEXT | Creation timestamp |
| updated_at | TEXT | Last update |

### ticket_messages

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| ticket_id | TEXT | Associated ticket |
| author_id | TEXT | Message author |
| message | TEXT | Message content |
| created_at | TEXT | Creation timestamp |

### ticket_attachments

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| ticket_id | TEXT | Associated ticket |
| message_id | TEXT | Optional associated message |
| uploaded_by | TEXT | Uploading user |
| object_key | TEXT | R2 object identifier |
| original_name | TEXT | Original filename |
| mime_type | TEXT | Validated MIME type |
| size_bytes | INTEGER | File size |
| created_at | TEXT | Upload timestamp |

### ticket_categories

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| name | TEXT | Category name |
| description | TEXT | Optional description |
| is_active | INTEGER | Category status |
| created_at | TEXT | Creation timestamp |

### sessions

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| user_id | TEXT | Associated user |
| token_hash | TEXT | Hashed session identifier |
| expires_at | TEXT | Expiration timestamp |
| created_at | TEXT | Creation timestamp |
| revoked_at | TEXT | Optional revocation timestamp |

### Database Rules

- Every table must have an explicit primary key.
- Foreign keys must be defined.
- Foreign-key enforcement must be enabled and verified.
- Appropriate indexes must be created.
- Use parameterized queries.
- Schema modifications must use migrations.
- Do not store attachment arrays as JSON.
- Do not use JSON for information that naturally belongs in relational columns.
- JSON metadata must be validated before persistence.

## 7. File Storage

Ticket attachments are stored in Cloudflare R2.

D1 stores only attachment metadata and object identifiers.

R2 objects must remain private.

Downloads must be performed through authenticated API endpoints that verify ticket ownership or administrative permissions.

The application must validate:
- File size.
- Allowed file types.
- MIME type.
- File extension.
- User permissions.

Never trust client-provided MIME types or filenames.

## 8. API Architecture

All API endpoints must use the `/api/v1` prefix.

Initial endpoint groups:

### Authentication

- POST `/api/v1/auth/login`
- POST `/api/v1/auth/logout`
- GET `/api/v1/auth/me`

### Tickets

- GET `/api/v1/tickets`
- POST `/api/v1/tickets`
- GET `/api/v1/tickets/:id`
- PATCH `/api/v1/tickets/:id`

### Messages

- GET `/api/v1/tickets/:id/messages`
- POST `/api/v1/tickets/:id/messages`

### Attachments

- POST `/api/v1/tickets/:id/attachments`
- GET `/api/v1/attachments/:id`

### Users

Administrative endpoints for customer management must be added under an appropriate users resource.

Every endpoint must define:
- Authentication requirements.
- Authorization requirements.
- Input validation.
- Expected responses.
- Error handling.

## 9. Error Handling

Use consistent HTTP status codes.

The API should return structured JSON errors.

Never expose:
- SQL errors.
- Internal stack traces.
- Password hashes.
- Session tokens.
- Infrastructure credentials.

Authentication errors should not reveal whether an email address exists.

## 10. Configuration and Secrets

Cloudflare bindings:

- DB: D1 database.
- STORAGE: R2 bucket.

Environment variables and secrets must be separated from source code.

Use development and production environments with independent resources.

Never commit real credentials or secrets.

## 11. Testing Strategy

The project must include:

- Unit tests for business logic.
- Repository integration tests.
- API integration tests.
- Authentication tests.
- Authorization tests.
- Attachment access tests.

Security tests must verify that customers cannot access another customer's resources.

## 12. Deployment and Maintenance

The project must support:

- Local development using Wrangler.
- Local D1 database migrations.
- Local R2 development storage.
- Production migrations.
- Cloudflare Pages deployment.
- GitHub Actions CI.

Database migrations must be documented and reproducible.

## 13. Future Considerations

The architecture should allow future implementation of:

- Email notifications.
- Custom ticket fields.
- Custom ticket statuses.
- Additional authentication mechanisms.
- Multiple administrative roles.
- Alternative frontend applications.
- External API integrations.

These features must not introduce unnecessary complexity into the initial implementation.
