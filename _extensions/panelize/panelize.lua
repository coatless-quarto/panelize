-- Define helper types for clarity
---@class Block
---@field t string The type of the block
---@field attr table Block attributes
---@field content? table Block content
---@field classes table List of classes
---@field text? string Block text if CodeBlock

---@class Cell
---@field code_blocks Block[] List of code blocks
---@field outputs Block[] List of output blocks
---@field language string Programming language

---@class DocumentMetadata
---@field panelize table<string, any> Configuration options
---@field handler_added boolean Flag for handler addition

-- Store metadata at module level
---@type DocumentMetadata
local document_metadata = {
    panelize = {},
    handler_added = false
}

-- Helper function to detect language from a code block
---@param block Block The code block to analyze
---@return string|nil language The detected language
local function detect_language(block)
    if block.attr.classes:includes("r") then
        return "r"
    elseif block.attr.classes:includes("python") then
        return "python"
    elseif block.text:match("^```{{r") then
        return "r"
    elseif block.text:match("^```{{python") then
        return "python"
    end
    return nil
end

-- Helper function to clean code block text
---@param block Block The code block to clean
---@param language string The programming language
---@param remove_fences boolean Whether to remove code fences and options
---@return string cleaned_text The processed text
local function clean_code_text(block, language, remove_fences)
    local text = block.text
    if remove_fences then
        if text:match("^```{{" .. language .. "}") then
            text = text:gsub("```{{" .. language .. "}}\n", ""):gsub("\n```", "")
        end
        text = text:gsub("#|.-\n", "")
    end
    return text
end

-- Helper function to extract cell content
---@param cell_div Block The cell div block
---@return Cell cell The processed cell content
local function extract_cell_content(cell_div)
    local cell = {
        blocks = {},  -- Will store alternating code blocks and their outputs
        language = nil
    }
    
    -- Process blocks in sequence
    for _, block in ipairs(cell_div.content) do
        if block.t == "CodeBlock" and block.classes:includes("cell-code") then
            table.insert(cell.blocks, {type = "code", content = block})
            -- Detect language from first code block if not already set
            if not cell.language then
                cell.language = detect_language(block)
            end
        elseif block.t == "Div" and (
            block.classes:includes("cell-output") or 
            block.classes:includes("cell-output-stdout") or 
            block.classes:includes("cell-output-display")
        ) then
            table.insert(cell.blocks, {type = "output", content = block})
        end
    end
    
    return cell
end

-- Helper function to create tab content
---@param cell Cell The cell content
---@param tab_type string The type of tab ("result", "source", or "interactive")
---@return pandoc.List content The tab content
local function create_tab_content(cell, tab_type)
    local content = pandoc.List()
    
    if tab_type == "interactive" then
        -- For interactive tab, combine all code blocks into one
        local combined_code = table.concat(
            pandoc.List(cell.blocks)
                :filter(function(block) return block.type == "code" end)
                :map(function(block) return clean_code_text(block.content, cell.language, true) end),
            "\n"
        )
        
        -- Create single code block with appropriate classes
        local classes = cell.language == "r" and {"{webr-r}", "cell-code"} or {"{pyodide-python}", "cell-code"}
        local attr = pandoc.Attr("", classes, {})
        content:insert(pandoc.CodeBlock(combined_code, attr))
    else
        -- For result and source tabs, process blocks in sequence
        for _, block in ipairs(cell.blocks) do
            if block.type == "code" then
                if tab_type == "result" then
                    -- For result tab, clean code but keep language class
                    local new_attr = block.content.attr:clone()
                    new_attr.classes = pandoc.List({cell.language})
                    local cleaned_text = clean_code_text(block.content, cell.language, true)
                    content:insert(pandoc.CodeBlock(cleaned_text, new_attr))
                else
                    -- For source tab, use original code block
                    content:insert(block.content)
                end
            else  -- output block
                content:insert(block.content)
            end
        end
    end
    
    return content
end

-- Process metadata
function Meta(meta)
    if meta and meta.panelize then
        for key, value in pairs(meta.panelize) do
            document_metadata.panelize[key] = pandoc.utils.stringify(value)
        end
    end
    return meta
end

-- Main processing function for divs
function Div(div)
    -- Check for required classes
    local to_webr = div.classes:includes("to-webr")
    local to_pyodide = div.classes:includes("to-pyodide")
    local to_source = div.classes:includes("to-source")
    
    if not (to_source or to_webr or to_pyodide) then
        return div
    end
    
    -- Find cell div
    local cell_div = nil
    for _, block in ipairs(div.content) do
        if block.t == "Div" and block.classes:includes("cell") then
            cell_div = block
            break
        end
    end
    
    if not cell_div then
        return div
    end
    
    -- Extract cell content
    local cell = extract_cell_content(cell_div)
    
    if not cell.language then
        quarto.log.error("Please specify either R or Python code cells inside of the .to-* div.")
        return div
    end
    
    -- Create tabs
    local tabs = pandoc.List()
    
    if to_webr or to_pyodide then
        -- Interactive environment tabs
        tabs:insert(quarto.Tab({
            title = "Result",
            content = pandoc.Blocks(create_tab_content(cell, "result"))
        }))
        tabs:insert(quarto.Tab({
            title = "Interactive",
            content = pandoc.Blocks(create_tab_content(cell, "interactive"))
        }))
    else
        -- Source code tabs
        tabs:insert(quarto.Tab({
            title = "Result",
            content = pandoc.Blocks(create_tab_content(cell, "result"))
        }))
        tabs:insert(quarto.Tab({
            title = "Source",
            content = pandoc.Blocks(create_tab_content(cell, "source"))
        }))
    end
    
    -- Return just the tabset, replacing the original div
    return quarto.Tabset({
        level = 3,
        tabs = tabs,
        attr = pandoc.Attr("", {"panel-tabset"}, {})
    })
end

-- Return the list of functions to register
return {
    {Meta = Meta},
    {Div = Div}
}