# Keycloak Setup

## docker-compose.yml

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: keycloak
      POSTGRES_DB: keycloak
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "keycloak"]
      interval: 5s
      retries: 5

  keycloak:
    image: quay.io/keycloak/keycloak:23.0
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8080:8080"
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: keycloak

      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin

      KC_HOSTNAME: localhost
      KC_HOSTNAME_PORT: 8080
      KC_HOSTNAME_STRICT: "false"
      KC_HTTP_ENABLED: "true"
    command: start-dev

volumes:
  postgres-data:
```

## Quick Start

```bash
# Start services
docker compose up -d

# Wait for startup
sleep 30

# Access admin console
open http://localhost:8080/admin
# Login: admin / admin
```

## Configure Realm

### 1. Create Realm

1. Click dropdown next to "master" → Create Realm
2. Name: `health-platform`
3. Click Create

### 2. Enable WebAuthn

1. Go to Authentication → Policies → WebAuthn Policy
2. Configure:
   - Relying Party Entity Name: `Health Data Platform`
   - Signature Algorithms: `ES256` (recommended)
   - Relying Party ID: `localhost`
   - Attestation Conveyance Preference: `not specified`
   - User Verification Requirement: `preferred`
3. Save

### 3. Create Authentication Flow

1. Go to Authentication → Flows
2. Duplicate "browser" flow → Name: `passkey-browser`
3. Configure flow:
   ```
   passkey-browser
   ├── Cookie (ALTERNATIVE)
   ├── Kerberos (DISABLED)
   ├── Identity Provider Redirector (ALTERNATIVE)
   └── passkey-browser forms
       ├── Username Form (REQUIRED)
       └── WebAuthn Authenticator (REQUIRED)
   ```
4. Bind flow: Authentication → Bindings → Browser Flow → `passkey-browser`

### 4. Create Client

1. Go to Clients → Create
2. Configure:
   - Client ID: `health-platform-web`
   - Client Protocol: `openid-connect`
   - Root URL: `http://localhost:3000`
3. Settings:
   - Access Type: `public`
   - Valid Redirect URIs: `http://localhost:3000/*`
   - Web Origins: `http://localhost:3000`

## Backend Configuration

### Get JWKS

```bash
curl http://localhost:8080/realms/health-platform/protocol/openid-connect/certs
```

### Token Endpoint

```bash
# Get token (for testing)
curl -X POST http://localhost:8080/realms/health-platform/protocol/openid-connect/token \
  -d "client_id=health-platform-web" \
  -d "username=testuser" \
  -d "password=testpass" \
  -d "grant_type=password"
```

## Frontend Integration

### Using keycloak-js

```bash
npm install keycloak-js
```

```typescript
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'health-platform',
  clientId: 'health-platform-web'
});

// Initialize
keycloak.init({
  onLoad: 'check-sso',
  silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html'
}).then(authenticated => {
  if (authenticated) {
    console.log('User is authenticated');
    console.log('Token:', keycloak.token);
  } else {
    keycloak.login();
  }
});

// Logout
keycloak.logout();

// Get token for API
fetch('/api/protected', {
  headers: {
    Authorization: `Bearer ${keycloak.token}`
  }
});
```

## Production Considerations

- Use `start` instead of `start-dev`
- Configure HTTPS
- Set up proper database
- Configure clustering for HA
- Set up proper admin credentials
- Enable audit logging
