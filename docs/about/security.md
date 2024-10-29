# Security Policy

## Supported Versions

We only provide (security) updates for the latest release. This means that we recommend using the Docker images tagged with the latest version or the `latest` tag. Whenever we fix an issue, we release a new version that includes the fix. We do not provide security updates for older versions.

## Reporting a Vulnerability

We deeply appreciate any effort to discover and disclose security vulnerabilities responsibly.

If you would like to report a vulnerability, or have security concerns regarding this project, please do **not** submit an issue. Instead, please email <sebastian@sommerfeld.io>.

In order for us to best respond to your report, please include any of the following:

- Steps to reproduce or proof-of-concept
- Any relevant tools, including versions used
- Tool output

[All issues labeled as `security`](https://github.com/sommerfeld-io/configs-homelab/issues?q=is%3Aissue+label%3Asecurity%2Crisk+is%3Aopen) tackle already disclosed security issues (e.g. CVEs) and are publicly known already.

## Detecting Vulnerabilities

We prioritize the security of our project and take proactive measures to detect vulnerabilities. As part of our continuous integration and delivery process, we scan our Docker images using Docker Scout in every pipeline run and for every pull request. This ensures that any potential vulnerabilities are identified and addressed promptly.
