// Conventional Commit message rules enforced by hk's commit-msg hook.
// Example: `feat(livestream): add per-platform enabled flag`
export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
    // Scope is optional but the header must be non-empty and fit.
    "type-enum": [
      2,
      "always",
      ["feat", "fix", "refactor", "perf", "docs", "test", "chore", "style", "build", "revert"],
    ],
    "header-max-length": [2, "always", 100],
  },
};
