# Lists

Ordered, unordered, nested, and GFM task lists.

## Unordered lists

- First item
- Second item
- Third item

All three markers are interchangeable:

- Hyphen
* Asterisk
+ Plus

## Ordered lists

1. First
2. Second
3. Third

Numbers do not have to be sequential — the renderer starts at the
first number and increments from there:

1. Starts at one
1. Still renders as two
1. And three

Or start from an arbitrary number:

5. Five
6. Six
7. Seven

## Nested lists

- Top level
  - Nested one
    - Nested two
      - Nested three
  - Back to nested one
- Second top-level entry
  1. Ordered inside unordered
  2. Keeps its own numbering
- Third top-level entry

Mixing markers across nesting is fine — the viewer renders each
level with the Material-3 spacing preset.

## Task lists (GFM)

- [x] Completed task
- [x] Another completed task
- [ ] Pending task
- [ ] Another pending task
- [x] Tasks ~~can be struck through~~ for emphasis
- [ ] Tasks can carry **formatting** and [links](https://example.com)
- [x] Nested tasks work:
  - [x] Subtask one
  - [ ] Subtask two

The check mark state is a read-only render in this viewer — tapping
a task-list box does not toggle its state. The user is expected to
tick / untick in their editor of choice and re-sync.

## Complex item content

A list item can contain multiple paragraphs, code blocks, and even
other markdown:

1. First paragraph of the first item.

   A second paragraph sits under the same item as long as it is
   indented to match the first character of the item body.

   ```dart
   // A fenced code block inside an ordered list item.
   void greet(String name) => print('Hello, \$name');
   ```

   > A blockquote inside the same item.

2. The second item resumes the counter normally.

## Deeply-nested mixed content

- Top-level point
  - Sub-point with **bold** and *italic*
    - Sub-sub-point with `inline code`
      - Fourth level with [a link](https://github.com/cemililik/markdown-viewer-mobile)
        - Fifth level is where the indentation budget runs out but it still renders
