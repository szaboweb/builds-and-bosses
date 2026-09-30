-- Scaffolds a new character source .aseprite file: 64x64 canvas, one Tag per
-- animation state, frame counts matching docs/MOVEMENT_AND_TUI_GUIDE.md.
--
-- Usage:
--   Aseprite.exe -b --script-param classId=fighter --script-param outputDir=<dir>
--     [--script-param baseImage=<png path>] --script tooling/scaffold_character.lua

local CANVAS = 64

local classId = app.params["classId"]
if not classId or classId == "" then
  error("Missing --script-param classId=<name>")
end

local outputDir = app.params["outputDir"]
if not outputDir or outputDir == "" then
  error("Missing --script-param outputDir=<path>")
end

local baseImage = app.params["baseImage"]

local states = {
  { name = "idle",   frames = 4 },
  { name = "run",    frames = 6 },
  { name = "jump",   frames = 4 },
  { name = "fall",   frames = 2 },
  { name = "attack", frames = 6 },
  { name = "block",  frames = 4 },
  { name = "cast",   frames = 6 },
  { name = "hit",    frames = 2 },
  { name = "dodge",  frames = 5 },
  { name = "death",  frames = 6 },
}

local spr
if baseImage and baseImage ~= "" then
  spr = Sprite{ fromFile = baseImage, oneFrame = true }
  if spr.width ~= CANVAS or spr.height ~= CANVAS then
    error("baseImage must be exactly " .. CANVAS .. "x" .. CANVAS .. " pixels")
  end
else
  spr = Sprite(CANVAS, CANVAS, ColorMode.RGB)
end

local totalFrames = 0
for _, s in ipairs(states) do totalFrames = totalFrames + s.frames end

-- Duplicate the last frame as a placeholder until every animation step has one.
while #spr.frames < totalFrames do
  spr:newFrame(spr.frames[#spr.frames])
end

local nextFrame = 1
for _, s in ipairs(states) do
  local tag = spr:newTag(nextFrame, nextFrame + s.frames - 1)
  tag.name = s.name
  nextFrame = nextFrame + s.frames
end

local outputPath = outputDir .. "/source.aseprite"
spr:saveAs(outputPath)
print("Saved " .. outputPath .. " with " .. #spr.frames .. " frames and " .. #spr.tags .. " tags.")
