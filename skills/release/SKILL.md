---
name: release
description: Cut a store release of a Flutter app - gate, version, build, upload, record, watch. Manual only; run it as /release when the batch is ready to ship to TestFlight or Play.
disable-model-invocation: true
---

# Release

Follow the app-release skill for the rules; this is the order of work. Stop at the first
failing step. The upload itself needs the owner's go-ahead.

1. **Gate.** CI green on the commit to release. `bash scripts/check_secrets.sh`,
   `bash scripts/check_login_config.sh --strict`, `bash <skills>/sync.sh --check .`. The
   store-review table in app-release is gone through row by row; login/purchase device tests
   per `references/device-testing.md`; screenshots current.
2. **Version and changelog** in one commit: `MAJOR.MINOR.PATCH+BUILD`, build `+1` on every
   upload; changelog entry with a Security line. Branch `chore/release-x.y.z`, PR, squash.
3. **Build** from the merged commit, from a clean tree (`git status` empty):

   ```bash
   flutter build appbundle --release        # build/app/outputs/bundle/release/app-release.aab
   flutter build ipa --release              # build/ios/ipa/*.ipa
   ```

   Artifacts stay under the app's `build/` directory. Never copy them into the repo or leave
   one per commit on disk. Check the bundled `.env` has publishable keys only and no `test_`
   RevenueCat key.
4. **Upload** (ask first): Play Console → internal testing for the `.aab`; Transporter or
   `xcrun altool` for the `.ipa` → TestFlight. Do not promote to production in the same run.
5. **Record** in the release PR: version, build number, commit, devices and flows that ran
   with results, anything skipped and why.
6. **Watch** for 48 hours (app-release: After release) and say who to look at before acting.
7. **Rollback / hotfix:** a bad build is superseded, not edited. Branch `fix/<name>` from the
   released tag, bump PATCH and BUILD, run the same gate, upload. Halt the staged rollout in
   Play Console or remove the build from sale in App Store Connect while the fix is prepared.
   A server-side problem is fixed with a backward-compatible migration, not a new build.
