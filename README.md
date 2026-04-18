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
<img width="480" height="270" alt="Image" src="https://github.com/user-attachments/assets/16a04578-651d-40ff-bba3-61acf429a0b6" />

- Falls back to vault-relative note paths when duplicate note stems exist
- Completes `#tags` from inline markdown tags and frontmatter `tags`
<img width="480" height="270" alt="Image" src="https://github.com/user-attachments/assets/61953b20-5685-415e-8cc2-e5feb2963beb" />

- Completes frontmatter tags in these forms:
  - `tags: foo`
  <img width="480" height="270" alt="Image" src="https://github.com/user-attachments/assets/7eb5028b-43b2-410e-ac8a-a88c9a05e5d3" />
  
  - `tags: [foo, bar]`
  <img width="480" height="270" alt="Image" src="https://github.com/user-attachments/assets/4107c487-6b66-4db4-be68-15772dabc631" />
  
  - list form under `tags:`
  <img width="480" height="270" alt="Image" src="https://github.com/user-attachments/assets/fc44ee72-44bf-4ac4-a6cf-d215fc71e497" />
  
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
