import xml

proc do_parse(input: string): bool =
  try:
    var root = parseXml(input)
    return root != nil and root.name.len > 0
  except XmlParserException:
    return false;

when isMainModule:
  let input = readAll(stdin);
  if do_parse(input): echo "OK"
  else: echo "FAIL"

