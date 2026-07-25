# Cloudflare R2 integration

`CloudflareR2Service.uploadAvatar` uploads `users/<userId>/avatar.png` to an
S3-compatible R2 bucket using AWS Signature Version 4. It reads `ACCOUNT_ID`,
`ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, `BUCKET_NAME`, and optionally
`CLOUDFLARE_R2_PUBLIC_URL` from `.env`.

Without the required values, the method returns a mock URL. With values, it
uploads directly from the mobile client. This is suitable only for controlled
development: production apps must not distribute long-lived R2 secret keys.
Use a backend to issue short-lived signed uploads instead.

The companion D1 client uses `D1_DTABASE` and `TOKEN_VALUE`; see
[configuration and security](SECURITY_CONFIGURATION.md) for the exact names
and production caveats.
