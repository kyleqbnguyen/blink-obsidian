# blink-obsidian

Small [`blink.cmp`](https://github.com/Saghen/blink.cmp) source for
Obsidian-style markdown vaults.

Scope stays intentionally small:

- `[[wiki links]]`
- `#tags`
- frontmatter `tags` completion

Not trying to be a full Obsidian integration layer.

See also `:h blink-obsidian`.

## Features

- `markdown` only
- Vault root auto-detected from nearest parent containing `.obsidian/`
- Duplicate note names fall back to vault-relative paths
- Fenced code blocks ignored while scanning inline tags
- Per-vault cache invalidated on markdown file write

### Wiki Links

Completes `[[wiki links]]` from markdown note names in current vault.

<p align="center">
  <img width="720" alt="Wiki link completion demo" src="https://github.com/user-attachments/assets/16a04578-651d-40ff-bba3-61acf429a0b6" />
</p>

### Unresolved Wikilinks

Optionally surface unresolved wikilinks — `[[links]]` that appear in the vault
but have no corresponding note yet. Useful for workflows where you link to
topics before the notes exist.

Unresolved wikilinks appear alongside existing notes, marked `(new)`.

<!-- demo gif -->

Enable via `include_unresolved_wiki_links`:

```lua
obsidian = {
  name = "Obsidian",
  module = "blink_obsidian",
  opts = {
    include_unresolved_wiki_links = true,
  },
}
```

### Inline Tags

Completes `#tags` from both inline markdown tags and frontmatter `tags` values.

<p align="center">
  <img width="720" alt="Inline tag completion demo" src="https://github.com/user-attachments/assets/61953b20-5685-415e-8cc2-e5feb2963beb" />
</p>

### Frontmatter Tags

Supports all common `tags` shapes.

`tags: foo`

<p align="center">
  <img width="720" alt="Scalar frontmatter tag completion demo" src="https://github.com/user-attachments/assets/7eb5028b-43b2-410e-ac8a-a88c9a05e5d3" />
</p>

`tags: [foo, bar]`

<p align="center">
  <img width="720" alt="Inline list frontmatter tag completion demo" src="https://github.com/user-attachments/assets/4107c487-6b66-4db4-be68-15772dabc631" />
</p>

List form under `tags:`

<p align="center">
  <img width="720" alt="Multiline frontmatter tag completion demo" src="https://github.com/user-attachments/assets/fc44ee72-44bf-4ac4-a6cf-d215fc71e497" />
</p>

## Install

### Native Neovim 0.12+ package manager

```lua
vim.pack.add({
  "https://github.com/Saghen/blink.cmp",
  "https://github.com/kyleqbnguyen/blink-obsidian",
})

require("blink.cmp").setup({
  sources = {
    default = { "lsp", "path", "buffer", "obsidian" },
    providers = {
      obsidian = {
        name = "Obsidian",
        module = "blink_obsidian",
        score_offset = 12,
      },
    },
  },
})
```

After adding plugin specs, restart Neovim and run `:lua vim.pack.update()` to install or update managed plugins.

### lazy.nvim

```lua
{
  "Saghen/blink.cmp",
  dependencies = {
    "kyleqbnguyen/blink-obsidian",
  },
  opts = {
    sources = {
      default = { "lsp", "path", "buffer", "obsidian" },
      providers = {
        obsidian = {
          name = "Obsidian",
          module = "blink_obsidian",
          score_offset = 12,
        },
      },
    },
  },
}
```

### packer.nvim

```lua
use {
  "Saghen/blink.cmp",
  requires = {
    "kyleqbnguyen/blink-obsidian",
  },
}

require("blink.cmp").setup({
  sources = {
    default = { "lsp", "path", "buffer", "obsidian" },
    providers = {
      obsidian = {
        name = "Obsidian",
        module = "blink_obsidian",
        score_offset = 12,
      },
    },
  },
})
```

## Blink Provider Config

Point Blink directly at module `blink_obsidian`.

```lua
obsidian = {
  name = "Obsidian",
  module = "blink_obsidian",
  score_offset = 12,
}
```

No `setup()` function.

## Options

Pass provider options through Blink.

```lua
obsidian = {
  name = "Obsidian",
  module = "blink_obsidian",
  opts = {
    close_wiki = true,
  },
}
```

Available options:

- `close_wiki` (`true` by default): append `]]` when completing inside an open
  `[[...` link and closing brackets are not already present after cursor.
- `include_unresolved_wiki_links` (`false` by default): include unresolved
  wikilinks — `[[links]]` that appear anywhere in the vault but have no
  corresponding note. These appear marked `(new)` in the completion menu.

## Notes

- Wiki completion triggers inside `[[...`.
- Inline tag completion triggers after `#`.
- Frontmatter list completion can trigger after `,` in `tags: [a, b]`.
- Bare `#` on an otherwise empty line intentionally does not auto-popup, to
  avoid markdown heading noise.
- Frontmatter parsing is hand-rolled for `tags` only.

## License

Current repo license: MIT. See `LICENSE`.
