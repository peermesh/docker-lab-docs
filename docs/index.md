---
hide:
  - navigation
  - toc
---

# Docker Lab Documentation

**Production-grade Docker Compose infrastructure for commodity VPS deployments**

---

Docker Lab is an opinionated, security-hardened Docker Compose stack that transforms a single VPS into a reliable hosting platform. It provides a complete foundation -- reverse proxy, TLS certificates, access control, observability -- all configured through declarative YAML.

This documentation is both a **learning resource** and an **operational manual**. Whether you are deploying your first container or managing multi-tenant infrastructure, Docker Lab gives you the patterns and tools to do it right.

## What You Will Learn

<div class="grid cards" markdown>

-   **Architecture & Concepts**

    ---

    Understand the layered architecture: socket proxy, reverse proxy, and application services. Learn why each layer exists and how they compose.

    [:octicons-arrow-right-24: Concepts](concepts.md)

-   **Deploy in Minutes**

    ---

    Go from a fresh VPS to a running stack with TLS certificates, basic auth, and a web dashboard in under 15 minutes.

    [:octicons-arrow-right-24: Quick Start](quick-start.md)

-   **Security by Default**

    ---

    Docker socket isolation, principle of least privilege, network segmentation, and automated TLS -- all built in from the start.

    [:octicons-arrow-right-24: Security](security.md)

-   **Observe Everything**

    ---

    Choose from lightweight monitoring (Netdata + Uptime Kuma) or full observability (Prometheus + Grafana + Loki). Both profiles are included.

    [:octicons-arrow-right-24: Observability](observability.md)

</div>

## Quick Navigation

### Getting Started

New to Docker Lab? Start here.

- [Introduction](introduction.md) -- What Docker Lab is and who it is for
- [Concepts](concepts.md) -- Architecture, design principles, and terminology
- [Quick Start](quick-start.md) -- From zero to running in 15 minutes

### Operations

Deploy and operate Docker Lab in production.

- [Foundation Stack](foundation-stack.md) -- The three core services that power everything
- [Security & Hardening](security.md) -- Socket isolation, TLS, access control
- [Deployment](deployment.md) -- VPS provisioning, configuration, and updates

### Features

Extend your stack with built-in capabilities.

- [Dashboard](dashboard.md) -- Real-time container management interface
- [Profiles](profiles.md) -- Composable service profiles for different needs
- [Observability](observability.md) -- Monitoring, metrics, and log aggregation

### Reference

Deep-dive technical content.

- [Extending Docker Lab](extending.md) -- Add your own services
- [Use Cases](use-cases.md) -- Real-world deployment patterns
- [Limitations & Roadmap](limitations.md) -- Known constraints and what is next
- [Reference](reference.md) -- Configuration, environment variables, CLI commands

---

<div style="text-align: center; margin-top: 2rem; color: var(--md-default-fg-color--lighter);">
Built by <strong>PeerMesh</strong> -- open infrastructure for everyone.
</div>
