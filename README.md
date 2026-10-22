# Chrome Gemini / AI Disable

PowerShell script that applies Chrome enterprise policies, hosts-file blocks, Local State flag overrides, and a daily version-change reminder to suppress Gemini and other built-in AI features.

**Unlicense** — do whatever you want with it.

## What it does

- Sets machine-level Chrome policies under `HKLM:\SOFTWARE\Policies\Google\Chrome` to disable known Gemini/AI settings.
- Adds hosts entries for `gemini.google.com` and `aistudio.google.com`.
- Edits the Chrome Local State file to set `browser.enabled_labs_experiments` for a set of AI-related flags.
- Creates a scheduled task that checks the Chrome version once a day and shows a message only if it has changed (so you can re-check `chrome://policy` and `chrome://flags`).

## Usage

1. Close Chrome completely.
2. Run PowerShell as Administrator.
3. Execute:
   ```powershell
   .\Disable-ChromeAI.ps1
   ```
4. Restart Chrome and verify with `chrome://policy` and `chrome://flags`.

Chrome updates can reset some flags. The scheduled task exists to remind you when that happens.

## Notes

- Requires administrative rights for the registry policies and hosts file.
- Policies and hosts changes are persistent; some flags may need re-application after major Chrome updates.
- Tested against the policy and flag surface discussed in the original conversation. Chrome evolves; review `chrome://policy` after updates.

## License

[Unlicense](https://unlicense.org)
