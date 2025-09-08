# Setting up Tigris Storage for GoPrint

## 1. Create Tigris Bucket (via Fly CLI)

```bash
# Create a Tigris bucket for the app
fly storage create

# Choose a name like: goprint-downloads
# Select region: sjc (same as your app)
# Make it public for downloads
```

## 2. Get Tigris Credentials

```bash
# This will show your bucket details and credentials
fly storage list
```

## 3. Upload the DMG file

### Option A: Using AWS CLI (S3 compatible)
```bash
# Configure AWS CLI with Tigris credentials
aws configure --profile tigris

# Enter:
# - Access Key ID: (from fly storage list)
# - Secret Access Key: (from fly storage list)
# - Region: auto
# - Output format: json

# Upload the file
aws s3 cp /Users/giovanniorlando/Sites/goprint/dist/GoPrint-1.0.1.dmg \
  s3://goprint-downloads/GoPrint-1.0.1.dmg \
  --profile tigris \
  --endpoint-url https://fly.storage.tigris.dev \
  --acl public-read
```

### Option B: Using rclone
```bash
# Install rclone if needed
brew install rclone

# Configure rclone
rclone config

# Create new remote:
# - Name: tigris
# - Storage: s3
# - Provider: Other
# - Access Key ID: (from fly storage list)
# - Secret Access Key: (from fly storage list)
# - Region: auto
# - Endpoint: fly.storage.tigris.dev

# Upload the file
rclone copy /Users/giovanniorlando/Sites/goprint/dist/GoPrint-1.0.1.dmg \
  tigris:goprint-downloads/
```

## 4. Verify the URL

The public URL will be:
```
https://fly.storage.tigris.dev/goprint-downloads/GoPrint-1.0.1.dmg
```

## 5. Update Download Page

The download page has already been updated with this URL. Once the file is uploaded, the download will work.

## Optional: Add to fly.toml for environment variables

Add these to your fly.toml if you want to use Tigris programmatically later:

```toml
[env]
  BUCKET_NAME = 'goprint-downloads'
  TIGRIS_ENDPOINT = 'https://fly.storage.tigris.dev'
```

Then set secrets:
```bash
fly secrets set TIGRIS_ACCESS_KEY_ID=your_key_id
fly secrets set TIGRIS_SECRET_ACCESS_KEY=your_secret_key
```