# AGENTS.md — Rules for AI Coding Assistants

**Read this file completely before making any change to this repository.**

<!-- RULES :  -->

1. Everything should be evironment driven, use environment variables.
2. Don't do any inline styling.
3. Do not modify unrelated files.
4. Do not push directly to main.
5. Never take access of .env file.
6. Don't do anything hardcoded.
7. Read and understand the existing code before making any changes.
8. Make only the changes required for the requested task. Do not modify unrelated files or functionality.
9. Follow the existing project structure, architecture, naming conventions, and coding style.
10. Use environment variables for configuration. Never hardcode secrets, credentials, API keys, database URLs, or environment-specific values.
11. Never read, expose, modify, or commit `.env` files or their secret values.
12. Do not add, remove, or upgrade dependencies unless they are required for the requested task.
13. Never perform destructive database operations or delete existing user data without explicit approval.
14. After making changes, run the relevant tests, build, lint, or validation checks and fix errors caused by the changes.
15. Do not commit, push, force-push, or modify Git history unless explicitly requested. Never push directly to `main`.
16. Do not overwrite or discard existing user changes. Preserve existing functionality unless the task explicitly requires changing it.



# Git Workflow & Commit Rules

## Developer-Controlled Git Operations

The developer owns and controls the Git repository.

Antigravity may inspect Git status, branches, diffs, and logs, but MUST NOT perform the following operations unless the developer explicitly asks:

- `git push`
- `git push --force`
- `git reset --hard`
- `git clean`
- `git branch -D`
- deleting remote branches
- rewriting Git history
- rebasing shared branches
- force-pushing any branch

Never modify or delete existing commits without explicit developer approval.

---

## Branching Strategy

The `main` branch is the stable branch.

Never develop directly on `main`.

Every feature, fix, refactor, or isolated task must use a dedicated branch.

Branch naming:

- `feature/<name>` for new functionality
- `fix/<name>` for bug fixes
- `refactor/<name>` for refactoring
- `docs/<name>` for documentation
- `test/<name>` for testing
- `chore/<name>` for tooling/configuration

Examples:

- `feature/authentication`
- `feature/case-management`
- `feature/ai-case-analysis`
- `fix/case-status-transition`
- `refactor/ai-service`

---

## Before Starting a Task

1. Inspect the current Git status.
2. Identify the current branch.
3. Inspect recent commits if necessary.
4. Ensure the working tree is understood before making changes.
5. Never overwrite unrelated developer changes.
6. Never discard uncommitted work.

If uncommitted changes already exist, report them to the developer before modifying potentially affected files.

---

## During Development

Work only on the requested task.

Do not:

- modify unrelated functionality
- perform unnecessary refactoring
- change project architecture without approval
- remove working functionality
- change dependencies without justification
- modify environment secrets

Keep changes focused and reviewable.

---

## Before Commit

Antigravity MUST:

1. Run `git status`.
2. Review changed files.
3. Run `git diff`.
4. Identify unrelated changes.
5. Check for accidentally added secrets or credentials.
6. Verify `.env` and other secret files are ignored.
7. Run appropriate tests.
8. Run appropriate linting/static analysis.
9. Run relevant build checks.
10. Confirm the implementation follows the PRD and SRS requirements.
11. Report the files changed and validation results.

Never commit if tests or builds fail unless the developer explicitly approves it.

---

## Commit Rules

Commits must be small, focused, and logically grouped.

Use Conventional Commit style:

`type(scope): description`

Allowed types:

- `feat`
- `fix`
- `refactor`
- `test`
- `docs`
- `chore`
- `security`

Examples:

`feat(auth): implement JWT authentication`

`feat(cases): add incident creation`

`feat(ai): add case analysis`

`fix(cases): validate status transitions`

`test(auth): add login tests`

Do not create vague commits such as:

- `update`
- `changes`
- `final`
- `stuff`
- `working`
- `changes made`

---

## Staging Rules

Do not blindly use:

`git add .`

Prefer explicitly staging relevant files.

Before committing, inspect:

`git diff --cached`

Only commit changes that belong to the current task.

---

## Secrets

Never commit:

- `.env`
- API keys
- Gemini API keys
- database passwords
- JWT secrets
- OAuth client secrets
- private keys
- access tokens
- service credentials

Use `.env.example` with placeholder values when appropriate.

---

## Push Rules

Antigravity MUST NOT push automatically.

After a successful commit, report:

- branch name
- commit hash
- commit message
- tests performed
- build status
- files changed
- exact push command

Wait for explicit developer approval before pushing.

---

## Pull Request

After the developer pushes the branch, the developer may create a Pull Request into `main`.

The PR should contain:

- feature/fix summary
- important implementation details
- tests performed
- known limitations
- related PRD/SRS requirement

Do not merge into `main` automatically unless explicitly instructed.

---

## Main Branch Protection

Treat `main` as production/stable code.

Never:

- develop directly on `main`
- force push `main`
- reset `main`
- delete `main`
- rewrite `main` history

Only merge tested and reviewed work into `main`.