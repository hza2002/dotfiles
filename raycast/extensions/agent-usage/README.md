# Agent Usage

Open `Agent Usage` in Raycast to query all connected coding plans in one page.
Command-R refreshes every plan. Each source loads independently and displays its
own errors. There is no sidebar or provider switching.

Supports the local Codex ChatGPT account: five-hour and weekly remaining
quotas, reset times and countdowns, reset credits, account and plan type. Dates use
the system timezone and a 24-hour clock. Countdowns update every 30 seconds;
reaching a reset time requires a fresh query. Results remain in memory only.

The extension reads `~/.codex/auth.json` to verify the account, then queries the
Homebrew Codex CLI at `/opt/homebrew/bin/codex` using `account/rateLimits/read`.
The short-lived query process selects the official OpenAI provider for itself.
Codex owns authentication and normal token refresh. No conversation is started.
API-key login, missing login, changed accounts and unavailable windows are shown
explicitly. Requires macOS, Raycast and the Homebrew Codex CLI.

Sources are declared in `src/index.tsx`; each supplies a query and a section
renderer, so new plans can use their own quota windows and authentication without
changing the page layout.

Kimi Code reads the existing OAuth access token from
`~/.kimi-code/credentials/kimi-code.json` and queries the same official
`https://api.kimi.com/coding/v1/usages` endpoint as Kimi Code 0.41.0's `/usage`.
It shows all returned quota windows and the weekly quota. Credentials are read
only, never copied or logged; redirects are rejected. If the token expires, run
`/usage` in Kimi Code to refresh authentication (or `/login` when signed out), then
refresh Raycast. The extension does not refresh or overwrite Kimi's token file.
Custom service endpoints and legacy `~/.kimi` logins are not used.

## Development

```sh
npm ci
npm run build
npm test
npm run lint
npm run dev
```

Source lives in `raycast/extensions/agent-usage`. `npm run dev` registers the local
extension with Raycast. Generated bundles, dependencies and credentials stay out
of Git. Run `./check raycast agent-usage` from the repository root.

For migration, register Agent Usage and remove the former CC Switch local extension
in Raycast. Its old menu cache is not used by this extension.

Verify in Raycast: opening immediately queries quotas; all plans share one list;
Command-R refreshes; loading and failures stay within their plan section; plan and
account sit in the section title; quota rows show colored, aligned remaining and
reset columns; the reset-credit row shows the count and nearest expiry.
