# Docker Lab Documentation

Public documentation for [Docker Lab](https://github.com/peermesh/docker-lab) -- production-grade Docker Compose infrastructure for commodity VPS deployments.

**Live site:** [peermesh.github.io/docker-lab-docs](https://peermesh.github.io/docker-lab-docs/)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/peermesh/docker-lab-docs.git
cd docker-lab-docs

# Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start local dev server
mkdocs serve
```

The docs site will be available at `http://localhost:8000`.

## Project Structure

```
docker-lab-docs/
├── mkdocs.yml              # Site configuration
├── requirements.txt        # Python dependencies
├── docs/                   # Documentation source
│   ├── index.md            # Landing page
│   ├── introduction.md     # Ch 1: Introduction
│   ├── concepts.md         # Ch 2: Concepts
│   ├── quick-start.md      # Ch 3: Quick Start
│   ├── foundation-stack.md # Ch 4: Foundation Stack
│   ├── profiles.md         # Ch 5: Profiles
│   ├── security.md         # Ch 6: Security
│   ├── deployment.md       # Ch 7: Deployment
│   ├── dashboard.md        # Ch 8: Dashboard
│   ├── multi-instance.md   # Ch 9: Multi-Instance
│   ├── observability.md    # Ch 10: Observability
│   ├── extending.md        # Ch 11: Extending
│   ├── use-cases.md        # Ch 12: Use Cases
│   ├── limitations.md      # Ch 13: Limitations
│   ├── reference.md        # Ch 14: Reference
│   ├── assets/             # Static assets
│   └── diagrams/           # Excalidraw source files
├── overrides/              # Theme overrides
└── scripts/                # Dev utilities
```

## Contributing

Contributions are welcome. To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b docs/your-topic`)
3. Make your changes
4. Submit a pull request

Please ensure all markdown follows proper heading hierarchy and builds without warnings (`mkdocs build --strict`).

## License

This documentation is released under the [MIT License](https://opensource.org/licenses/MIT).
