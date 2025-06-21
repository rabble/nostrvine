# Setting up Cloudinary Secrets

## IMPORTANT: Never commit secrets to git!

The Cloudinary API key and secret must be configured using Wrangler secrets, NOT in wrangler.toml.

## Setting Secrets

### For Development:
```bash
# Set the API key
wrangler secret put CLOUDINARY_API_KEY
# Enter the value when prompted

# Set the API secret
wrangler secret put CLOUDINARY_API_SECRET
# Enter the value when prompted
```

### For Staging:
```bash
wrangler secret put CLOUDINARY_API_KEY --env staging
wrangler secret put CLOUDINARY_API_SECRET --env staging
```

### For Production:
```bash
wrangler secret put CLOUDINARY_API_KEY --env production
wrangler secret put CLOUDINARY_API_SECRET --env production
```

## Required Secrets

1. **CLOUDINARY_API_KEY**: Your Cloudinary API key
2. **CLOUDINARY_API_SECRET**: Your Cloudinary API secret (NEVER share or commit this!)

## Verifying Secrets

To list configured secrets (but not their values):
```bash
wrangler secret list
```

## Security Best Practices

1. **Never commit secrets to git** - Use wrangler secrets
2. **Use different API keys for different environments** if possible
3. **Rotate secrets regularly**
4. **Limit access to production secrets**
5. **Use environment-specific Cloudinary accounts** for better isolation

## Getting Cloudinary Credentials

1. Log in to your Cloudinary dashboard
2. Go to Settings > Account
3. Find your Cloud name, API Key, and API Secret
4. The Cloud name can be in wrangler.toml (it's public)
5. The API Key and Secret must be set as secrets