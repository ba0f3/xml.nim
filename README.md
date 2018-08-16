# xml.nim
Simple XML parser in pure Nim


This module written for *compile time* XML parsing purpose, it supports only some features:

- Nodes
- Atrributes
- CDATA and Text

> The parser is simple and small, no error checking/correcting. Use it as your own risk*

If you need a more powerful XML/HTML parser, consider using [parsexml](https://nim-lang.org/docs/parsexml.html)


This module contains a modified version of my [q.nim](https://github.com/OpenSystemsLab/q.nim) module, named `selector`.

Just import `xml/selector` to use it

### Usage:
```nim
import xml, xml/selector

var d = q($readFile("test.html"))


assert d.select("head *").len == 2
echo d.select("head *")

```