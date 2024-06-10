function Div(div)
  -- Check if the `div` has the class "to-panel"
  if not div.classes:includes("to-panel") then 
    return
  end
  
  -- Initialize local variables for code block and cell output
  local code_block = nil
  local cell_output = nil

  -- Walk through the content of the `div` to find `CodeBlock` and `Div` elements
  div:walk({
    CodeBlock = function(code)
      -- If a `CodeBlock` with the class "cell-code" is found, assign it to `code_block`
      if code.classes:includes("cell-code") then
        code_block = code
      end
    end,
    Div = function(div)
      -- If a `Div` with the class "cell-output" is found, assign it to `cell_output`
      if div.classes:includes("cell-output") then
        cell_output = div
      end
    end
  })

  -- Create a tab for the rendered output
  local rendered = quarto.Tab({ title = "Rendered", content = cell_output })
  -- Create a tab for the source code
  local source = quarto.Tab({ title = "Source", content = code_block })
  -- Combine the tabs into a list
  local tabs = pandoc.List({ rendered, source })

  -- Return a `quarto.Tabset` with the created tabs and specific attributes
  return quarto.Tabset({
    level = 3,
    tabs = tabs,
    attr = pandoc.Attr("", {"panel-tabset"}) -- This attribute assignment shouldn't be necessary but addresses a known issue. Remove when using Quarto 1.5 or greater as required version.
  })
end