# Image pipeline (serverless)

Triggered when the app uploads an original to the **private** uploads bucket
(via the API's presigned PUT). The function:

1. downloads the original,
2. auto-orients and **strips all EXIF/GPS** (sharp drops metadata by default),
3. writes `_1080` and `_480` JPEG derivatives to the **public** bucket,
4. marks the `tree_photos` row `processed` with dimensions.

## Build & deploy (AWS SAM)

```bash
npm install
npm run build

# sharp needs the Linux/arm64 binary to match the Lambda runtime:
npm install --os=linux --cpu=arm64 --libc=glibc sharp   # or use a sharp Lambda layer

sam build
sam deploy --guided \
  --parameter-overrides \
    UploadsBucketName=mwavuli-uploads-private \
    PublicBucketName=mwavuli-public \
    DatabaseUrlSecretArn=arn:aws:secretsmanager:...:secret:mwavuli/db
```

## IAM (least privilege)

- `s3:GetObject` on `mwavuli-uploads-private/uploads/*`
- `s3:PutObject` on `mwavuli-public/public/*`
- `secretsmanager:GetSecretValue` on the DB secret
- VPC access to reach RDS (or use **RDS Proxy** to avoid connection exhaustion)

## Notes

- The uploads bucket has **Block Public Access** on — originals never become
  public; only the stripped derivatives do.
- Alternatives: GCP Cloud Functions + Cloud Storage, or Cloudflare Images /
  Images Resizing. The handler logic is portable; only the trigger/SDK changes.
