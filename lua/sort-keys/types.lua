--- Type definitions for sort-keys.nvim
--- @meta

--- @class SortKeysOptions
--- @field flags? string Sorting flags (i, n, f, x, o, b, u)
--- @field reverse? boolean Reverse sort order
--- @field deep? boolean Recursively sort nested containers
--- @field range? { [1]: number, [2]: number } Line range (1-indexed)

--- @class ElementInfo
--- @field node TSNode
--- @field key_text string|nil Sort key
--- @field value_text string Full element text
--- @field start_row number
--- @field end_row number
--- @field leading_comments string[]
--- @field trailing_comment string|nil Inline comment on the same line
--- @field separator string|nil
--- @field is_excluded boolean
--- @field indent string

--- @class ContainerInfo
--- @field node TSNode
--- @field type string Container type (e.g., "object", "array", "table_constructor")
--- @field start_row number
--- @field end_row number
--- @field start_col number
--- @field end_col number
--- @field is_multiline boolean

--- @class AdapterInterface
--- @field get_filetypes fun(): string[]
--- @field get_container_types fun(): string[]
--- @field get_element_wrapper fun(container_type: string): string|nil
--- @field get_element_type fun(container_type: string): string|nil
--- @field get_separator fun(container_type: string): string
--- @field get_brackets fun(container_type: string): string|nil, string|nil
--- @field get_key_from_element fun(element: TSNode, bufnr: number): string|nil
--- @field is_excluded_element fun(node: TSNode): boolean
--- @field extract_elements fun(container: TSNode, bufnr: number): ElementInfo[]
--- @field format_output fun(elements: ElementInfo[], container: ContainerInfo, bufnr: number): string[]

--- @class AdapterConfig
--- @field filetypes? string[]
--- @field container_types string[]
--- @field element_wrappers? table<string, string>
--- @field element_types table<string, string|nil>
--- @field separators table<string, string>
--- @field brackets? table<string, string[]>
--- @field exclude_types? string[]
--- @field get_key_from_element fun(element: TSNode, bufnr: number): string|nil

--- @class ParsedFlags
--- @field case_insensitive boolean
--- @field numeric_mode "decimal"|"float"|"hex"|"octal"|"binary"|nil
--- @field unique boolean

return {}
