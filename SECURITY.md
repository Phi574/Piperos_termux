# Security policy

## Supported versions

Only the latest PiperOS Termux runtime release is supported.

## Release integrity

Production runtime manifests must be signed with Ed25519. The private key is
stored only as a protected GitHub Actions secret. PiperOS embeds the public
key from `keys/manifest-public.pem` and must reject:

- unsigned production manifests;
- an invalid manifest signature;
- an archive whose SHA-256 or byte size differs from the manifest;
- an archive containing absolute paths or `..` path traversal;
- an archive for a different application id, prefix, ABI, or minimum API.

Runtime installation should extract into a private staging directory and
replace the active runtime only after all checks pass.

## Reporting

Do not open a public issue for a vulnerability that would expose users.
Contact the repository owner privately through the GitHub profile associated
with this repository.

