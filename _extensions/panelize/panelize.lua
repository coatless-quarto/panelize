-- Function to process code blocks
local function clean_code_block(el, language)
  
  -- Check if the code block contains R code
  if el.text:match("^```{{"..language) then
    -- Remove the ```{{<language>}} and ``` lines
    local cleaned_text = el.text:gsub("```{{".. language .."}}\n", ""):gsub("\n```", "")

    -- Remove lines starting with #| (options)
    cleaned_text = cleaned_text:gsub("#|.-\n", "")

    -- Add 'language' to the class list if not already present
    if not el.attr.classes:includes(language) then
      table.insert(el.attr.classes, 1, language)
    end

    -- Return the modified code block
    return pandoc.CodeBlock(cleaned_text, el.attr)
  end

  -- If not an R code block, return unchanged
  return el
end

-- Helper function to clone and update code block attributes
local function clone_and_update_code_block(code_block, new_classes)
  local new_attr = code_block.attr:clone()
  new_attr.classes = pandoc.List(new_classes)
  return pandoc.CodeBlock(code_block.text, new_attr)
end

function Div(div)
  local to_webr = div.classes:includes("to-webr")
  local to_pyodide = div.classes:includes("to-pyodide")

  -- Check if the `div` has the class "to-source"/"to-webr"/"to-pyodide"
  if not (div.classes:includes("to-source") or to_webr or to_pyodide) then 
    return
  end
  
  -- Initialize local variables for code block, cell output, and language
  local code_block = nil
  local cell_output = nil
  local language = nil

  -- Walk through the content of the `div` to find `CodeBlock` and `Div` elements
  div:walk({
    CodeBlock = function(code)
      -- If a `CodeBlock` with the class "cell-code" is found, assign it to `code_block`
      if code.classes:includes("cell-code") then
        code_block = code
        -- Determine the language of the code block
        if code.classes:includes("r") or code.text:match("^```{{r") then
          language = "r"
        elseif code.classes:includes("python") or code.text:match("^```{{python")  then
          language = "python"
        else 
          quarto.log.error("Please only specify either R or Python code cells inside of the `.to-*` div.")
        end
      end
    end,
    Div = function(div)
      -- If a `Div` with the class "cell-output" is found, assign it to `cell_output`
      if div.classes:includes("cell-output") then
        cell_output = div
      end
    end
  })

  local cleaned_code_cell = clean_code_block(code_block, language)

  -- Determine the type of Tab to use
  local tabs = nil

  -- Check if the language matches the required condition
  if to_webr or to_pyodide then
    -- Create a tab for the Result
    local result_tab = quarto.Tab({ title = "Result", content = pandoc.List({code_block, cell_output}) })

    -- Pick attribute classes
    local code_block_attr_classes = to_webr and {"{webr-r}", "cell-code"} or {"{pyodide-python}", "cell-code"}

    -- Create a tab for the Source
    local interactive_tab = quarto.Tab({ title = "Interactive", content =  clone_and_update_code_block(code_block, code_block_attr_classes) })

    -- Combine the tabs into a list
    tabs = pandoc.List({ result_tab, interactive_tab })
  else 
    -- Create a tab for the Rendered
    local rendered_tab = quarto.Tab({ title = "Result", content = pandoc.List({cleaned_code_cell, cell_output}) })
    
    -- Create a tab for the Source
    local source_tab = quarto.Tab({ title = "Source", content =  clone_and_update_code_block(code_block, {"md", "cell-code"}) })

    -- Combine the tabs into a list
    tabs = pandoc.List({ rendered_tab, source_tab })
  end

  -- Return a `quarto.Tabset` with the created tabs and specific attributes
  return quarto.Tabset({
    level = 3,
    tabs = tabs,
    attr = pandoc.Attr("", {"panel-tabset"}) -- This attribute assignment shouldn't be necessary but addresses a known issue. Remove when using Quarto 1.5 or greater as required version.
  })
end