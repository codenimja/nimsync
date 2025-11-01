# Security Policy

## Supported Versions

We take security seriously. The following versions of nimsync are currently supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | ✅ Yes             |
| < 1.0.0 | ❌ No              |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability in nimsync, please report it responsibly:

### How to Report

**Option 1: GitHub Security Advisories** (Preferred)
- Go to [https://github.com/codenimja/nimsync/security/advisories/new](https://github.com/codenimja/nimsync/security/advisories/new)
- Create a new security advisory
- Provide detailed information about the vulnerability

**Option 2: Email**
- Send an email to the maintainer (contact info in GitHub profile)
- Use subject line: `[SECURITY] nimsync vulnerability`

### What to Include

Please provide:

- A clear description of the vulnerability
- Steps to reproduce the issue
- Potential impact and severity assessment
- Any suggested fixes or mitigations (if you have them)
- Your preferred method of credit (or remain anonymous)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days  
- **Status Updates**: At least weekly
- **Resolution Timeline**: Depends on severity
  - Critical: < 7 days
  - High: < 14 days
  - Medium/Low: < 30 days

### Disclosure Policy

We follow coordinated disclosure:

1. We will work with you to understand and validate the issue
2. We will develop and test a fix
3. We will prepare a security advisory
4. We will coordinate a public disclosure date with you
5. We will release the fix and publish the advisory simultaneously
6. We will credit you in the advisory (unless you prefer anonymity)

## Security Best Practices

When using nimsync in production:

### General
- **Keep Updated**: Use the latest stable version
- **Monitor Advisories**: Watch this repository for security updates
- **Dependency Hygiene**: Keep Nim and Chronos updated
- **Review Changelog**: Check breaking changes before upgrading

### Runtime
- **Error Handling**: Implement proper error boundaries
- **Resource Limits**: Set appropriate channel buffer sizes
- **Logging**: Enable structured logging for security events
- **Monitoring**: Track task spawn rates and memory usage

### Deployment
- **Least Privilege**: Run with minimum required permissions
- **Network Isolation**: Limit network access where possible
- **Input Validation**: Validate all external inputs
- **Rate Limiting**: Implement rate limits on public endpoints

## Known Security Considerations

### Memory Safety
- nimsync uses Nim's ORC memory management
- Lock-free algorithms use atomic operations with proper memory barriers
- All unsafe code is carefully audited

### Concurrency
- Task cancellation is cooperative, not preemptive
- Always set timeouts for potentially blocking operations
- Use appropriate backpressure policies for streams

### Dependencies
- Chronos 4.0.4+ (actively maintained)
- Nim 2.0.0+ (latest stable recommended)

## Security Update Process

When a security issue is confirmed:

1. **Patch Development**: Fix is developed in a private repository
2. **Testing**: Comprehensive testing including security-specific tests
3. **Advisory Preparation**: CVE requested if applicable
4. **Coordinated Release**: Fix released with security advisory
5. **Notification**: Users notified via GitHub Security Advisories

## Contact

For security-related questions that are not vulnerabilities, please:
- Open a discussion on [GitHub Discussions](https://github.com/codenimja/nimsync/discussions)
- Check our [Support documentation](../SUPPORT.md)

---

**Thank you for helping keep nimsync and its users safe!**

For security-related questions or concerns, please contact us at [security@nimsync.dev](mailto:security@nimsync.dev).