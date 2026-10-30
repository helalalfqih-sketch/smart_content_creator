# Firestore authorization tests

Install Node 24.12 or newer and Java 21, then run from this directory:

```sh
npm ci --ignore-scripts
npm test
```

The tests use the local Firestore emulator with the synthetic project
`demo-scc-security`. They do not use a Firebase login, cloud project, production
data, or repository secrets. `initializeTestEnvironment` explicitly selects
127.0.0.1:8080 and clears only that emulator between cases.

Coverage includes private profile isolation, administrator access, safe account
creation, privilege and credit escalation, deleting/recreating profiles, counter
reset, private settings sync, and chat subcollection ownership. The root profile
tests also detect the rules-v2 recursive wildcard bypass.

These checks do not cover all collections, Storage rules, backend authorization,
subscription expiry, real device attestation, or the signed Android build.
