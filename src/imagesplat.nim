import strformat, math, sequtils, tables, sugar, random, os
import imageman
import imageman/kernels

randomize()

type
  PixelGrouper = proc(x, y: int): int
  ColorCombiner = proc(cols: seq[ColorRGBU]): ColorRGBU

proc apply(img: Image[ColorRGBU],
           groupFn: PixelGrouper,
           combineFn: ColorCombiner): Image[ColorRGBU] =
  let seed = rand(1..100_000)
  randomize(seed)
  var groups = initTable[int, seq[ColorRGBU]]()
  for j in 0..<img.height:
    let offset = j * img.width
    for i in 0..<img.width:
      let group = groupFn(i, j)
      if not groups.hasKey(group):
        groups[group] = newSeq[ColorRGBU]()
      groups[group].add img.data[offset + i]

  let combined = collect(initTable(groups.len)):
    for g, vs in groups.pairs: { g: combineFn(vs) }

  randomize(seed)
  result = initImage[ColorRGBU](img.width, img.height)
  for j in 0..<img.height:
    let offset = j * img.width
    for i in 0..<img.width:
      let group = groupFn(i, j)
      result.data[offset + i] = combined[group]

func averageColor(cs: seq[ColorRGBU]) : ColorRGBU =
  if cs.len == 0:
    return [0'u8, 0'u8, 0'u8].ColorRGBU
  var
    rSum = 0
    gSum = 0
    bSum = 0
  for c in cs:
    rSum += c.r.int
    gSum += c.g.int
    bSum += c.b.int
  return [(rSum div cs.len).uint8, (gSum div cs.len).uint8, (bSum div cs.len).uint8].ColorRGBU

func maxBy(f: proc(c: ColorRGBU): int): ColorCombiner =
  result = proc(cols: seq[ColorRGBU]): ColorRGBU =
    cols[map[ColorRGBU, int](cols, f).maxIndex]

func minBy(f: proc(c: ColorRGBU): int): ColorCombiner =
  result = proc(cols: seq[ColorRGBU]): ColorRGBU =
    cols[map[ColorRGBU, int](cols, f).minIndex]

func colorValueTotal(c: ColorRGBU): int = c.r.int + c.g.int + c.b.int

func rectsGrouper(imgW, imgH, rectW, rectH: int): PixelGrouper =
  let
    widthInRects = ceil(imgW / rectW)
    heightInRects = ceil(imgH / rectH)

  func grouper(x, y: int): int =
    let rx = floor((x / imgW) * widthInRects).int
    let ry = floor((y / imgH) * heightInRects).int
    result = ry * widthInRects.int + rx
  result = grouper

#[ if o = (0, 0), get which quadrant number (x, y) is in
   4|1
   -o-
   3|2
]#
template quadrant(x, y: int): int =
  if x > 0:
    if y > 0: 1
    else: 2
  else:
    if y > 0: 4
    else: 3

func circleGrouper(imgW, imgH, circleThickness: int, sectorMod=0): PixelGrouper =
  let
    cx = (imgW div 2)
    cy = (imgH div 2)

  func grouper(x, y: int): int =
    let
      ox = x - cx
      oy = y - cy

    let r = sqrt((ox^2 + oy^2).float).int
    let cn = r div circleThickness
    let quad = if sectorMod == 0 or cn mod sectorMod > 0: 0
               else: quadrant(ox, oy)
    result = cn * 5 + quad
  result = grouper

# This takes and returns Image[ColorRGBU] but only uses the r value in the input,
# and sets the output rgbs to the same value because Image[ColorGU] doesn't seem to be well supported
func thresholded(img: Image[ColorRGBU], thresh: uint8): Image[ColorRGBU] =
  result = initImage[ColorRGBU](img.width, img.height)
  for i in 0 .. img.data.high:
      let v: uint8 = if img.data[i].r > thresh: 255
                     else: 0
      result.data[i].r = v
      result.data[i].g = v
      result.data[i].b = v

const
  lightShade = "\u2591"
  midShade = "\u2592"
  darkShade = "\u2593"
  maxVal = 255 * 3
func toShade(cols: seq[ColorRGBU]): string =
  let avgTotal = averageColor(cols).colorValueTotal()
  return if maxVal / avgTotal >= 2.8:
    lightShade
  elif maxVal / avgTotal >= 2:
    midShade
  else:
    darkShade

proc asShadeString(img: Image[ColorRGBU], w, h: int): string =
  let
    bw = img.width div w
    bh = img.height div h
    groupFn = rectsGrouper(img.width, img.height, bw, bh)

  var groups = initTable[int, seq[ColorRGBU]]()
  for j in 0..<img.height:
    let offset = j * img.width
    for i in 0..<img.width:
      let group = groupFn(i, j)
      if not groups.hasKey(group):
        groups[group] = newSeq[ColorRGBU]()
      groups[group].add img.data[offset + i]

  let combined = collect(initTable(groups.len)):
    for g, vs in groups.pairs: { g: toShade(vs) }

  for j in 0..<h:
    for i in 0..<w:
      result &= combined[j * w + i]
    result &= '\n'

when isMainModule:
  let pngIn = if paramCount() > 0: paramStr(1)
              else: "flamingo"
  var img = loadImage[ColorRGBU](fmt"images/{pngIn}.png")
  let brightPixelated = img.apply(rectsGrouper(img.width, img.height, 60, 10), maxBy(colorValueTotal))
  brightPixelated.savePNG(fmt"images/{pngIn}-bright-pixellated.png")
  let sectoredCircles = img.apply(circleGrouper(img.width, img.height, 8, 3), averageColor)
  sectoredCircles.savePNG(fmt"images/{pngIn}-sectored.png")
  echo img.asShadeString(80, 30)
  echo pngIn, " in ", lightShade, midShade, darkShade

  # for cw in @[10, 25, 50]:
  #   for ch in @[10, 25, 50]:
  #     averageChunks(img, cw, ch).savePNG(fmt"images/chunked-{cw}-{ch}")
  # let greyscale = img.filteredGreyscale()
  # var edges = greyscale.convolved(kernelEdgeDetection)
  # edges.savePNG(fmt"images/edges")
  # for thresh in @[20, 50, 200]:
  #   edges.thresholded(thresh.uint8)
  #        .savePNG(fmt"images/edges-{thresh}")
