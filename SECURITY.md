# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 1.0.x   | ✅ Yes             |
| < 1.0   | ❌ No              |

## Reporting a Vulnerability

If you discover a security vulnerability in crisp, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, email: enesdemir@example.com

### What to include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response timeline:
- **Acknowledgment**: within 48 hours
- **Initial assessment**: within 1 week
- **Fix release**: depends on severity

## Security Model

crisp is a local CLI tool that:
- Runs with user privileges (no sudo unless required by specific modules)
- Does not transmit data to external servers
- Reads/writes only to XDG-compliant directories
- Modules execute shell commands — review `crisp.conf` to control which modules run

## Best Practices

- Keep crisp updated (`crisp update`)
- Review `crisp.conf` — only enable modules you trust
- Run `crisp --dry-run` before first use
- Use Homebrew tap for installation (verified formula)
