# Security policy

PharmEye handles people's medicine and health information, so security reports are taken seriously.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report it privately through GitHub instead: open the **Security** tab of this repository and choose **Report a vulnerability**. Include:

- what you found and where (file, screen or flow),
- steps to reproduce it,
- what an attacker could do with it.

You'll get an acknowledgement as soon as possible. Please give a reasonable amount of time for a fix before sharing details publicly.

## Keeping your own build safe

- Never commit `PharmEye/Supabase.plist`, API keys, signing certificates or provisioning profiles. They are already in `.gitignore`.
- Only ever put the Supabase **publishable / anon** key in the app. The service-role or secret key must never ship in a client app.
- Turn on Row Level Security for every Supabase table you add.
