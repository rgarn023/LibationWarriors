# Supabase Setup

The repository contains the schema migration but intentionally does not contain a private server credential.

1. Confirm the Supabase project intended for Libation Warriors.
2. Apply \`supabase/migrations/20260928155100_foundation.sql\` through the Supabase migration workflow.
3. Copy \`config/supabase.public.example.json\` to \`config/supabase.public.json\`.
4. Put only the project URL and **publishable** client key in that file.
5. Never place a service-role/secret key in the Android project or Git history.
6. Configure Auth email/password and the desired confirmation/reset redirect behavior in Supabase.
7. Run \`scenes/tests/foundation_tests.tscn\`, then test sign-up → scan → logout → login → restore on an Android emulator.
8. Verify RLS manually with two separate test users before release.

\`config/supabase.public.json\` is gitignored.
