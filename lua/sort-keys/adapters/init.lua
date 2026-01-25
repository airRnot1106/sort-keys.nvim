--- Adapter registry for sort-keys.nvim
local M = {}

--- @type table<string, AdapterInterface>
local registered_adapters = {}

--- @type table<string, string>
local language_aliases = {
    -- TypeScript uses JavaScript adapter
    typescript = "javascript",
    typescriptreact = "javascript",
    javascriptreact = "javascript",
    -- JSON variations
    jsonc = "json",
    json5 = "json",
}

--- Register an adapter for a language
--- @param lang string Language name
--- @param adapter AdapterInterface
function M.register(lang, adapter)
    registered_adapters[lang] = adapter
end

--- Get an adapter for a language
--- @param lang string Language name
--- @return AdapterInterface|nil
function M.get_adapter(lang)
    -- Check for alias first
    local actual_lang = language_aliases[lang] or lang

    -- Return registered adapter
    if registered_adapters[actual_lang] then
        return registered_adapters[actual_lang]
    end

    -- Try to load the adapter module
    local ok, adapter = pcall(require, "sort-keys.adapters." .. actual_lang)
    if ok and adapter then
        registered_adapters[actual_lang] = adapter
        return adapter
    end

    return nil
end

--- Check if an adapter exists for a language
--- @param lang string Language name
--- @return boolean
function M.has_adapter(lang)
    return M.get_adapter(lang) ~= nil
end

--- Get list of supported languages
--- @return string[]
function M.get_supported_languages()
    local languages = {}
    for lang, _ in pairs(registered_adapters) do
        table.insert(languages, lang)
    end
    -- Add aliases
    for alias, _ in pairs(language_aliases) do
        if not vim.tbl_contains(languages, alias) then
            table.insert(languages, alias)
        end
    end
    return languages
end

return M
