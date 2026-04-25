# Markdown Stress Fixture

Paragraph with **bold**, *italic*, `inline code`, [link](https://example.com), ~~strike~~, and a very long sentence that should wrap naturally without breaking backgrounds or leaving visible markdown artifacts in the terminal renderer.

---

## Ordered Lists

1. First item
2. Second item
3. Third item

   1. Nested ordered item
   2. Another nested item
4. Fourth item

## Mixed Nested Content

1. Ordered item with paragraph

   This paragraph belongs to the ordered item.
2. Ordered item with blockquote

   > Quote inside ordered list.
   >
   > - Bullet inside quote
   >   Another paragraph inside the bullet.
3. Ordered item with code

   ```elixir
   def hello(name) do
     {:ok, "hello #{name}"}
   end
   ```
4. Ordered item with task list

   - [x] Done nested task
   - [ ] Pending nested task

## Blockquotes

> This is a blockquote.
>
> It can contain multiple paragraphs.
>
> > This is a nested blockquote.
> >
> > Nested quotes test indentation.

## Tables

| Feature | Status | Notes |
| --- | --- | --- |
| read | done | syntax highlighted |
| write | done | diff output |
| edit | done | exact replacement |

## Task Lists

- [x] Completed task
- [ ] Pending task
- [x]

## Code

```elixir
IO.puts(:ok)

Enum.map(1..3, &(&1 * 2))
```
