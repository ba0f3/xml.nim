import xml, xml/selector

const
  content1 = """<?xml version="1.0" encoding="UTF-8"?><profile>
  <steamID64>76561198859045421</steamID64>
</profile>"""

  content2 = """<?xml version="1.0" encoding="UTF-8"?> <profile>
  <steamID64>76561198859045421</steamID64>
</profile>"""

static:
  var
    d1 = q(content1)
    d2 = q(content2)

  echo d1.select("steamID64")
  echo d2.select("steamID64")
  assert d1.select("steamID64")[0].text == d2.select("steamID64")[0].text
