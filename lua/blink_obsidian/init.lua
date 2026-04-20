local source = {}

local default_opts = {
  close_wiki = true,
  include_undefined_refs = false,
}

local cache = {}
local autocmd_registered = false

local function normalize_path(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function relative_path(root, path)
  local prefix = root
  if prefix:sub(-1) ~= "/" then
    prefix = prefix .. "/"
  end

  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end

  return vim.fn.fnamemodify(path, ":t")
end

local function detect_root(bufnr)
  if vim.bo[bufnr].filetype ~= "markdown" then
    return nil
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return nil
  end

  local dir = vim.fs.dirname(path)
  if not dir then
    return nil
  end

  local marker = vim.fs.find(".obsidian", {
    path = normalize_path(dir),
    upward = true,
    type = "directory",
    limit = 1,
  })[1]

  if not marker then
    return nil
  end

  local root = vim.fs.dirname(marker)
  if not root then
    return nil
  end

  return normalize_path(root)
end

local function is_tag_char(char)
  return char ~= "" and char:match("[%w_/-]") ~= nil
end

local function parse_frontmatter_tag_context(bufnr, root, line, cursor_line, cursor_col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor_line, false)
  if lines[1] ~= "---" then
    return nil
  end

  local in_tags_list = false
  for line_number = 2, cursor_line do
    local current = lines[line_number]
    if line_number > 1 and (current == "---" or current == "...") then
      return nil
    end

    if line_number < cursor_line then
      local key = current:match("^([%w_-]+):")
      if key then
        in_tags_list = key == "tags" and current:match("^tags:%s*$") ~= nil
      elseif in_tags_list and current:match("^%s*%-%s*") then
      elseif in_tags_list and current:match("^%s*$") then
      elseif in_tags_list then
        in_tags_list = false
      end
    end
  end

  local before_cursor = line:sub(1, cursor_col)
  local inline_tags = before_cursor:match("^tags:%s*%[([^%]]*)$")
  if inline_tags then
    local typed_query = vim.trim(inline_tags:match("([^,]*)$") or inline_tags)
    return {
      kind = "frontmatter_tag",
      query = typed_query:gsub("^#", ""),
      root = root,
      start_col = cursor_col - #typed_query,
    }
  end

  local scalar_start, scalar_query = before_cursor:match("^tags:%s+()([#]?[%w_/-]*)$")
  if scalar_start then
    return {
      kind = "frontmatter_tag",
      query = scalar_query:gsub("^#", ""),
      root = root,
      start_col = scalar_start - 1,
    }
  end

  if not in_tags_list then
    return nil
  end

  local item_start, item_query = before_cursor:match("^%s*%-%s*()([#]?[%w_/-]*)$")
  if not item_start then
    return nil
  end

  return {
    kind = "frontmatter_tag",
    query = item_query:gsub("^#", ""),
    root = root,
    start_col = item_start - 1,
  }
end

local function parse_context(bufnr, line, cursor)
  local root = detect_root(bufnr)
  if not root then
    return nil
  end

  local cursor_line = cursor[1]
  local cursor_col = cursor[2]
  local before_cursor = line:sub(1, cursor_col)
  local wiki_query = before_cursor:match("%[%[([^%]]*)$")
  if wiki_query and not wiki_query:find("|", 1, true) then
    return {
      kind = "wiki",
      query = wiki_query,
      root = root,
      start_col = cursor_col - #wiki_query,
    }
  end

  local frontmatter_tag = parse_frontmatter_tag_context(bufnr, root, line, cursor_line, cursor_col)
  if frontmatter_tag then
    return frontmatter_tag
  end

  local tag_query = before_cursor:match("#([%w_/-]*)$")
  if not tag_query then
    return nil
  end

  local hash_col = cursor_col - #tag_query
  local prefix = before_cursor:sub(1, hash_col - 1)
  local prev = hash_col > 1 and before_cursor:sub(hash_col - 1, hash_col - 1) or ""
  if prev:match("[%w_/]") then
    return nil
  end

  if prefix:match("^%s*#+$") then
    return nil
  end

  if prefix:match("^%s*$") and tag_query == "" then
    return nil
  end

  return {
    kind = "tag",
    query = tag_query,
    root = root,
    start_col = hash_col - 1,
  }
end

local function scan_notes(root)
  local raw_notes = {}
  local stem_counts = {}

  for _, path in ipairs(vim.fn.globpath(root, "**/*.md", false, true)) do
    local abs_path = normalize_path(path)
    local rel_path = relative_path(root, abs_path)
    if not rel_path:match("^%.") and not rel_path:match("/%.") then
      local stem = vim.fn.fnamemodify(abs_path, ":t:r")
      local rel_note = rel_path:gsub("%.md$", "")
      stem_counts[stem] = (stem_counts[stem] or 0) + 1
      raw_notes[#raw_notes + 1] = {
        stem = stem,
        rel = rel_note,
      }
    end
  end

  table.sort(raw_notes, function(a, b)
    local a_key = a.stem:lower() .. "\0" .. a.rel:lower()
    local b_key = b.stem:lower() .. "\0" .. b.rel:lower()
    return a_key < b_key
  end)

  local notes = {}
  for _, note in ipairs(raw_notes) do
    notes[#notes + 1] = {
      label = note.stem,
      insert = stem_counts[note.stem] > 1 and note.rel or note.stem,
      description = note.rel ~= note.stem and note.rel or nil,
      filter = note.stem .. " " .. note.rel,
    }
  end

  return notes
end

local function collect_tags(line, seen, tags)
  local index = 1

  while index <= #line do
    local hash = line:find("#", index, true)
    if not hash then
      break
    end

    local prefix = line:sub(1, hash - 1)
    local prev = hash > 1 and line:sub(hash - 1, hash - 1) or ""
    local next_char = line:sub(hash + 1, hash + 1)
    local leading_hashes = prefix:match("^%s*#+$") ~= nil

    if not prev:match("[%w_/]") and is_tag_char(next_char) and not leading_hashes then
      local end_index = hash + 1
      while end_index <= #line and is_tag_char(line:sub(end_index, end_index)) do
        end_index = end_index + 1
      end

      local tag = line:sub(hash + 1, end_index - 1)
      if not seen[tag] then
        seen[tag] = true
        tags[#tags + 1] = tag
      end

      index = end_index
    else
      index = hash + 1
    end
  end
end

local function add_tag(tag, seen, tags)
  tag = vim.trim(tag or "")
  tag = tag:gsub('^["\']', ""):gsub('["\']$', "")
  tag = tag:gsub('^#', "")

  if tag == "" or not tag:match("^[%w_/-]+$") then
    return
  end

  if not seen[tag] then
    seen[tag] = true
    tags[#tags + 1] = tag
  end
end

local function collect_frontmatter_tags(line, state, seen, tags)
  local key, value = line:match("^([%w_-]+):%s*(.*)$")
  if key then
    state.in_list = false

    if key ~= "tags" then
      return
    end

    if value == "" then
      state.in_list = true
      return
    end

    if value:match("^%b[]$") then
      for part in value:sub(2, -2):gmatch("[^,]+") do
        add_tag(part, seen, tags)
      end
      return
    end

    add_tag(value, seen, tags)
    return
  end

  if not state.in_list then
    return
  end

  local item = line:match("^%s*%-%s*(.+)%s*$")
  if item then
    add_tag(item, seen, tags)
  else
    state.in_list = false
  end
end

local function scan_undefined_refs(root, notes)
  local existing = {}
  for _, note in ipairs(notes) do
    existing[note.insert:lower()] = true
    existing[note.label:lower()] = true
    if note.description then
      existing[note.description:lower()] = true
    end
  end

  local refs = {}
  local seen = {}

  for _, path in ipairs(vim.fn.globpath(root, "**/*.md", false, true)) do
    local ok, lines = pcall(vim.fn.readfile, path)
    if ok then
      for _, line in ipairs(lines) do
        for raw in line:gmatch("%[%[([^%]|]+)") do
          local target = vim.trim(raw:gsub("#.*$", ""))
          if target ~= "" and not existing[target:lower()] and not seen[target:lower()] then
            seen[target:lower()] = true
            refs[#refs + 1] = target
          end
        end
      end
    end
  end

  table.sort(refs, function(a, b)
    return a:lower() < b:lower()
  end)

  return refs
end

local function scan_tags(root)
  local tags = {}
  local seen = {}

  for _, path in ipairs(vim.fn.globpath(root, "**/*.md", false, true)) do
    local ok, lines = pcall(vim.fn.readfile, path)
    if ok then
      local in_frontmatter = lines[1] == "---"
      local in_fence = false
      local frontmatter_state = { in_list = false }

      for line_number, line in ipairs(lines) do
        if in_frontmatter then
          if line_number > 1 and (line == "---" or line == "...") then
            in_frontmatter = false
            frontmatter_state.in_list = false
          else
            collect_frontmatter_tags(line, frontmatter_state, seen, tags)
          end
        elseif line:match("^%s*```") then
          in_fence = not in_fence
        elseif not in_fence then
          collect_tags(line, seen, tags)
        end
      end
    end
  end

  table.sort(tags, function(a, b)
    return a:lower() < b:lower()
  end)

  return tags
end

local function ensure_cache(root)
  local entry = cache[root]
  if not entry then
    entry = {}
    cache[root] = entry
  end

  return entry
end

local function register_autocmd()
  if autocmd_registered then
    return
  end

  autocmd_registered = true

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("blink-obsidian-cache", { clear = true }),
    pattern = "*.md",
    callback = function(args)
      local root = detect_root(args.buf)
      if root then
        cache[root] = nil
      end
    end,
  })
end

local function build_wiki_item(note, ctx, context, close_wiki)
  local after_cursor = ctx.line:sub(ctx.cursor[2] + 1)
  local suffix = close_wiki and not after_cursor:match("^%]%]") and "]]" or ""
  local new_text = note.insert .. suffix

  return {
    label = note.label,
    label_description = note.description,
    insertText = new_text,
    filterText = note.filter,
    kind = require("blink.cmp.types").CompletionItemKind.Reference,
    textEdit = {
      newText = new_text,
      range = {
        start = { line = ctx.cursor[1] - 1, character = context.start_col },
        ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
      },
    },
  }
end

local function build_undefined_ref_item(ref, ctx, context, close_wiki)
  local after_cursor = ctx.line:sub(ctx.cursor[2] + 1)
  local suffix = close_wiki and not after_cursor:match("^%]%]") and "]]" or ""
  local new_text = ref .. suffix

  return {
    label = ref,
    label_description = "(new)",
    insertText = new_text,
    filterText = ref,
    kind = require("blink.cmp.types").CompletionItemKind.Reference,
    textEdit = {
      newText = new_text,
      range = {
        start = { line = ctx.cursor[1] - 1, character = context.start_col },
        ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
      },
    },
  }
end

local function build_tag_item(tag, ctx, context)
  local in_frontmatter = context.kind == "frontmatter_tag"
  local new_text = in_frontmatter and tag or "#" .. tag

  return {
    label = in_frontmatter and tag or new_text,
    insertText = new_text,
    filterText = tag,
    kind = require("blink.cmp.types").CompletionItemKind.Keyword,
    kind_name = "Tag",
    textEdit = {
      newText = new_text,
      range = {
        start = { line = ctx.cursor[1] - 1, character = context.start_col },
        ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
      },
    },
  }
end

function source.new(opts)
  register_autocmd()

  local self = setmetatable({}, { __index = source })
  self.opts = vim.tbl_deep_extend("force", default_opts, opts or {})
  return self
end

function source:get_trigger_characters()
  return { "[", "#", "," }
end

function source:enabled()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  return parse_context(0, line, cursor) ~= nil
end

function source:get_completions(ctx, callback)
  local context = parse_context(ctx.bufnr, ctx.line, ctx.cursor)
  if not context then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  local entry = ensure_cache(context.root)
  local items = {}

  if context.kind == "wiki" then
    if not entry.notes then
      entry.notes = scan_notes(context.root)
    end

    for _, note in ipairs(entry.notes) do
      items[#items + 1] = build_wiki_item(note, ctx, context, self.opts.close_wiki)
    end

    if self.opts.include_undefined_refs then
      if not entry.undefined_refs then
        entry.undefined_refs = scan_undefined_refs(context.root, entry.notes)
      end
      for _, ref in ipairs(entry.undefined_refs) do
        items[#items + 1] = build_undefined_ref_item(ref, ctx, context, self.opts.close_wiki)
      end
    end
  else
    if not entry.tags then
      entry.tags = scan_tags(context.root)
    end

    for _, tag in ipairs(entry.tags) do
      items[#items + 1] = build_tag_item(tag, ctx, context)
    end
  end

  callback({
    items = items,
    is_incomplete_forward = false,
    is_incomplete_backward = false,
  })
end

return source
