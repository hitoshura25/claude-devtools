# FastAPI JWT Verification

## Installation

```bash
pip install python-jose[cryptography] httpx
```

## JWT Verification (Generic)

Works with Hanko, Keycloak, or any OIDC provider:

```python
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
import httpx
from functools import lru_cache
from typing import Optional
import time

app = FastAPI()
security = HTTPBearer()

# Configuration
JWKS_URL = "http://localhost:8000/.well-known/jwks.json"  # Hanko
# JWKS_URL = "http://localhost:8080/realms/health-platform/protocol/openid-connect/certs"  # Keycloak
ISSUER = "http://localhost:8000"  # Hanko
# ISSUER = "http://localhost:8080/realms/health-platform"  # Keycloak
AUDIENCE = None  # Set if needed

# JWKS cache
_jwks_cache = {"keys": None, "expires": 0}


async def get_jwks() -> dict:
    """Fetch and cache JWKS."""
    now = time.time()

    if _jwks_cache["keys"] and _jwks_cache["expires"] > now:
        return _jwks_cache["keys"]

    async with httpx.AsyncClient() as client:
        response = await client.get(JWKS_URL)
        response.raise_for_status()
        jwks = response.json()

    _jwks_cache["keys"] = jwks
    _jwks_cache["expires"] = now + 3600  # Cache for 1 hour

    return jwks


def get_public_key(token: str, jwks: dict) -> dict:
    """Get the public key for a token from JWKS."""
    unverified_header = jwt.get_unverified_header(token)
    kid = unverified_header.get("kid")

    for key in jwks.get("keys", []):
        if key.get("kid") == kid:
            return key

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Unable to find appropriate key"
    )


async def verify_token(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> dict:
    """Verify JWT and return claims."""
    token = credentials.credentials

    try:
        jwks = await get_jwks()
        public_key = get_public_key(token, jwks)

        payload = jwt.decode(
            token,
            public_key,
            algorithms=["RS256", "ES256"],
            issuer=ISSUER,
            audience=AUDIENCE,
            options={"verify_aud": AUDIENCE is not None}
        )

        return payload

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}"
        )


# Dependency to get current user
async def get_current_user(claims: dict = Depends(verify_token)) -> dict:
    """Extract user info from JWT claims."""
    return {
        "id": claims.get("sub"),
        "email": claims.get("email"),
        "claims": claims
    }
```

## Protected Routes

```python
from fastapi import FastAPI, Depends

app = FastAPI()


@app.get("/api/me")
async def get_me(user: dict = Depends(get_current_user)):
    """Get current user info."""
    return {
        "user_id": user["id"],
        "email": user.get("email")
    }


@app.get("/api/glucose")
async def get_glucose_readings(
    user: dict = Depends(get_current_user),
    limit: int = 100
):
    """Get glucose readings for current user."""
    readings = await fetch_glucose_readings(user["id"], limit)
    return {"readings": readings}


@app.post("/api/glucose")
async def create_glucose_reading(
    reading: GlucoseReading,
    user: dict = Depends(get_current_user)
):
    """Create a new glucose reading."""
    result = await save_glucose_reading(user["id"], reading)
    return {"id": result.id}
```

## Role-Based Access Control

```python
from fastapi import Depends, HTTPException, status
from typing import List


def require_roles(required_roles: List[str]):
    """Dependency to check user roles."""

    async def check_roles(claims: dict = Depends(verify_token)):
        # Keycloak puts roles in realm_access.roles
        user_roles = claims.get("realm_access", {}).get("roles", [])

        # Or in a custom claim
        user_roles = user_roles or claims.get("roles", [])

        if not any(role in user_roles for role in required_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions"
            )

        return claims

    return check_roles


@app.get("/api/admin/users")
async def list_users(
    claims: dict = Depends(require_roles(["admin"]))
):
    """Admin-only endpoint."""
    return await fetch_all_users()


@app.delete("/api/admin/users/{user_id}")
async def delete_user(
    user_id: str,
    claims: dict = Depends(require_roles(["admin", "user-manager"]))
):
    """Delete user (admin or user-manager role required)."""
    await delete_user_by_id(user_id)
    return {"deleted": user_id}
```

## Testing

```python
# tests/test_auth.py
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, AsyncMock

from app.main import app


@pytest.fixture
def mock_jwt_claims():
    return {
        "sub": "user-123",
        "email": "test@example.com",
        "iss": "http://localhost:8000"
    }


@pytest.fixture
def auth_headers(mock_jwt_claims):
    # In real tests, generate a valid test token
    return {"Authorization": "Bearer test-token"}


def test_protected_route_unauthorized():
    """Test that protected routes require auth."""
    client = TestClient(app)
    response = client.get("/api/me")
    assert response.status_code == 403  # No auth header


@patch("app.auth.verify_token")
def test_protected_route_authorized(mock_verify, mock_jwt_claims):
    """Test that protected routes work with valid auth."""
    mock_verify.return_value = mock_jwt_claims

    client = TestClient(app)
    response = client.get(
        "/api/me",
        headers={"Authorization": "Bearer test-token"}
    )

    assert response.status_code == 200
    assert response.json()["user_id"] == "user-123"
```

## CORS Configuration

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Your frontend
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```
