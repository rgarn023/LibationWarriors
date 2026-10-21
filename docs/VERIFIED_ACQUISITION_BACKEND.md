# Verified Acquisition — implementation and launch gates

## Current code
- Supabase migration `20261015152000_verified_scan.sql` introduces private location/challenge/claim tables, **database-enforced 30-day registered-location changes**, single-use five-minute handwritten challenges, and an atomic service-role-only claim function.
- `supabase/functions/verified-acquisition/index.ts` provides authenticated `register_location`, `begin_scan`, and `submit_proof` endpoints with trusted location/device, noncommercial venue, and photo verifier integration. It fails closed when those external verifiers are absent.
- The server owns first-claim global warrior blueprints, gender and design. The blueprint is returned to the device; players cannot submit arbitrary blueprint/category data to mint warriors.
- A barcode can be acquired **once per player**, but the same barcode can be owned by different players, always referencing one globally immutable blueprint row. Prior cloud-save client inserts must be removed.
- Exact registered locations exist **only** in a protected table, inaccessible to authenticated and anon clients, and must never be returned in public profiles or logs.

## Not production-ready / required integrations
1. The connected Supabase project is currently inactive and has not been confirmed to be the Libation Warriors project. The migration and Edge Function are committed to GitHub **but not deployed to Supabase**.
2. Configure real verified device-geolocation attestation `DEVICE_LOCATION_VERIFY_URL`, private/nonbusiness place screening `NONCOMMERCIAL_SITE_VERIFY_URL` and audited photo handwriting/product/liveness/anti-replay inspection `BOTTLE_PROOF_VERIFY_URL`. Each provider's verdict must be contract-tested and independently secured with `LW_VERIFIER_API_KEY`. Verify providers do not simply echo client booleans.
3. Build Android native in-app camera still/proof capture, randomized live motion capture, and a trustworthy location-integrity plugin. Refuse to enable scan claims until native evidence is available.
4. Explicitly integrate the client with `verified-acquisition` and obtain canonical base_data from the server after successful verification. Only then place the warrior in collection; do not allow local `WarriorFactory.generate` to bypass verification.
5. Resolve legacy unverified debug collection rows: never upload them as verified claims.
6. Age/legal/regional gating, disclosure/consent for photo/location data, minimization of proof retention, per-user rate limits, fraud review, appeals, and proof destruction lifecycle.
7. Supabase Edge Function URL must use valid authenticated JWT. Service-role secret stays only server side. Public build remains fail-closed.
8. Security-test rapid location changes, forged location evidence, venue business addresses, screenshot/photo replay, modified clients, missing proof, nonce reuse, simultaneous redemption, race conditions, two users same UPC, mismatched product, and expired challenge.

**Limit:** No image classifier can conclusively prove ownership or reject every replay/edit. Providers return risk signals, not mathematical certainty. Do not claim otherwise.
