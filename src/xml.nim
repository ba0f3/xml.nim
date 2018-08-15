# xml
# Copyright Huy Doan
# Pure Nim XML parser

import strformat, strutils, strtabs


const NameIdentChars = IdentChars + {':', '-', '.'}

type
  XmlParserException* = object of Exception

  TokenKind* = enum
    TAG_BEGIN
    TAG_END
    NAME
    SIMPLE_TAG_CLOSE
    TAG_CLOSE
    STRING
    TEXT
    EQUALS
    CDATA_BEGIN
    CDATA_END

  XmlToken* = object
    kind*: TokenKind
    text*: string

  XmlNode* = ref object of RootObj
    name*: string
    text*: string
    attributes*: StringTableRef
    children*: seq[XmlNode]

template error(message: string) =
  raise newException(XmlParserException, message)

proc expect(tokens: seq[XmlToken], i: int, kind: TokenKind) {.inline.} =
  if tokens[i].kind != kind:
    error(fmt"{kind} expected, got {tokens[i].kind}")

proc token(kind: TokenKind, text = ""): XmlToken =
  result.kind = kind
  result.text = text

template skip_until(c: char) =
  while(input[pos] != c):
    inc(pos)

template skip_until(s: string) =
  let length = s.len
  while(input[pos..<pos+length] != s):
    inc(pos)
  inc(pos, length)


iterator tokens*(input: string): XmlToken {.inline.} =
  ## This iterator yield tokens that extracted from `input`
  var
    pos: int
    length = input.len
    is_cdata = false
    is_text = false

  var ch = input[pos]

  while pos < length and input[pos] != '\0':
    let ch = input[pos]
    if ch in Whitespace:
      inc(pos)
      continue
    case ch
    of '<':
      if not is_cdata:
        inc(pos)
        case input[pos]:
        of '?':
          # skips prologue
          skip_until('>')
          # print out prologue
          #echo input[0..pos]
          inc(pos)
        of '!':
          inc(pos)
          if input[pos..pos+6] == "[CDATA[":
            # CDATA
            is_cdata = true
            is_text = true
            yield token(CDATA_BEGIN)
            inc(pos, 6)
          elif input[pos..pos+1] == "--":
            # skips comment
            let comment_start = pos-2
            skip_until("-->")
            # print out full of comment
            #echo input[comment_start..<pos]
          else:
            error(fmt"text expected, found ""{input[pos]}"" at {pos}")
        of '/':
          yield token(TAG_CLOSE)
          is_text = false
        else:
          dec(pos)
          yield token(TAG_BEGIN)
          is_text = false
        inc(pos)
    of ']':
      if input[pos..pos+2] != "]]>":
        error(fmt"cdata end ""]]>"" expected, found {input[pos..pos+2]} at {pos}")
      is_text =  true
      is_cdata = false
      yield token(CDATA_END)
      inc(pos, 3)
    of '\'', '"':
      inc(pos)
      var next_ch = input.find(ch, pos)
      if next_ch == -1:
        error(fmt"unable to find matching string quote last found {pos}") 
      yield token(STRING, input[pos..<next_ch])
      pos = next_ch+1
    of '>':
      inc(pos)
      is_text = true
      yield token(TAG_END)
    of '=':
      inc(pos)
      yield token(EQUALS)
    of '/':
      if input[pos+1] == '>':
        yield token(SIMPLE_TAG_CLOSE)
        inc(pos, 2)
    else:
      if(is_text):
        var text_end = 0
        if is_cdata:
          text_end = input.find("]]>", pos)
        else:
          text_end = input.find('<', pos)
        if text_end == -1:
          error(fmt"unable to find ending point of text, started at {pos}")
        yield token(TEXT, input[pos..<text_end])
        pos = text_end
        is_text = false
      else:
        var
          name = ""
          name_start = pos
        var c = input[pos]
        if c in IdentStartChars:
          while c in NameIdentChars:
            name.add(c)
            inc(pos)
            c = input[pos]
          yield token(NAME, name)
          if not (c in NameIdentChars):
            dec(pos)
        inc(pos)

proc tokens*(input: string): seq[XmlToken] =
  result = @[]
  for token in input.tokens:
    result.add(token)


proc newNode(name: string, text = ""): XmlNode =
  ## create new node
  new(result)
  result.name = name
  result.text = text

proc child*(node: XmlNode, name: string): XmlNode =
  ## finds the first element of `node` with name `name`
  ## returns `nil` on failure
  if not node.children.isNil:
    for n in node.children:
      if n.name == name:
        result = n
        break

proc addChild*(node, child: XmlNode) =
  if node.children.isNil:
    node.children = @[]
  node.children.add(child)

proc hasAttr*(node: XmlNode, name: string): bool =
  ## returns `true` if `node` has attribute `name`
  if node.attributes.isNil:
    result = false
  else:
    result = node.attributes.hasKey(name)

proc attr*(node: XmlNode, name: string): string =
  ## returns value of attribute `name`, returns "" on failure
  if not node.attributes.isNil:
    result = node.attributes.getOrDefault(name)

proc setAttr(node: XmlNode, name, value: string) =
  if node.attributes.isNil:
    node.attributes = newStringTable(modeCaseInsensitive)
    node.attributes[name] = value

proc parseNode(tokens: seq[XmlToken], start: int): XmlNode =
  var
    attrName: string
    last: TokenKind
    closed = false

  var i = start

  expect(tokens, i, TAG_BEGIN)

  inc(i)
  expect(tokens, i, NAME)

  result = newNode(tokens[i].text)

  inc(i)
  while tokens[i].kind == NAME:
    echo  fmt"I {i}"
    attrName = tokens[i].text
    inc(i)
    expect(tokens, i, EQUALS)

    inc(i)
    expect(tokens, i, STRING)
    result.setAttr(attrName, tokens[i].text)
    inc(i)
    echo tokens[i].kind

  if tokens[i].kind == SIMPLE_TAG_CLOSE:
    return result;

  expect(tokens, i, TAG_END)

  inc(i)
  while tokens[i].kind != TAG_CLOSE:
    case tokens[i].kind
    of TEXT:
      result.text = tokens[i].text
    of CDATA_BEGIN:
      inc(i)
      expect(tokens, i, TEXT)
      result.text = tokens[i].text
      inc(i)
      expect(tokens, i, CDATA_END)
    of TAG_BEGIN:
      result.addChild(parseNode(tokens, i))
      continue
    else:
      error(fmt"unknown token kind {tokens[i].kind}")
    inc(i)
  inc(i)
  expect(tokens, i, NAME)

  if tokens[i].text != result.name:
    error(fmt"Tag name not matched, expected '{result.name}', got 'tokens[i].text'")

  inc(i)
  expect(tokens, i, TAG_END)
  inc(i)



proc parseXml(input: string): XmlNode =
  ## this proc takes an XML `input` as string
  ## returns root XmlNode
  var tokens = tokens(input)
  result = parseNode(tokens, 0)


when isMainModule:
  let xml = """<?xml version="1.0" encoding="UTF-8"?>
<!-- example -->
<classes>
    <simple closed="true"/>
    <note><![CDATA[This text is CDATA<>]]></note>
    <class name="Klient">
        <attr type="int">id</attr>
        <attr type="String">imie</attr>
        <attr type="String">nazwisko</attr>
        <attr type="Date">dataUr</attr>
    </class>
    <class name="Wizyta">
        <attr type="int">id</attr>
        <attr type="Klient">klient</attr>
        <attr type="Date">data</attr>
    </class>
</classes>
"""
  assert tokens(xml).len == 109
  #for t in xml.tokens:
  #  echo t
  var root = parseXml(xml)
  echo root[]
  assert root.name == "classes"
  let
    simple = root.children[0]
    note = root.children[1]

  assert simple.name == "simple"
  assert simple.hasAttr("closed")
  assert simple.attr("closed") == "true"
  assert simple.text == ""


