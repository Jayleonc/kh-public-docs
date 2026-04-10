# web-chat Rendering Contract

This file is for maintainers. It is outside `api/`, so it is not intended to render in the public `web-chat` portal.

The current personal-version Knowledge Hub behavior was verified from:

- `internal/synchook/juzidocs.go`
- `internal/gitsync/service.go`
- `web-chat/src/lib/api.ts`
- `web-chat/src/components/knowledge/DocSidebar.tsx`
- `web-chat/src/store/vfsStore.ts`

## Confirmed Rules

- `web-chat` requests VFS tree data with `view_mode: "portal"`.
- Portal view hides nodes with metadata `synchook.ui_visible=false`.
- `JuziDocsHook` marks `api/*.md` as visible documents.
- `JuziDocsHook` marks `docs/*.md` as hidden documents.
- Other paths are hidden by default when hook metadata is applied.
- `_meta.yaml` files are not synced as documents.
- `_meta.yaml` is parsed as directory metadata with this schema:

```yaml
title: Display Name
order: 1
```

- Directory `_meta.yaml` sets:
  - `synchook.title`
  - `synchook.ui_visible`
  - `synchook.order` if `order > 0`
- Directory `_meta.yaml` only sets `synchook.ui_visible=true` when the `_meta.yaml` path starts with `api/`.
- Root `_meta.yaml` would target `/` and set `synchook.ui_visible=false`, so it must not be used in this repository.
- Markdown file display title is extracted from front matter `title`.
- File-level `order` is not currently extracted by the sync hook.
- File ordering in `DocSidebar` falls back to filename, so numeric filename prefixes are used.

## Visible Content Rule

Put customer-visible Markdown here:

```text
api/*.md
```

Keep maintainer-only notes outside `api/`.

