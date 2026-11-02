# Core Ticket System — Architecture

## 1. Project Philosophy

Core Ticket System is an open-source, self-hosted ticket management system.

Its purpose is to provide a minimal, secure, and extensible ticket management engine that can be integrated into different business environments.

Each organization operates its own independent installation.

The project does not implement centralized multi-tenancy. Each installation has its own application instance, database, storage resources, configuration, and Identity Provider integration.

### Core Principles

- Simplicity over unnecessary abstraction.
- Security by default.
- API-first development.
- Relational data modeling.
- Minimal operational dependencies.
- Independent frontend and backend.
- Separation of authentication and authorization.
- External identity management through standard protocols.
- Community-friendly development.

## 2. Deployment Architecture

The application runs on Cloudflare Pages with Pages Functions.

### Components

**Frontend**

- Astro.
- Static generation.
- TypeScript for browser interactions.
- Communicates with the backend through REST.
- Does not implement authentication protocols.
- Does not store authentication tokens.

**Backend**

- Cloudflare Pages Functions.
- TypeScript.
- REST API under `/api/v1`.
- Business logic separated from HTTP handlers.
- Responsible for authentication sessions and authorization.
- Integrates with an external OpenID Connect Identity Provider.

**Database**

- Cloudflare D1.
- SQLite relational model.
- Explicit SQL queries.
- Schema migrations.

**Object Storage**

- Cloudflare R2.
- Private storage for ticket attachments.
- Access mediated by authenticated API endpoints.

**Identity Provider**

- External OpenID Connect (OIDC) provider.
- Responsible for user authentication and credential management.
- Configured independently for each installation.
- Must support OIDC Discovery and Authorization Code Flow with PKCE.

### Runtime Architecture

The initial deployment uses Astro as a static site generator.

Pages Functions handle dynamic backend operations independently.

The project must not depend on Astro server-side rendering or a frontend-specific runtime for its API.

This separation keeps the backend accessible to alternative frontend implementations.

The frontend and backend should preferably be deployed under the same origin to simplify session cookie management and avoid unnecessary CORS configuration.

If separate origins are required, CORS and cookie policies must be explicitly configured and restricted to trusted origins.

## 3. Application Modules

The backend should be organized around the following responsibilities.

### Authentication

Responsible for:

- OIDC authorization flow initiation.
- OIDC callback processing.
- Identity Provider response validation.
- External identity resolution.
- Local application session creation.
- Session expiration.
- Session revocation.
- Current authenticated user retrieval.
- Local logout.

Authentication must be independent of the Identity Provider implementation.

### Authorization

Responsible for:

- Role verification.
- Resource ownership validation.
- Administrative permissions.
- Customer access restrictions.
- Access control for tickets, messages, attachments, and customer records.

Authorization is enforced exclusively by the backend.

### Identity Association

Responsible for:

- Associating local users with external identities.
- Validating the configured OIDC issuer.
- Enforcing uniqueness of external identity associations.
- Maintaining the relationship between local user records and external identities.

The application must never associate identities based exclusively on email addresses.

### Users and Customers

Responsible for:

- Local user records.
- Customer account management.
- Customer activation and deactivation.
- External identity association.
- Local account status.

The application does not manage passwords or external credentials.

### Tickets

Responsible for:

- Ticket creation.
- Ticket listing and filtering.
- Ticket details.
- Status changes.
- Priority management.
- Ticket ownership.
- Ticket history.

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

### Categories

Responsible for:

- Ticket categories.
- Category creation and updates.
- Category activation and deactivation.

## 4. Authentication Architecture

Authentication is delegated to an external OpenID Connect (OIDC) Identity Provider.

Core Ticket System does not implement its own credential management system.

The application does not store passwords, password hashes, or Identity Provider credentials.

### 4.1. Identity Provider Configuration

Each installation supports one configured OIDC provider.

The implementation must remain provider-agnostic and follow the OpenID Connect standard.

The following configuration values are required:

| Variable | Description |
|---|---|
| `OIDC_ISSUER_URL` | Configured Identity Provider issuer URL |
| `OIDC_CLIENT_ID` | Registered OIDC client identifier |
| `OIDC_CLIENT_SECRET` | Confidential client secret |
| `OIDC_REDIRECT_URI` | Explicitly registered backend callback URI |
| `APP_BASE_URL` | Canonical application base URL |

The client secret must be stored using Cloudflare Secrets or an equivalent secure secret-management mechanism.

It must never be exposed to the frontend, stored in D1, committed to source control, or included in logs.

Development, preview, and production environments must use independent configurations and credentials.

The backend must use OIDC Discovery to retrieve the provider metadata and obtain the authorization, token, and JWKS endpoints.

The discovered issuer must match the configured issuer.

Redirect URIs must be explicitly configured and validated. They must not be constructed using untrusted Host or forwarded headers.

### 4.2. OIDC Authentication Flow

The application uses:

- OpenID Connect Authorization Code Flow.
- Proof Key for Code Exchange (PKCE).
- A confidential client managed by the backend.
- Server-side processing of the authorization callback.

The authentication flow is:

1. The user selects the login action in the frontend.
2. The browser is redirected to `GET /api/v1/auth/login`.
3. The backend generates and stores the necessary authorization transaction data, including `state`, `nonce`, and PKCE parameters.
4. The backend redirects the browser to the Identity Provider.
5. The user authenticates with the Identity Provider.
6. The Identity Provider redirects the browser to the configured backend callback URI.
7. The backend validates the authorization response and exchanges the authorization code for tokens.
8. The backend validates the ID Token.
9. The backend resolves the external identity to an existing local user.
10. The backend creates a local application session.
11. The backend sets the session cookie.
12. The backend redirects the browser to an allowed internal application URL.

The frontend must never process the authorization code, ID Token, or access token.

### 4.3. OIDC Validation Requirements

The backend must validate:

- Authorization transaction `state`.
- PKCE code verifier.
- `nonce`.
- ID Token signature.
- Issuer (`iss`).
- Audience (`aud`).
- Expiration (`exp`).
- Issued-at timestamp (`iat`).

Signature verification must use the provider's published JWKS and an explicit algorithm allowlist.

The backend must reject invalid, expired, or incorrectly issued tokens.

Identity resolution must use the combination of:

- `iss`: Identity Provider issuer.
- `sub`: Subject identifier.

The pair `(iss, sub)` is the external identity key.

Email addresses must never be used as the sole identity key.

### 4.4. Local User Resolution

A valid OIDC authentication does not automatically grant access to the application.

The backend must resolve the external identity to an existing local user record.

Requirements:

- The external identity must already be associated with a local user.
- The issuer must match the configured provider.
- The subject must match the associated external identity.
- The local user must be active.
- The local application role determines authorization.

If no matching local user exists, access must be denied.

The application must not automatically create users during OIDC login.

Identity association is performed through a trusted administrative provisioning procedure.

### 4.5. Local Application Sessions

The application maintains its own sessions independently of the Identity Provider.

Sessions are persisted in D1.

A session consists of:

- Random session identifier.
- Associated local user.
- Session creation timestamp.
- Expiration timestamp.
- Optional revocation timestamp.

Only a cryptographic hash of the session identifier must be stored in D1.

The original identifier is sent to the browser through a secure cookie.

Session cookies must use:

- `HttpOnly`.
- `Secure` in production.
- Appropriate `SameSite` policy.
- Host-only scope where possible.
- Appropriate `Path`.
- Explicit expiration.

The backend must validate the local session on every protected API request.

Session identifiers must be rotated after successful authentication.

State-changing authenticated requests must implement CSRF protection through appropriate token and/or origin validation mechanisms.

The application must not expose session identifiers to JavaScript.

### 4.6. Logout

Local logout invalidates the current application session.

The backend must:

- Revoke the local session.
- Clear the session cookie.
- Reject subsequent requests using the revoked session.

Local logout does not necessarily terminate the user's global Identity Provider session.

The application must not assume that logging out of Core Ticket System also logs the user out of other applications using the same Identity Provider.

### 4.7. Authentication Responsibilities

| Responsibility | Component |
|---|---|
| Credential management | Identity Provider |
| User authentication | Identity Provider |
| OIDC protocol validation | Backend |
| External identity resolution | Backend |
| Local user records | Core Ticket System |
| Application sessions | Core Ticket System |
| Application roles | Core Ticket System |
| Resource authorization | Core Ticket System |

## 5. Authorization Model

Authentication and authorization are separate responsibilities.

The Identity Provider establishes the user's external identity.

Core Ticket System determines what that user can access within the installation.

Authorization is enforced by the backend.

### 5.1. Initial Roles

Two roles are initially supported:

| Role | Description |
|---|---|
| `admin` | Full administrative access within the installation. |
| `customer` | Access restricted to owned resources. |

Roles are stored locally and must not depend on claims or role assignments provided by the Identity Provider.

### 5.2. Administrator

An administrator can:

- View all tickets.
- Create and manage tickets.
- View all customers.
- Create customer records.
- Update customer profile information.
- Activate and deactivate customers.
- Respond to tickets.
- Change ticket status.
- Manage ticket priorities.
- Manage ticket categories.
- View authorized ticket attachments.

Administrator accounts must be provisioned through a trusted installation procedure.

Public administrator registration is forbidden.

### 5.3. Customer

A customer can:

- Create tickets.
- View their own tickets.
- View messages belonging to their tickets.
- Reply to their own tickets.
- Upload attachments to their own tickets.
- Download authorized attachments.
- Access permitted information from their own account.

Customers must never:

- Access resources belonging to another customer.
- Modify their own role.
- Change their account status.
- Create administrator accounts.
- Access administrative endpoints.
- Modify administrative ticket fields unless explicitly permitted.

### 5.4. Resource Ownership

Ownership must be verified by the backend using the local user ID.

The application must never trust client-provided ownership information.

For example:

- Ticket ownership is determined by `tickets.customer_id`.
- Message authorship is determined by the authenticated local user.
- Attachment access is validated against the associated ticket.
- Customer account access is restricted to the corresponding local user.

Ownership checks must occur in the service or data-access layer.

Frontend route protection and role-based navigation are usability mechanisms, not security boundaries.

### 5.5. Authorization Response Rules

The API should use consistent authorization responses:

- `401 Unauthorized`: missing or invalid authentication.
- `403 Forbidden`: authenticated user without permission.
- `404 Not Found`: resource does not exist or its existence is intentionally concealed from the requesting user.

Authorization must follow a deny-by-default policy.

## 6. Database Model

The database uses a relational model implemented with Cloudflare D1.

The application uses explicit SQL queries rather than an ORM.

### 6.1. users

Stores local application user records and their external identity associations.

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| identity_issuer | TEXT | External OIDC issuer |
| identity_subject | TEXT | External OIDC subject |
| name | TEXT | User name |
| email | TEXT | Contact email |
| role | TEXT | `admin` or `customer` |
| is_active | INTEGER | Local account status |
| created_at | TEXT | Creation timestamp |
| updated_at | TEXT | Last update |

Constraints:

- `(identity_issuer, identity_subject)` must be unique.
- The external issuer must match the configured Identity Provider.
- `role` must be validated against supported roles.
- `is_active` determines local application access.
- Email must not be used as an external identity key.

Email uniqueness may be enforced as an application data constraint, but it must never be used to associate an external identity automatically.

No password or password hash must be stored.

### 6.2. sessions

Stores local application sessions.

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| user_id | TEXT | Associated local user |
| token_hash | TEXT | Hashed session identifier |
| expires_at | TEXT | Expiration timestamp |
| created_at | TEXT | Creation timestamp |
| revoked_at | TEXT | Optional revocation timestamp |

Constraints:

- `user_id` references `users.id`.
- Only the hashed session identifier is persisted.
- Expired or revoked sessions must be rejected.
- Sessions belonging to inactive users must not grant access.

### 6.3. tickets

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| customer_id | TEXT | Local user who owns the ticket |
| category_id | TEXT | Optional category |
| subject | TEXT | Ticket subject |
| description | TEXT | Initial description |
| status | TEXT | Current status |
| priority | TEXT | Ticket priority |
| metadata | TEXT | Optional validated JSON |
| created_at | TEXT | Creation timestamp |
| updated_at | TEXT | Last update |

`customer_id` references `users.id`.

Ticket ownership must use the local user identifier, never the external OIDC subject.

### 6.4. ticket_messages

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| ticket_id | TEXT | Associated ticket |
| author_id | TEXT | Local user who authored the message |
| message | TEXT | Message content |
| created_at | TEXT | Creation timestamp |

`ticket_id` references `tickets.id`.

`author_id` references `users.id`.

### 6.5. ticket_attachments

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| ticket_id | TEXT | Associated ticket |
| message_id | TEXT | Optional associated message |
| uploaded_by | TEXT | Local uploading user |
| object_key | TEXT | R2 object identifier |
| original_name | TEXT | Original filename |
| mime_type | TEXT | Validated MIME type |
| size_bytes | INTEGER | File size |
| created_at | TEXT | Upload timestamp |

`ticket_id` references `tickets.id`.

`message_id` references `ticket_messages.id` when applicable.

`uploaded_by` references `users.id`.

### 6.6. ticket_categories

| Column | Type | Description |
|---|---|---|
| id | TEXT | Primary key |
| name | TEXT | Category name |
| description | TEXT | Optional description |
| is_active | INTEGER | Category status |
| created_at | TEXT | Creation timestamp |

### 6.7. Database Rules

- Every table must have an explicit primary key.
- Foreign keys must be defined.
- Foreign-key enforcement must be enabled and verified.
- Appropriate indexes must be created.
- Use parameterized SQL queries.
- Schema modifications must use migrations.
- Do not modify already-applied migrations.
- Do not store attachment arrays as JSON.
- Do not use JSON for information that naturally belongs in relational columns.
- JSON metadata must be validated before persistence.
- Historical ticket and message records must be preserved when users are deactivated.
- User deactivation must not cascade-delete historical records.

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

Attachment access must always be validated against the associated ticket.

Deactivating a user must not automatically delete historical attachments.

## 8. API Architecture

All API endpoints must use the `/api/v1` prefix.

The API must remain independent of the frontend implementation and Identity Provider vendor.

### 8.1. Authentication

- GET `/api/v1/auth/login`
- GET `/api/v1/auth/callback`
- POST `/api/v1/auth/logout`
- GET `/api/v1/auth/me`

Responsibilities:

- `/login`: initiates the OIDC authorization flow.
- `/callback`: processes the Identity Provider authorization response.
- `/logout`: revokes the local application session.
- `/me`: returns the current authenticated user's permitted profile information.

The OIDC callback is processed exclusively by the backend.

The frontend must never receive or process OIDC tokens.

### 8.2. Customers

Administrative customer management endpoints:

- GET `/api/v1/customers`
- POST `/api/v1/customers`
- GET `/api/v1/customers/:id`
- PATCH `/api/v1/customers/:id`
- POST `/api/v1/customers/:id/activate`
- POST `/api/v1/customers/:id/deactivate`

Requirements:

- Only administrators may access customer management endpoints.
- Customer creation must associate an existing external identity.
- New customer records must always receive the `customer` role.
- Identity association must use `identity_issuer` and `identity_subject`.
- Email matching alone must never establish identity association.
- Customer deactivation must revoke active local sessions.
- Customer deactivation must preserve historical records.

### 8.3. Tickets

- GET `/api/v1/tickets`
- POST `/api/v1/tickets`
- GET `/api/v1/tickets/:id`
- PATCH `/api/v1/tickets/:id`

The API must support:

- Ticket creation.
- Ticket listing.
- Filtering.
- Searching.
- Pagination.
- Ticket details.
- Permitted ticket updates.

Administrators can access all tickets.

Customers can access only their own tickets.

Customer ownership must be derived from the authenticated local user context.

The backend must never trust a customer ID supplied by the frontend.

### 8.4. Messages

- GET `/api/v1/tickets/:id/messages`
- POST `/api/v1/tickets/:id/messages`

The API must verify access to the associated ticket before returning or creating messages.

Message authorship must be derived from the authenticated local user.

### 8.5. Attachments

- POST `/api/v1/tickets/:id/attachments`
- GET `/api/v1/attachments/:id`

The API must validate ticket ownership or administrative permissions before allowing upload or download operations.

R2 access must never be exposed directly to unauthorized users.

### 8.6. Categories

Administrative endpoints for category management must be implemented under an appropriate categories resource.

Category access and modification must follow the authorization model.

### 8.7. API Requirements

Every endpoint must define:

- Authentication requirements.
- Authorization requirements.
- Input validation.
- Expected responses.
- Error handling.

All request payloads must be validated using Zod.

Database access must use parameterized SQL queries.

Business logic must remain separated from HTTP handlers.

## 9. Frontend Architecture

The frontend is implemented with Astro using static generation and TypeScript.

It communicates with the backend through the REST API.

### 9.1. Authentication Integration

The frontend must:

- Redirect users to `GET /api/v1/auth/login` to initiate authentication.
- Retrieve the current user through `GET /api/v1/auth/me`.
- Maintain an application-level authentication state.
- Call `POST /api/v1/auth/logout` to end the local session.
- Include browser credentials in requests that require the session cookie.

The frontend must not:

- Implement OIDC protocol logic.
- Process the OIDC callback.
- Store ID Tokens or access tokens.
- Store session identifiers in JavaScript-accessible storage.
- Expose Identity Provider credentials.
- Treat locally cached user information as proof of authentication.

### 9.2. Role-Based Navigation

The frontend may display different navigation structures according to the authenticated user's local role.

This improves usability but does not replace backend authorization.

### 9.3. Route Protection

Because the frontend uses static generation, route protection is implemented as a client-side navigation mechanism.

The frontend should check authentication before rendering protected application areas.

However, static frontend routes must never be considered a security boundary.

All sensitive data and operations must remain protected by backend authentication and authorization.

Do not introduce SSR solely to implement route protection.

### 9.4. Session Cookies and API Requests

Authenticated requests must include browser credentials where required.

Use `credentials: "include"` for cross-origin requests that rely on cookies.

The preferred deployment model is same-origin frontend and backend.

If cross-origin deployment is necessary:

- Allow only explicitly configured trusted origins.
- Enable credentials only for approved origins.
- Never combine credentialed requests with wildcard origins.
- Configure cookie attributes appropriately.
- Apply CSRF protection to state-changing operations.

## 10. Error Handling

Use consistent HTTP status codes.

The API should return structured JSON errors.

Never expose:

- SQL errors.
- Internal stack traces.
- Session tokens.
- Infrastructure credentials.
- Identity Provider client secrets.
- Sensitive authentication data.

Authentication and authorization errors must not disclose unnecessary information about local accounts or external identities.

The API must distinguish between:

- Invalid or missing authentication.
- Insufficient permissions.
- Invalid input.
- Missing resources.
- Unexpected internal errors.

## 11. Configuration and Secrets

Cloudflare bindings:

- `DB`: D1 database.
- `STORAGE`: R2 bucket.

OIDC configuration:

- `OIDC_ISSUER_URL`
- `OIDC_CLIENT_ID`
- `OIDC_CLIENT_SECRET`
- `OIDC_REDIRECT_URI`
- `APP_BASE_URL`

The OIDC client secret must be stored as an encrypted Cloudflare Secret.

Other environment-specific values must be configured through appropriate environment variables.

Development, preview, and production environments must use independent resources and credentials.

Never commit real credentials or secrets.

Local development secrets must be stored in ignored environment files, such as `.dev.vars`.

The application must never expose secret configuration to the browser.

## 12. Testing Strategy

The project must include:

- Unit tests for business logic.
- Repository integration tests.
- API integration tests.
- OIDC authentication tests.
- Session management tests.
- Authorization tests.
- Customer management tests.
- Ticket ownership tests.
- Attachment access tests.
- Frontend authentication integration tests.

Security tests must verify that:

- Invalid OIDC responses are rejected.
- Invalid or expired sessions are rejected.
- Inactive users cannot access protected resources.
- Customers cannot access another customer's resources.
- Customers cannot access administrative endpoints.
- External identities cannot be associated through email matching alone.
- Local logout revokes the application session.
- Deactivated customers cannot authenticate into the application.
- Unauthorized users cannot access private R2 objects.

Tests must use isolated databases, mocked Identity Provider responses, and fictitious data.

Never use production credentials or sessions.

## 13. Deployment and Maintenance

The project must support:

- Local development using Wrangler.
- Local D1 database migrations.
- Local R2 development storage.
- OIDC configuration for local development.
- Independent preview and production environments.
- Production database migrations.
- Cloudflare Pages deployment.
- GitHub Actions CI.

Database migrations must be documented and reproducible.

OIDC redirect URIs must be registered separately for each environment.

Production secrets must be configured through Cloudflare's secret-management facilities.

## 14. Architectural Constraints

The following constraints must be preserved throughout development:

1. Each installation is independent and single-tenant.
2. Authentication is delegated to one external OIDC provider per installation.
3. The application does not store passwords or manage credentials.
4. OIDC protocol processing occurs exclusively in the backend.
5. Local application sessions are independent of the Identity Provider session.
6. Roles and permissions are managed locally.
7. External identities are identified by `(identity_issuer, identity_subject)`.
8. Email addresses must never be used as the sole identity association key.
9. Local user records must exist before an external identity can access the application.
10. User deactivation must preserve historical ticket data.
11. All resource ownership and authorization checks are enforced by the backend.
12. R2 objects must remain private.
13. The frontend remains statically generated.
14. The API must remain independent of the frontend and Identity Provider vendor.

## 15. Future Considerations

The architecture should allow future implementation of:

- Email notifications.
- Custom ticket fields.
- Custom ticket statuses.
- Additional administrative roles.
- External API integrations.
- Automated Identity Provider user provisioning.
- Identity Provider invitation workflows.
- Additional frontend applications.
- Audit logging.
- Advanced permission policies.

These features must not introduce unnecessary complexity into the initial implementation.

Support for multiple Identity Providers per installation and standalone local authentication are not part of the initial architecture.

Any future authentication mechanism must preserve the separation between authentication, local application sessions, and authorization.
