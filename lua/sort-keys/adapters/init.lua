--- Adapter registry for sort-keys.nvim
local M = {}

--- @type table<string, AdapterInterface>
local registered_adapters = {}

--- List of known adapter module names to try
local known_adapters = { "json", "lua", "javascript", "nix" }

--- Register an adapter for a language (overrides existing adapters)
--- @param lang string Language name
--- @param adapter AdapterInterface
function M.register(lang, adapter)
    registered_adapters[lang] = adapter
    -- Also register for all filetypes the adapter handles (override existing)
    if adapter.get_filetypes then
        for _, ft in ipairs(adapter.get_filetypes()) do
            registered_adapters[ft] = adapter
        end
    end
end

--- Get an adapter for a language
--- @param lang string Language name
--- @return AdapterInterface|nil
function M.get_adapter(lang)
    -- Return registered adapter
    if registered_adapters[lang] then
        return registered_adapters[lang]
    end

    -- Try to load the adapter module directly
    local ok, adapter = pcall(require, "sort-keys.adapters." .. lang)
    if ok and adapter then
        M.register(lang, adapter)
        return adapter
    end

    -- Try known adapters to see if any handles this filetype
    for _, adapter_name in ipairs(known_adapters) do
        local ok2, known_adapter = pcall(require, "sort-keys.adapters." .. adapter_name)
        if ok2 and known_adapter and known_adapter.get_filetypes then
            for _, ft in ipairs(known_adapter.get_filetypes()) do
                if ft == lang then
                    M.register(adapter_name, known_adapter)
                    return known_adapter
                end
            end
        end
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
    -- Load all known adapters to populate filetypes
    for _, adapter_name in ipairs(known_adapters) do
        local ok, adapter = pcall(require, "sort-keys.adapters." .. adapter_name)
        if ok and adapter then
            M.register(adapter_name, adapter)
        end
    end

    local languages = {}
    for lang, _ in pairs(registered_adapters) do
        table.insert(languages, lang)
    end
    return languages
end

return M
