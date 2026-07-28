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

## Package repository release

1. Configure the dedicated OpenPGP secret described in
   `docs/PACKAGE_REPOSITORY.md`.
2. Verify `config/package-set.txt`.
3. Run `Build package repository` manually and inspect all three artifacts.
4. Create a `packages-v<version>` tag.
5. Push the tag and wait for all architecture, repository and deploy jobs.
6. Verify `InRelease`, `Release.gpg`, package indexes and checksums at the
   GitHub Pages endpoint.
7. Update the Android client's pinned repository key only through a reviewed
   application release.

Never publish a production package repository with `trusted=yes`.
