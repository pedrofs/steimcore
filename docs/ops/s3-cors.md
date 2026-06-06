# S3 bucket CORS for Active Storage direct uploads

The exercise upload queue (and the Exercises admin) upload media straight from the
browser to S3 via Active Storage **direct uploads** (`app/frontend/lib/direct-upload.ts`).
The browser issues a cross-origin `PUT` from `https://steimfit.com` to
`https://steimcore-production.s3.amazonaws.com`, so the bucket must return CORS
headers or the preflight is blocked and the upload fails before it ever reaches Rails:

```
Access to XMLHttpRequest at 'https://steimcore-production.s3.amazonaws.com/...'
from origin 'https://steimfit.com' has been blocked by CORS policy: Response to
preflight request doesn't pass access control check: No 'Access-Control-Allow-Origin'
header is present on the requested resource.
```

The server side is fine — the failure is entirely the missing bucket CORS rule.

## Policy

See [`s3-cors.json`](./s3-cors.json). Only `PUT` is needed: blob **downloads** are
proxied through Rails (`rails_blob_path(only_path: true)`), so the browser never
fetches S3 directly. Add `GET`/`HEAD` only if you switch to redirect/public URLs.

## Apply

```bash
aws s3api put-bucket-cors \
  --bucket steimcore-production \
  --cors-configuration file://docs/ops/s3-cors.json
```

The dev/test buckets use the local Disk service (`config/storage.yml`), so they need
no CORS. If a `steimcore-staging` S3 bucket is ever added, apply the same policy with
its own `AllowedOrigins`.

## Verify

```bash
aws s3api get-bucket-cors --bucket steimcore-production
```

Then re-record a clip from the upload queue — the `PUT` to `s3.amazonaws.com` should
return `200` instead of `net::ERR_FAILED`, and the exercise drops off the queue.
