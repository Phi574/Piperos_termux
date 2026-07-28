# Runtime release procedure

## One-time signing setup

Generate an Ed25519 key:

```bash
openssl genpkey -algorithm ED25519 -out manifest-private.pem
openssl pkey -in manifest-private.pem -pubout -out keys/manifest-public.pem
base64 -w 0 manifest-private.pem
```

Add the base64 output as the protected GitHub Actions repository secret
`PIPEROS_MANIFEST_SIGNING_KEY_B64`. Store the private key offline. Commit only
the public key.

## Release

1. Update `PIPEROS_RUNTIME_VERSION` and the pinned upstream revision.
2. Run repository validation.
3. Commit the source.
4. Create a matching `runtime-v<version>` tag.
5. Push the branch and tag.
6. Wait for all three ABI jobs and the publish job.
7. Verify the release signature, hashes, source tag, and download URLs.
8. Update the manifest URL embedded in PiperOS only after verification.

Do not publish an unsigned production manifest.

