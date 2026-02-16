---
name: passkey-auth
description: Use when adding passwordless/WebAuthn authentication, evaluating auth providers, or integrating passkeys
---

# Passkey Authentication

## Overview

Integrate passkey/WebAuthn using proven OSS solutions.

**Announce at start:** "I'm using the passkey-auth skill to evaluate authentication options."

## When to Use

- Adding passwordless auth
- Evaluating auth providers
- Modernizing authentication

## Options

| Solution | Complexity | Best For |
|----------|------------|----------|
| **Hanko** | Low | Fast integration |
| **Keycloak** | Medium | Enterprise, SSO |
| **Zitadel** | Medium | Modern, cloud-native |
| **Custom** | High | Full control |

## Recommendation

**MVP:** Use Hanko (OSS, self-hosted, passkey-first)
**Enterprise:** Keycloak if SSO/SAML needed
**Learning:** Keep mpo-api-authn-server as reference

## References

- @references/options-comparison.md - Detailed comparison
- @references/hanko-setup.md - Recommended setup
- @references/keycloak-setup.md - Enterprise option
- @references/fastapi-integration.md - Backend integration

## Completion Criteria

- [ ] Auth service running
- [ ] Can register passkey
- [ ] Can authenticate
- [ ] JWT tokens issued
- [ ] Backend verifies tokens
