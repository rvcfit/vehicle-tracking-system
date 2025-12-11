# Contributing to Vehicle Tracking System

Thank you for your interest in contributing to the Vehicle Tracking System! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](../../issues)
2. If not, create a new issue with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, Docker version, etc.)
   - Relevant logs

### Suggesting Features

1. Check existing issues for similar suggestions
2. Create a new issue with the `enhancement` label
3. Describe the feature and its use case
4. Explain how it benefits users

### Pull Requests

1. Fork the repository
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes following our coding standards
4. Write/update tests as needed
5. Update documentation
6. Commit with clear messages:
   ```bash
   git commit -m "feat: add vehicle type filtering"
   ```
7. Push and create a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/vehicle-tracking-system.git
cd vehicle-tracking-system

# Run setup
./setup.sh

# Start in development mode
docker compose up
```

## Coding Standards

### Java (Spring Boot)
- Follow Google Java Style Guide
- Use Lombok for boilerplate reduction
- Write unit tests with JUnit 5

### Node.js
- Use ESLint with Airbnb config
- Write tests with Jest
- Use async/await over callbacks

### Python
- Follow PEP 8
- Use type hints
- Write tests with pytest

### Docker
- Use multi-stage builds
- Run as non-root user
- Include health checks

## Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `style:` Formatting
- `refactor:` Code restructuring
- `test:` Tests
- `chore:` Maintenance

## Questions?

Feel free to open an issue with the `question` label or reach out to the maintainers.

Thank you for contributing! 🎉
