# Releasing the kit

1. Raise `version` in `plugins/elasticore/.claude-plugin/plugin.json` and in
   `plugins/elasticore/plugin.json` (Codex) - `claude plugin update` finds nothing new otherwise -
   and write the version's section in [CHANGELOG.md](CHANGELOG.md), `## X.Y.Z`, for users: what
   they get, and how to update in Claude Code, opencode and Codex.
2. Merge to `main` once CI passes.
3. Tag the merge commit `vX.Y.Z` and push the tag. The
   [Release workflow](.github/workflows/release.yml) checks that the tag is the plugin's version,
   and publishes the GitHub release "ElastiCORE agent kit X.Y.Z" with the CHANGELOG section as its
   notes and a footer pointing to the README and the CHANGELOG
   (`bash .github/scripts/release-notes.sh vX.Y.Z` prints them). A release that exists already is
   left as it is.

Every version has a release on https://github.com/xsko/elasticore-agent-kit/releases.
