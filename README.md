# blink-obsidian

Small [`blink.cmp`](https://github.com/Saghen/blink.cmp) source for
Obsidian-style markdown vaults.

Scope stays intentionally small:

- `[[wiki links]]`
- `#tags`
- frontmatter `tags` completion

Not trying to be a full Obsidian integration layer. No markdown link completion,
aliases, or general YAML parsing.

See also `:h blink-obsidian`.

## Features

- Enables only for `markdown` buffers
- Detects vault root from nearest parent directory containing `.obsidian/`
- Completes `[[wiki links]]` from `**/*.md` note names in that vault
- Falls back to vault-relative note paths when duplicate note stems exist
- Completes `#tags` from inline markdown tags and frontmatter `tags`
- Completes frontmatter tags in these forms:
  - `tags: foo`
  - `tags: [foo, bar]`
  - list form under `tags:`
- Ignores fenced code blocks when scanning inline tags
- Invalidates per-vault cache on markdown file write

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

## Notes

- Wiki completion triggers inside `[[...`.
- Inline tag completion triggers after `#`.
- Frontmatter list completion can trigger after `,` in `tags: [a, b]`.
- Bare `#` on an otherwise empty line intentionally does not auto-popup, to
  avoid markdown heading noise.
- Frontmatter parsing is hand-rolled for `tags` only.

## License

Current repo license: MIT. See `LICENSE`.
