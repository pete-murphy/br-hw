import Bun from "bun"
import "mapbox-gl"
import chroma from "chroma-js"

// traverse the JSON object and replace HSL/HSLA color strings
function walkAndReplace(
  obj: any,
  replaceFn: (colorStr: string) => string
): any {
  if (Array.isArray(obj)) {
    return obj.map((item) => walkAndReplace(item, replaceFn))
  } else if (typeof obj === "object" && obj !== null) {
    const result: any = {}
    for (const [key, value] of Object.entries(obj)) {
      result[key] = walkAndReplace(value, replaceFn)
    }
    return result
  } else if (typeof obj === "string" && /hsla?\(/.test(obj)) {
    return replaceFn(obj)
  } else {
    return obj
  }
}

function remapPaint(
  paint: mapboxgl.LayerSpecification["paint"],
  colorList: string[]
): mapboxgl.LayerSpecification["paint"] {
  return walkAndReplace(paint, (colorStr: string) => {
    const color = Bun.color(colorStr, "hex")
    if (color) {
      return findClosestColor(color, colorList)
    } else {
      return colorStr
    }
  })
}

async function main() {
  const filePath = Bun.argv.at(2)
  if (!filePath) {
    console.log("Usage: bun run index.ts path/to/style.json")
    return
  }

  const styleFile = Bun.file(filePath)
  const style: mapboxgl.StyleSpecification = await styleFile.json()
  let newLayers = []
  for (const layer of style.layers) {
    let newLayer = { ...layer }
    const id = layer.id
    const type = layer.type
    const group = (layer.metadata as any)?.["mapbox:group"]
    const featureComponent = (layer.metadata as any)?.[
      "mapbox:featureComponent"
    ]
    const paint = layer.paint

    if (type == "symbol") {
      newLayer.paint = remapPaint(paint, greys)
      newLayers.push(newLayer)
      continue
    }

    if (group == "Land & water, water") {
      newLayer.paint = remapPaint(paint, towerGreys)
      newLayers.push(newLayer)
      continue
    }

    if (group == "Land & water, land") {
      newLayer.paint = remapPaint(paint, pampas)
      newLayers.push(newLayer)
      continue
    }

    if (featureComponent == "walking-cycling") {
      newLayer.paint = remapPaint(paint, greys)
      newLayers.push(newLayer)
      continue
    }

    if (featureComponent == "transit") {
      newLayer.paint = remapPaint(paint, greys)
      newLayers.push(newLayer)
      continue
    }

    if (featureComponent == "road") {
      newLayer.paint = remapPaint(paint, greys)
      newLayers.push(newLayer)
      continue
    }

    newLayer.paint = remapPaint(paint, greys)
    newLayers.push(newLayer)
  }

  const newStyle = { ...style, layers: newLayers }

  const newJSONString = JSON.stringify(newStyle, null, 2)
  const updatedJSONString = replaceFontsInJSONString(newJSONString)

  console.log(updatedJSONString)
}

main().catch(console.error)

const colors = {
  "pampas-50": "#f8f6f4",
  "pampas-100": "#efeae5",
  "pampas-200": "#ded4ca",
  "pampas-300": "#c9b7a8",
  "pampas-400": "#b29685",
  "pampas-500": "#a37f6c",
  "pampas-600": "#956f61",
  "pampas-700": "#7d5b51",
  "pampas-800": "#664c46",
  "pampas-900": "#543f3a",
  "pampas-950": "#2c201e",

  "tower-gray-50": "#f6f9f9",
  "tower-gray-100": "#edf0f1",
  "tower-gray-200": "#d7dfe0",
  "tower-gray-300": "#a6b8bb",
  "tower-gray-400": "#8ba2a5",
  "tower-gray-500": "#6c878b",
  "tower-gray-600": "#576e72",
  "tower-gray-700": "#47595d",
  "tower-gray-800": "#3d4c4f",
  "tower-gray-900": "#364244",
  "tower-gray-950": "#242b2d",

  white: "#ffffff",
  "grey-100": "#f7f7f7",
  "grey-200": "#efefef",
  "grey-300": "#dbdbdb",
  "grey-400": "#9b9b9b",
  "grey-500": "#666666",
  "grey-600": "#333333",
  "grey-700": "#222222",
  "grey-800": "#111111",
  "accent-dark": "#c75724",
  accent: "#e15a1d",
}

const greys = Object.entries(colors)
  .filter(([name]) => name.includes("grey"))
  .map(([_, color]) => color)

const pampas = Object.entries(colors)
  .filter(([name]) => name.includes("pampas"))
  .map(([_, color]) => color)

const towerGreys = Object.entries(colors)
  .filter(([name]) => name.includes("tower-gray"))
  .map(([_, color]) => color)

function findClosestColor(sourceColor: string, colorList: string[]): string {
  let minDistance = Infinity
  let closestColor = null

  colorList.forEach((color: string) => {
    const distance = chroma.distance(sourceColor, color, "lab")
    if (distance < minDistance) {
      minDistance = distance
      closestColor = color
    }
  })

  return closestColor!
}

const fontsToReplace = [
  "DIN Pro Italic",
  "DIN Pro Bold",
  "DIN Pro Medium",
  "DIN Pro Regular",
] as const

function replaceFontsInJSONString(string: string): string {
  let updatedString = string
  fontsToReplace.forEach((font) => {
    if (font == "DIN Pro Italic") {
      updatedString = updatedString.replace(
        new RegExp(font, "g"),
        "GT Ultra Trial Regular Italic"
      )
    }
    if (font == "DIN Pro Bold") {
      updatedString = updatedString.replace(
        new RegExp(font, "g"),
        "GT Ultra Trial Bold"
      )
    }
    if (font == "DIN Pro Medium") {
      updatedString = updatedString.replace(
        new RegExp(font, "g"),
        "GT Ultra Trial Regular"
      )
    }
    if (font == "DIN Pro Regular") {
      updatedString = updatedString.replace(
        new RegExp(font, "g"),
        "GT Ultra Trial Regular"
      )
    }
  })
  return updatedString
}
