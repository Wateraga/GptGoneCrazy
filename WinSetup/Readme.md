# WinSetup Modular Hardening Suite

## Features

- Modular, role-driven Windows system hardening and setup
- YAML-driven config for apps, buckets, services, and firewall rules
- SHA256 self-verification and repo tamper-evidence
- Detailed logging, Markdown summaries, and Event Log integration
- Parallel Scoop installs and optional-app prompts
- Python handoff for cross-platform or advanced automation

## Usage

1. Review and edit `config.yaml` for your needs and role
2. Place all files as per structure:  
   `WinSetup.ps1`, `WinSetup.py`, `config.yaml`, `modules/`, `.gitignore`, etc.
3. Run `WinSetup.ps1` as Administrator
4. Review logs and Markdown summary after completion

## Troubleshooting

- Logs are on your Desktop as `WinSetup_log.txt`
- Errors and warnings summarized in `WinSetup_Summary_*.md`
- If script hash or repo is not trusted, verify the allowlist

## Contribution

- Fork, branch, and submit PRs as usual
- Keep core logic in modules for clarity and upgradeability
