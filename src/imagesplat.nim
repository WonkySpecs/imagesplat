import strformat, math, sequtils, tables, sugar, random
import imageman
import imageman/kernels

randomize()

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

func maxBy(f: proc(c: ColorRGBU): int): ColorCombiner =
  result = proc(cols: seq[ColorRGBU]): ColorRGBU =
    cols[map[ColorRGBU, int](cols, f).maxIndex]

func minBy(f: proc(c: ColorRGBU): int): ColorCombiner =
  result = proc(cols: seq[ColorRGBU]): ColorRGBU =
    cols[map[ColorRGBU, int](cols, f).minIndex]

func absMax(): ColorCombiner =
  maxBy(proc(c: ColorRGBU): int = c.r.int + c.g.int + c.b.int)

func absMin(): ColorCombiner =
  minBy(proc(c: ColorRGBU): int = c.r.int + c.g.int + c.b.int)

func rectsGrouper(imgW, imgH, rectW, rectH: int): PixelGrouper =
  let
    widthInRects = ceil(imgW / rectW)
    heightInRects = ceil(imgH / rectH)

  func grouper(x, y: int): int =
    let rx = floor((x / imgW) * widthInRects).int
    let ry = floor((y / imgH) * heightInRects).int
    result = ry * widthInRects.int + rx
  result = grouper

func quadrant(x, y: int): int =
  result = if x > 0:
    if y > 0: 1
    else: 2
  else:
    if y > 0: 4
    else: 3

func circleGrouper(imgW, imgH, circleThickness: int): PixelGrouper =
  let
    cx = (imgW div 2)
    cy = (imgH div 2)

  func grouper(x, y: int): int =
    let
      ox = x - cx
      oy = y - cy

    let r = sqrt((ox^2 + oy^2).float).int
    let cn = r div circleThickness
    let quad = if cn mod 2 == 0: 0
               else: quadrant(ox, oy)
    result = cn * 5 + quad

  result = grouper

when isMainModule:
  var img = loadImage[ColorRGBU]("images/flamingo.png")
  #let res = img.apply(rectsGrouper(img.width, img.height, 60, 10), absMax())
  let res = img.apply(circleGrouper(img.width, img.height, 8), averageColor)
  res.savePNG("images/test")

  # for cw in @[10, 25, 50]:
  #   for ch in @[10, 25, 50]:
  #     averageChunks(img, cw, ch).savePNG(fmt"images/chunked-{cw}-{ch}")
  # let greyscale = img.filteredGreyscale()
  # var edges = greyscale.convolved(kernelEdgeDetection)
  # edges.savePNG(fmt"images/edges")
  # for thresh in @[20, 50, 200]:
  #   edges.thresholded(thresh.uint8)
  #        .savePNG(fmt"images/edges-{thresh}")
