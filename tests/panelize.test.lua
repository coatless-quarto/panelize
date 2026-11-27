-- panelize tests. Run from the repo root: quarto pandoc lua path/to/qtest.lua
-- The fixtures run R and Python through knitr, so they need R with rmarkdown
-- and a python3 on the PATH (no reticulate).
local t = require("qtest")

--- The HTML of one tab: from its tab pane to the next tab pane or the end of
--- the tabset.
---@param html string
---@param id string Tab pane id, e.g. "tabset-1-2"
---@return string
local function tab(html, id)
  local start = html:find('<div id="' .. id .. '"', 1, true)
  t.ok(start, "the page has tab " .. id)
  local stop = html:find('<div id="tabset-', start + 1, true)
    or html:find('<div class="tabset-margin-container">', start + 1, true)
  return html:sub(start, stop and stop - 1 or #html)
end

--- The text of some HTML, without tags (code is split into highlighting spans).
---@param html string
---@return string
local function text(html)
  return (html:gsub("<[^>]*>", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end

t.test(".to-source: a Result tab with the cleaned code and its outputs, and a Source tab with the cell as written", function()
  local r = t.render("source.qmd", "html")
  r:succeeded()
  t.count(r.text, '<div class="panel-tabset">', 2)
  t.in_order(r.text, { ">Result</a>", ">Source</a>" })

  local result = tab(r.text, "tabset-1-1")
  t.not_contains(text(result), "```")
  t.not_contains(text(result), "#|")
  t.in_order(text(result), { "1 + 1\n\nplot(1:10)", "[1] 2" })
  t.contains(result, "<figure")

  t.in_order(text(tab(r.text, "tabset-1-2")), { "```{r}\n#| eval: true\n1 + 1\n\nplot(1:10)\n```", "[1] 2" })
end)

-- Regression: the second tab was built without the cell's content, so it
-- came out empty.
t.test("the second tab is never empty", function()
  local source = tab(t.render("source.qmd", "html").text, "tabset-2-2")
  t.in_order(text(source), { "x <- 3", "[1] 3" })
  local interactive = tab(t.render("webr.qmd", "html").text, "tabset-1-2")
  t.contains(interactive, "1 + 1")
end)

-- Regression (0.0.2): only one output made it into the Result tab, and graphs
-- were left out.
t.test(".to-webr: the Result tab keeps every code piece with its output, plot included; the Interactive tab is one webR cell", function()
  local r = t.render("webr.qmd", "html")
  r:succeeded()
  t.in_order(r.text, { ">Result</a>", ">Interactive</a>" })
  local result = tab(r.text, "tabset-1-1")
  t.in_order(text(result), { "1 + 1", "[1] 2", "plot(1:10)" })
  t.in_order(result, { "plot", "<figure" })

  local interactive = tab(r.text, "tabset-1-2")
  t.count(interactive, '<pre class="{webr-r} cell-code"><code>1 + 1\nplot(1:10)</code></pre>', 1)
end)

t.test(".to-pyodide: the Result tab has the output; the Interactive tab is one Pyodide cell", function()
  local r = t.render("pyodide.qmd", "html")
  r:succeeded()
  t.in_order(text(tab(r.text, "tabset-1-1")), { "print(x)", "[1, 2]" })
  t.count(tab(r.text, "tabset-1-2"),
    '<pre class="{pyodide-python} cell-code"><code>x = [1, 2]\nprint(x)</code></pre>', 1)
end)
