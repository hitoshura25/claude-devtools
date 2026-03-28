# Phase 3: Vetted Design Doc — Detailed Guidance

## The Core Rule

Every statement in the design doc must be traceable to something the prototype
demonstrated or something the cross-cutting research revealed. If the prototype
didn't touch a concern, say "not validated by prototype" rather than speculating.

A design doc that says "the API returns JSON with fields X, Y, Z" because the
prototype actually called the API and got those fields is infinitely more valuable
than one that says "the API probably returns JSON" based on reading documentation.

## Generating the Doc

Use the template in `references/design-doc-template.md` as the structural guide.
Create the doc at `docs/design/<feature-name>-<YYYY-MM-DD>.md` (using today's date), creating the directory if needed.

### Section-by-section guidance

**Architecture Overview**: Describe the components the prototype revealed are needed.
Reference specific prototype files. If the prototype showed that what seemed like
one component is actually two (common discovery), explain why.

**Prototype Reference**: Point to `prototypes/<feature-name>/` and describe
what it proves. This section is the "evidence" that backs up the rest of the doc.

**Data Model**: Describe data structures the prototype used. If the prototype
interacted with external data (APIs, databases, files), document the actual shapes
observed, not the theoretical ones from documentation.

**Testing Strategy**: Based on Phase 2 research. Be specific about what to mock —
the prototype revealed real external dependencies. Reference the project's existing
test infrastructure if it has one.

**Containerization**: Based on Phase 2 research. Include the specific base image
entrypoint behavior discovered. If containerization is not applicable, say so with
a one-line explanation and move on.

**Security Posture**: Based on Phase 2 research. Focus on the specific data flows
the prototype revealed. Generic security advice ("validate all inputs") is useless —
name the specific inputs, the specific validation needed, and why.

**Deployment Strategy**: Based on Phase 2 research. Describe how this feature
integrates with the existing deployment pipeline. If it introduces new infrastructure
dependencies, name them explicitly.

**Open Questions**: Anything the prototype didn't resolve. Be honest about gaps.
A good design doc admits what it doesn't know rather than papering over uncertainty.

## Writing Quality

### Do

- Use concrete language: "The API returns a JSON array of objects with `id` (string),
  `timestamp` (ISO 8601), and `value` (float)" — not "The API returns data."
- Reference specific files: "See `prototypes/health-sync/fetch.py` lines 23-31
  for the actual API response parsing."
- Note surprises: "The documentation says the API supports batch requests, but the
  prototype found that batch requests over 100 items return a 413 error."

### Don't

- Include code blocks from the prototype. Reference the file instead. Code blocks in
  design docs look authoritative but go stale. The prototype is the authority.
- Speculate about performance. If the prototype measured something, report it. If not,
  list it as an open question.
- Over-specify implementation details. The design doc describes *what* and *why*.
  Future task decomposition will handle *how*.

## Consumability for Future Phases

The design doc will eventually be consumed by a task decomposition phase (Phase 4,
not yet built). To make that possible:

- Use consistent heading levels (H2 for major sections, H3 for subsections)
- Keep each section self-contained — a future parser should be able to extract
  "Testing Strategy" without needing context from "Architecture Overview"
- Use the exact section names from the template — don't rename them creatively
- End each section with a clear boundary (no trailing thoughts that belong in
  the next section)
