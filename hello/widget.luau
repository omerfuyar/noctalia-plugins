--!nonstrict
function update()
  noctalia.setUpdateInterval(60000)
  barWidget.setGlyph("puzzle")
  if not barWidget.isVertical() then
    barWidget.setText(noctalia.tr("widget.text"))
  end
end

function onClick()
  noctalia.notify(noctalia.tr("widget.text"), noctalia.tr("widget.clicked"))
end
