# Security Policy

## Supported Versions

Security updates are applied to the latest release on the `main` branch.

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| Older   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Ensemble, please report it responsibly. **Do not open a public GitHub issue for security vulnerabilities.**

### How to Report

Send an email to **sharjeel@ensembleui.com** with:

- A description of the vulnerability
- Steps to reproduce the issue
- The potential impact
- Any suggested fixes (if applicable)

### What to Expect

- **Acknowledgment:** We will acknowledge receipt of your report within 48 hours.
- **Assessment:** We will investigate and assess the severity of the vulnerability.
- **Resolution:** We will work on a fix and coordinate disclosure with you.
- **Credit:** We are happy to credit reporters in release notes (unless you prefer to remain anonymous).

## Security Best Practices for Users

When using Ensemble in your applications:

- Keep your Ensemble dependencies up to date.
- Do not commit sensitive credentials (API keys, Firebase config with secrets, etc.) to your repository. Use environment variables or `.env` files excluded from version control.
- Review the `ensemble-config.yaml` for any sensitive configuration before committing.
- When using `from: remote` for app definitions, ensure your server uses HTTPS and is properly configured against CORS attacks.
- Follow the [Flutter security best practices](https://docs.flutter.dev/security) for your deployed applications.

## Scope

This security policy applies to the code in the [EnsembleUI/ensemble](https://github.com/EnsembleUI/ensemble) repository. For security issues related to Ensemble Studio or other hosted services, please contact **sharjeel@ensembleui.com**.
