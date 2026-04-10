# kh-public-docs

This repository is designed to be synced into Knowledge Hub through Git Sync and rendered by `web-chat` in portal mode.

Important rendering constraints:

- Do not add `_meta.yaml` at the repository root. In the current personal-version sync hook, root `_meta.yaml` would mark the root node as hidden in portal view.
- Put all customer-visible Markdown files under `api/`.
- Keep `api/_meta.yaml`; it gives the visible top-level directory its display title.
- Each customer-visible Markdown file must start with YAML front matter and put `title` first.
- Use numeric filename prefixes for ordering. File-level `order` is not parsed by the current sync hook.
- Root-level files such as this README are for maintainers only. They are not intended to appear in `web-chat`.

Recommended Git Sync settings:

```yaml
file_patterns:
  - "*.md"
```

`_meta.yaml` is included by Git Sync even when it is not matched by `file_patterns`.

Before syncing, run:

```bash
bash scripts/validate-web-chat-format.sh
```

