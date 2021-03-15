import strformat, math, sequtils
import imageman
import imageman/kernels

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

func averageChunks(img: Image[ColorRGBU], chunkW, chunkH: int): Image[ColorRGBU] =
  let 
    widthInChunks = ceil(img.width / chunkW).int
    heightInChunks = ceil(img.height / chunkH).int
  var chunks: seq[seq[ColorRGBU]] = @[]
  for n in 0 ..< widthInChunks * heightInChunks:
    chunks.add newSeq[ColorRGBU]()

  for j in 0 ..< img.height:
    let cy = floor((j / img.height) * (img.height div chunkH).float).int
    for i in 0 ..< img.width:
      let col = img.data[j * img.width + i]
      let cx = floor((i / img.width) * (img.width div chunkW).float).int
      chunks[cy * widthInChunks + cx].add col
  let averages = chunks.mapIt(it.averageColor)
  result = initImage[ColorRGBU](img.width, img.height)
  for j in 0 ..< img.height:
    let cy = floor((j / img.height) * (img.height div chunkH).float).int
    for i in 0 ..< img.width:
      let cx = floor((i / img.width) * (img.width div chunkW).float).int
      result.data[j * img.width + i] = averages[cy * widthInChunks + cx]

when isMainModule:
  var img = loadImage[ColorRGBU]("images/humming-bird.png")
  for cw in @[10, 25, 50]:
    for ch in @[10, 25, 50]:
      averageChunks(img, cw, ch).savePNG(fmt"images/chunked-{cw}-{ch}")
  let greyscale = img.filteredGreyscale()
  var edges = greyscale.convolved(kernelEdgeDetection)
  edges.savePNG(fmt"images/edges")
  for thresh in @[20, 50, 200]:
    edges.thresholded(thresh.uint8)
         .savePNG(fmt"images/edges-{thresh}")
