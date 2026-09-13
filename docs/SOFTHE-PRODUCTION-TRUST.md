# Softhe production trust profile

The Softhe fork keeps two trust chains separate:

1. Microsoft signs and authorizes the Windows kernel driver package.
2. The driver authorizes Pawn modules using an immutable RSA public key built
   into the driver.

The matching module private key must never be committed to this repository,
placed in ordinary CI secrets, copied into release artifacts, or installed on
test machines. Production signing should use a non-exportable HSM or managed
key and a two-person release procedure.

## Selected key-custody architecture

The selected production target is Azure Key Vault Managed HSM. The module RSA
private key will be generated inside Managed HSM as a non-exportable signing
key. Builds receive only the corresponding CNG public-key blob and its pinned
SHA-256 fingerprint. The signing service submits module digests to Managed HSM
and never retrieves private-key material.

The preferred primary deployment region is `swedencentral`. Confirm Managed
HSM availability and subscription quota in the authenticated tenant immediately
before provisioning. If Sweden Central is unavailable, use `northeurope` as the
EU fallback only after recording the data-residency and billing decision.

Provisioning is intentionally blocked until all of these owner-controlled
inputs exist:

- an Azure tenant and subscription with an accepted billing owner;
- a globally unique Managed HSM resource name and deployment region;
- named HSM administrators and least-privilege module-signing identities;
- at least three independently stored RSA recovery key pairs and a chosen
  recovery quorum;
- approved offline storage for the encrypted security-domain backup and its
  recovery private keys;
- an agreed retention and purge-protection period, because an HSM can remain
  billable throughout retention;
- a verified legal publisher identity for Microsoft Hardware Developer Program
  enrollment.

No production module key is generated before the recovery ceremony. Test
fixtures and mutated public blobs are never eligible for production trust.

## Production configuration

Configure a production candidate with all of the following:

```powershell
cmake -S . -B cmake-build-production -A x64 `
  -DPAWNIO_PRODUCTION_BUILD=ON `
  -DPAWNIO_UNRESTRICTED=OFF `
  -DPAWNIO_TRUST_UPSTREAM=OFF `
  -DPAWNIO_CUSTOM_TRUST_KEY_BLOB=C:\secure-input\softhe_module_public_key.blob `
  -DPAWNIO_CUSTOM_TRUST_KEY_SHA256=<64-lowercase-hex-digits> `
  -DPAWNIO_NAME=SofthePawnIO `
  -DPAWNIO_NAME_FULL=SofthePawnIOProductionDriver `
  -DPAWNIO_AUTHOR=Softhe
```

The supplied file is public build input and must be a raw 539-byte, 4096-bit
CNG `BCRYPT_RSAPUBLIC_BLOB`. CMake validates its exact size, `RSA1` magic,
bit length, exponent length, and modulus length before generating a fixed C++
array. It is never interpreted as source or preprocessor input. The production
public key and its SHA-256 fingerprint may be published. Only its private
counterpart is secret.

Run `scripts/Test-ProductionTrustProfile.ps1` with the public blob and pinned
fingerprint to build Release and confirm that Debug, unrestricted, upstream
trust, missing-fingerprint, and mismatched-fingerprint profiles are rejected.

Production configuration fails closed when unrestricted mode is enabled, the
upstream module key remains trusted, the custom public-key blob or its pinned
SHA-256 is missing/mismatched, or upstream driver branding is retained. A
production-configured Debug build also fails at compile time.

## Verification seam

`module_trust_verify` is the only interface used by the VM loader to authorize
a raw module and its signature. Hashing, trusted-key selection, and RSA
verification remain behind that seam. The VM allocates and loads module state
only after this interface returns success.

The initial Softhe profile intentionally preserves PawnIO's existing envelope
and RSA PKCS#1 SHA-256 algorithm. A versioned envelope with key identifiers and
rotation metadata is deferred until after the first independently signed pilot
to avoid combining a trust-root change with a wire-format migration.

## Release gates

- Pin PawnIO, PawnPP, WDK, Visual Studio Build Tools, and module-source commits.
- Build the restricted driver and raw module twice and compare hashes.
- Sign the module outside ordinary CI and verify it with public material only.
- Submit the driver package to Microsoft Partner Center for signing.
- Verify the returned Microsoft signature and lock every package hash.
- Validate install, load, rejection of unsigned/modified modules, rollback,
  Secure Boot, Memory Integrity, and Driver Verifier on a clean Windows VM.
- Repeat bounded xHCI read/write/readback/restore tests on supported hardware.
- Initially claim only `15B6`, `15B8`, and `43F7`; retain `15B7` and `43FD` as
  unsupported until they receive equivalent physical validation.
- Keep KX as the stable and recovery backend until a separately reviewed
  release satisfies every promotion gate.

Attestation signing may support a private pilot, but the public production goal
is HLK/WHCP dashboard signing. No unsigned or test-signed driver is a production
artifact.

Official Microsoft references:

- [Register for the Windows Hardware Developer Program](https://learn.microsoft.com/en-us/windows-hardware/drivers/dashboard/hardware-program-register)
- [Code signing requirements](https://learn.microsoft.com/en-us/windows-hardware/drivers/dashboard/code-signing-reqs)
- [Driver signing options](https://learn.microsoft.com/en-us/windows-hardware/drivers/dashboard/driver-signing-offerings)
- [HVCI-compatible driver guidance](https://learn.microsoft.com/en-us/windows-hardware/drivers/driversecurity/implement-hvci-compatible-code)
