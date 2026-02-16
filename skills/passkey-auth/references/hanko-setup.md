# Hanko Setup

## docker-compose.yml

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: hanko
      POSTGRES_PASSWORD: hanko
      POSTGRES_DB: hanko
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "hanko"]
      interval: 5s
      retries: 5

  hanko:
    image: ghcr.io/teamhanko/hanko:latest
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8000:8000"  # Public API
      - "8001:8001"  # Admin API
    environment:
      # Database
      DATABASE_URL: postgres://hanko:hanko@postgres:5432/hanko?sslmode=disable

      # URLs
      PUBLIC_URL: http://localhost:8000
      ADMIN_URL: http://localhost:8001

      # CORS (your frontend)
      CORS_ALLOWED_ORIGINS: http://localhost:3000

      # Secrets (generate with: openssl rand -hex 32)
      SECRETS_KEYS: CHANGE_ME_TO_RANDOM_32_BYTE_HEX

      # Passkey settings
      PASSKEY_ENABLED: "true"
      PASSKEY_USER_VERIFICATION: preferred

      # Email settings (optional, for magic links)
      EMAIL_ENABLED: "false"

    volumes:
      - ./hanko-config.yaml:/etc/hanko/config.yaml

volumes:
  postgres-data:
```

## Configuration File

Create `hanko-config.yaml`:

```yaml
server:
  public:
    cors:
      allow_origins:
        - http://localhost:3000
      allow_credentials: true
  admin:
    cors:
      allow_origins:
        - http://localhost:3000

webauthn:
  relying_party:
    id: localhost
    display_name: Health Data Platform
    origins:
      - http://localhost:3000
  user_verification: preferred
  timeout: 60000

session:
  cookie:
    domain: localhost
    http_only: true
    same_site: lax
    secure: false  # Set to true in production with HTTPS
  lifespan: 720h  # 30 days

password:
  enabled: false  # Passkey-only

email:
  enabled: false
```

## Quick Start

```bash
# Start services
docker compose up -d

# Check Hanko is running
curl http://localhost:8000/.well-known/jwks.json

# View admin API
curl http://localhost:8001/health
```

## Frontend Integration

### Install Hanko Elements

```bash
npm install @teamhanko/hanko-elements
```

### React Component

```tsx
import { useEffect, useCallback, useMemo } from 'react';
import { register } from '@teamhanko/hanko-elements';

const HANKO_API_URL = 'http://localhost:8000';

export function HankoAuth() {
  const hankoApi = useMemo(() => HANKO_API_URL, []);

  useEffect(() => {
    register(hankoApi).catch(console.error);
  }, [hankoApi]);

  return (
    <hanko-auth
      style={{ '--color': '#007bff', '--border-radius': '8px' }}
    />
  );
}

export function HankoProfile() {
  const hankoApi = useMemo(() => HANKO_API_URL, []);

  useEffect(() => {
    register(hankoApi).catch(console.error);
  }, [hankoApi]);

  return <hanko-profile />;
}
```

### Getting Session Token

```typescript
import { Hanko } from '@teamhanko/hanko-elements';

const hanko = new Hanko('http://localhost:8000');

// Check if user is authenticated
const session = hanko.session.get();
if (session.isValid) {
  console.log('User ID:', session.userID);
}

// Get JWT for API calls
const jwt = await hanko.session.getJWT();
fetch('/api/protected', {
  headers: {
    Authorization: `Bearer ${jwt}`
  }
});

// Logout
await hanko.user.logout();
```

## Session Events

```typescript
import { Hanko } from '@teamhanko/hanko-elements';

const hanko = new Hanko('http://localhost:8000');

// Listen for auth state changes
hanko.onAuthFlowCompleted((detail) => {
  console.log('User authenticated:', detail.userID);
  // Redirect to dashboard
  window.location.href = '/dashboard';
});

hanko.onSessionExpired(() => {
  console.log('Session expired');
  // Redirect to login
  window.location.href = '/login';
});
```

## Production Checklist

- [ ] Use HTTPS
- [ ] Set secure cookies (`secure: true`)
- [ ] Configure proper CORS origins
- [ ] Generate secure secrets
- [ ] Set up database backups
- [ ] Configure rate limiting
- [ ] Set up monitoring
