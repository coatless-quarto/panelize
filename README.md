# quarto-panelize: A Quarto Extension for Panelizing Code Cells

The `quarto-panelize` extension allows you to tabbify existing code cells to show their source or add interactivity.

## Installation

To install the `quarto-panelize` extension, follow these steps:

1. Enter a Quarto project.

2. Open your terminal inside the Quarto project.

3. Run the following command:

```bash
quarto add coatless-quarto/panelize
```

This command will download and install the extension under the `_extensions` subdirectory of your Quarto project. If you are using version control, ensure that you include this directory in your repository.

## Usage

For each document, place the `panelize` filter in the document's header:

```yml
filters:
  - panelize
```

Then, wrap existing R or Python code cells using a `Div` and specify the a panelize class. 
Supported options include:

| Class         | Description                                                                         |
|---------------|-------------------------------------------------------------------------------------|
| `.to-source`  | Convert a code cell to show rendered output and its source.                         |
| `.to-pyodide` | Convert code cell from static Python code to interactive Python code using Pyodide. |
| `.to-webr`    | Convert code cell from static R code to interactive R code using webR.              |


For example, if we have a code cell with R that we want to show its options, then we use:

```` md
:::{.to-source}
```{r}
#| echo: fenced
#| eval: true
1 + 1
```
:::
````

### Interactivity

If you wish to make your code interactive, please install the following Quarto extensions:

```sh
# For Python
quarto add coatless-quarto/pyodide

# For R
quarto add coatless/quarto-webr
```

Next, modify the document header and place the desired extension filter **after** `panelize`, e.g.

```yml
filters:
  - panelize
  - pyodide
  - webr
```

> [!IMPORTANT]
>
> Order matters! Please make sure to place the filters after `panelize`.
> Otherwise, the interactivity filter will *not* detect the code cell!
>

Finally, wrap the existing code cell using a `Div` with a class of either `.to-pyodide` or `.to-webr`.

For Python, that looks like: 

````md
:::{.to-pyodide}
```{python}
4 + 5
```
:::
````

For R, that looks like: 

````md
:::{.to-webr}
```{r}
1 + 1
```
:::
````


## Acknowledgements

Thanks to [@mcanouil](https://github.com/mcanouil) and [@cscheid](https://github.com/cscheid) who provided great insight into approaching this problem by re-orienting it in a way that is more managable. Please see the [full discussion](https://github.com/quarto-dev/quarto-cli/discussions/9646).