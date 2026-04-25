# Comprehensive Markdown Test Suite

> A compact but feature-rich Markdown response to test rendering, formatting, nesting, code blocks, tables, lists, links, and edge cases.

---

## 1. Text Formatting

This paragraph includes **bold text**, *italic text*, ***bold italic text***, ~~strikethrough~~, `inline code`, and a normal sentence.

You can also combine formatting:

- **Bold with `inline code`**
- *Italic with [a link](https://example.com)*
- ~~Deleted text with **bold inside**~~
- `code_with_snake_case()` next to punctuation.

---

## 2. Headings

# H1 Heading

## H2 Heading

### H3 Heading

#### H4 Heading

##### H5 Heading

###### H6 Heading

---

## 3. Blockquotes

> This is a blockquote.
>
> It supports multiple paragraphs.
>
> > This is a nested blockquote.
> >
> > - With a list
> > - Inside the quote
>
> Final line of the outer.

quote---

## 4. Lists

### Unordered List

- Item one
- Item two

  - Nested item two-one
  - Nested item two-two

    - Deeply nested item

- three Item

### Ordered List

1. First step
2. Second step
   1. Sub-step A
   2. Sub-step B
3. Third step

### Mixed Checklist

- [x] Write tests
- [x] Run formatter
- [ ] Add integration coverage
- [ ] Document edge cases

---

## 5. Code Blocks

### Elixir

```elixir
defmodule Example.Counter do
  use GenServer

  def start_link(initial \\ 0) do
    GenServer.start_link(__MODULE__, initial, name: __MODULE__)
  end

  def increment do
    GenServer.call(__MODULE__, :increment)
  end

  @impl true
  def init(initial), do: {:ok, initial}

  @impl true
  def handle_call(:increment, _from, state) do
    next = state + 1
    {:reply, next, next}
  end
end
```

### JSON

```json
{
  "name": "markdown-test",
  "features": ["tables", "lists", "code", "links"],
  "enabled": true,
  "count": 42
}
```

### Bash

```bash
mix format
mix test
mix credo --strict
```

---

## 6. Tables

| Feature | Supported | Notes |
| --- | --- | --- |
| Bold | ✅ | **text** |
| Italic | ✅ | *text* |
| Tables | ✅ | Alignment included |
| Code blocks | ✅ | Fenced blocks |
| Footnotes | ⚠️ | Renderer-dependent |

### Alignment Test

| Left Aligned | Center Aligned | Right Aligned |
| :--- | :---: | ---: |
| alpha | beta | gamma |
| short | medium text | very long text |
| 1 | | |
| 1 | 22 | 333 |

---

## 7. Links and Images

Inline link: [OpenAI](https://openai.com)

Reference-style link: [Example Reference][example-ref]

Autolink: <https://example.com>

Image syntax:

![Placeholder image](https://example.com/image.png)

[example-ref]: https://example.com

---

## 8. Horizontal Rules

Three hyphens:

---

Three asterisks:

***

Three underscores:

___

---

## 9. Escaping Characters

Escaped Markdown characters:

\*not italic\*

\# not a heading

\`not inline code\`

\[not a link\](https://example.com)

---

## 10. Nested Structure Stress Test

1. Parent ordered item

   - Nested unordered item

     > Blockquote inside list
     >
     > ```text
     > Code block inside blockquote inside list
     > ```

   - Another nested item

2. Second parent item

   1. Nested ordered item

      - Mixed child item

        - [x] Completed nested task
        - [ ] Incomplete nested task

---

## 11. HTML Inline Compatibility

Some renderers allow inline HTML:

<details>
<summary>Open details</summary>

This is content inside a `<details>` block.

- It includes list.
- It includes `inline code`.
- It includes **bold text**.

</details>

---

## 12. Math-Like Text

Inline math-style text: E = mc^2

Renderer-dependent LaTeX-style syntax:

$$
f(x) = x^2 + 2x + 1
$$

---

## 13. Definition-Style Content

Term: Markdown

: A lightweight markup language for plain text formatting.

Term: Renderer

: A system that converts Markdown into HTML or another display format.

---

## 14. Final Checklist

- [x] Headings
- [x] Emphasis
- [x] Lists
- [x] Blockquotes
- [x] Code blocks
- [x] Tables
- [x] Links
- [x] Images
- [x] Escaping
- [x] Nested structures
- [x] HTML compatibility
- [x] Renderer-dependent features

> End of comprehensive Markdown test.
