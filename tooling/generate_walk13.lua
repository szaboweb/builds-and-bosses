-- Generates a deterministic 13-frame, 32x32 directional walk/run block-in.
-- The 32x32 canvas matches the game's authoritative character sprite size
-- (see docs/MOVEMENT_AND_TUI_GUIDE.md).
--
-- Usage:
--   Aseprite.exe -b --script-param config=path/to/walk13.json \
--     --script tooling/generate_walk13.lua
--
-- Config JSON:
--   {
--     "projectName": "hero",
--     "subjectDescription": "pixel adventurer",
--     "parts": [
--       {"name":"head", "role":"head", "x":13, "y":1,
--        "width":6, "height":6, "color":"#F2C078"},
--       {"name":"torso", "role":"torso", "x":11, "y":9,
--        "width":10, "height":7, "color":"#3366FF"},
--       {"name":"arm_left", "role":"arm_left", "x":8, "y":10,
--        "width":2, "height":6, "color":"#F2C078"},
--       {"name":"arm_right", "role":"arm_right", "x":22, "y":10,
--        "width":2, "height":6, "color":"#F2C078"},
--       {"name":"leg_left", "role":"leg_left", "x":11, "y":18,
--        "width":3, "height":14, "color":"#30384A"},
--       {"name":"leg_right", "role":"leg_right", "x":18, "y":18,
--        "width":3, "height":14, "color":"#30384A"}
--     ]
--   }
--
-- Required roles: head, torso, arm_left, arm_right, leg_left, leg_right.
-- All source rectangles must be disjoint, and must keep enough clearance
-- between adjacent parts so pose shifts (walk +-1, run +-2, turn +-1) never
-- make them touch or overlap. Legs must end at y=31.

local configPath = app.params["config"]
if not configPath or configPath == "" then
  error("Missing --script-param config=<json path>")
end

local file = io.open(configPath, "r")
if not file then
  error("Cannot open config file: " .. configPath)
end
local configText = file:read("*a")
file:close()

local ok, config = pcall(json.decode, configText)
if not ok or config == nil then
  error("Config must contain valid JSON: " .. tostring(config))
end
if type(config.projectName) ~= "string"
  or not string.match(config.projectName, "^[%w_-]+$") then
  error("projectName must contain only letters, numbers, '_' or '-'")
end
if type(config.subjectDescription) ~= "string" or config.subjectDescription == "" then
  error("Missing subjectDescription in config")
end
if config.parts == nil then
  error("Missing parts array in config")
end

local requiredRoles = {
  "head", "torso", "arm_left", "arm_right", "leg_left", "leg_right"
}
local byRole = {}
local seenNames = {}
local function parseHex(value, partName)
  if type(value) ~= "string" or not string.match(value, "^#%x%x%x%x%x%x$") then
    error("Part " .. partName .. " color must be #RRGGBB")
  end
  local red = tonumber(string.sub(value, 2, 3), 16)
  local green = tonumber(string.sub(value, 4, 5), 16)
  local blue = tonumber(string.sub(value, 6, 7), 16)
  return app.pixelColor.rgba(red, green, blue, 255)
end

for _, part in ipairs(config.parts) do
  if part == nil or type(part.name) ~= "string"
    or type(part.role) ~= "string" then
    error("Each part needs string name and role fields")
  end
  if seenNames[part.name] then
    error("Duplicate part name: " .. part.name)
  end
  seenNames[part.name] = true
  for _, field in ipairs({ "x", "y", "width", "height" }) do
    if type(part[field]) ~= "number" or part[field] ~= math.floor(part[field]) then
      error("Part " .. part.name .. " field " .. field .. " must be an integer")
    end
  end
  if part.width < 1 or part.height < 1 then
    error("Part " .. part.name .. " dimensions must be positive")
  end
  if part.x < 0 or part.y < 0 or part.x + part.width > 32
    or part.y + part.height > 32 then
    error("Part " .. part.name .. " is outside the 32x32 canvas")
  end
  part.pixelColor = parseHex(part.color, part.name)
  if part.role ~= "head" and part.role ~= "torso"
    and part.role ~= "arm_left" and part.role ~= "arm_right"
    and part.role ~= "leg_left" and part.role ~= "leg_right"
    and part.role ~= "static" then
    error("Unsupported role for part " .. part.name .. ": " .. part.role)
  end
  if part.role ~= "static" then
    if byRole[part.role] then
      error("Only one part per required role is supported: " .. part.role)
    end
    byRole[part.role] = part
  end
end

for _, role in ipairs(requiredRoles) do
  if not byRole[role] then
    error("Missing required part role: " .. role)
  end
end

local leftLeg = byRole.leg_left
local rightLeg = byRole.leg_right
if leftLeg.y + leftLeg.height ~= 32 or rightLeg.y + rightLeg.height ~= 32 then
  error("Both legs must end on canvas row Y=31")
end
if leftLeg.width ~= rightLeg.width or leftLeg.height ~= rightLeg.height then
  error("Left and right legs must have matching dimensions")
end
for _, pair in ipairs({
  { byRole.arm_left, byRole.arm_right, "arms" },
  { leftLeg, rightLeg, "legs" },
}) do
  if pair[1].width ~= pair[2].width or pair[1].height ~= pair[2].height then
    error("Left and right " .. pair[3] .. " must have matching dimensions")
  end
end

local function rectanglesOverlap(a, b)
  return a.x < b.x + b.width and b.x < a.x + a.width
    and a.y < b.y + b.height and b.y < a.y + a.height
end
for firstIndex = 1, #config.parts do
  for secondIndex = firstIndex + 1, #config.parts do
    if rectanglesOverlap(config.parts[firstIndex], config.parts[secondIndex]) then
      error("Source parts must not overlap: " .. config.parts[firstIndex].name
        .. " and " .. config.parts[secondIndex].name)
    end
  end
end

local defaultPoses = {
  { name = "idle_right", kind = "idle", facing = "right" },
  { name = "walk_right_1", kind = "walk", phase = 1, facing = "right" },
  { name = "walk_right_2", kind = "walk", phase = -1, facing = "right" },
  { name = "run_right_1", kind = "run", phase = 1, facing = "right" },
  { name = "run_right_2", kind = "run", phase = -1, facing = "right" },
  { name = "turn_front_1", kind = "turn", phase = 1, facing = "front" },
  { name = "front", kind = "front", facing = "front" },
  { name = "turn_left_1", kind = "turn", phase = 1, facing = "left" },
  { name = "run_left_1", kind = "run", phase = -1, facing = "left" },
  { name = "run_left_2", kind = "run", phase = 1, facing = "left" },
  { name = "walk_left_1", kind = "walk", phase = -1, facing = "left" },
  { name = "walk_left_2", kind = "walk", phase = 1, facing = "left" },
  { name = "idle_left", kind = "idle", facing = "left" },
}

local poses = config.poses or defaultPoses
if #poses ~= 13 then
  error("Pose sequence must contain exactly 13 named poses")
end
for _, pose in ipairs(poses) do
  if type(pose.name) ~= "string" or type(pose.kind) ~= "string"
    or (pose.facing ~= "left" and pose.facing ~= "right" and pose.facing ~= "front") then
    error("Each pose needs a name, kind, and left/right/front facing")
  end
end

local function frontTorsoShape(part)
  local area = part.width * part.height
  for width = math.floor(math.sqrt(area)), 1, -1 do
    if width < part.width and area % width == 0 then
      local height = area / width
      if height > part.height then
        return width, height
      end
    end
  end
  return part.width, part.height
end

local function foldedLegShape(part)
  local area = part.width * part.height
  for width = math.floor(math.sqrt(area)), part.width + 1, -1 do
    if area % width == 0 then
      return width, area / width
    end
  end
  return part.width, part.height
end

local function transformedPart(part, pose)
  local result = {
    x = part.x,
    y = part.y,
    width = part.width,
    height = part.height,
    pixelColor = part.pixelColor,
  }
  local phase = pose.phase or 0

  if pose.kind == "walk" then
    if part.role == "leg_left" then result.x = result.x + phase * 2 end
    if part.role == "leg_right" then result.x = result.x - phase * 2 end
    if part.role == "arm_left" then result.y = result.y - phase * 2 end
    if part.role == "arm_right" then result.y = result.y + phase * 2 end
    if part.role == "head" or part.role == "torso" then
      result.y = math.max(0, result.y + phase)
    end
  elseif pose.kind == "run" then
    if part.role == "leg_left" or part.role == "leg_right" then
      local folded = (part.role == "leg_left" and phase > 0)
        or (part.role == "leg_right" and phase < 0)
      if folded then
        result.width, result.height = foldedLegShape(part)
        result.x = math.floor(part.x + part.width / 2 - result.width / 2)
        result.y = 32 - result.height
      elseif part.role == "leg_left" then
        result.x = result.x + phase * 2
      else
        result.x = result.x - phase * 2
      end
    end
    if part.role == "arm_left" then result.y = result.y - phase end
    if part.role == "arm_right" then result.y = result.y + phase end
    if part.role == "head" or part.role == "torso"
      or part.role == "arm_left" or part.role == "arm_right" then
      result.x = result.x + 1
    end
    if part.role == "head" or part.role == "torso" then
      result.y = math.max(0, result.y - 1)
    end
  elseif pose.kind == "turn" then
    if pose.facing == "front" then
      if part.role == "arm_left" then result.y = result.y - phase end
      if part.role == "arm_right" then result.y = result.y + phase end
    else
      if part.role == "leg_left" then result.x = result.x + phase * 2 end
      if part.role == "leg_right" then result.x = result.x - phase * 2 end
      if part.role == "arm_left" then result.y = result.y - phase * 2 end
      if part.role == "arm_right" then result.y = result.y + phase * 2 end
    end
  elseif pose.kind == "front" then
    -- The front-facing torso is narrow/tall, with limbs placed beside it.
  end

  if pose.kind == "front" or pose.facing == "front" then
    if part.role == "head" then
      result.x = math.floor((32 - result.width) / 2)
    elseif part.role == "torso" then
      result.width, result.height = frontTorsoShape(part)
      result.x = math.floor((32 - result.width) / 2)
    elseif part.role == "arm_left" or part.role == "leg_left" then
      local torso = byRole.torso
      local torsoWidth = frontTorsoShape(torso)
      local torsoX = math.floor((32 - torsoWidth) / 2)
      result.x = torsoX - result.width
    elseif part.role == "arm_right" or part.role == "leg_right" then
      local torso = byRole.torso
      local torsoWidth = frontTorsoShape(torso)
      local torsoX = math.floor((32 - torsoWidth) / 2)
      result.x = torsoX + torsoWidth
    end
  elseif pose.kind == "idle" or pose.kind == "walk" then
    if part.role == "head" or part.role == "torso" then
      result.x = result.x + 1
    end
  end

  if pose.facing == "left" or pose.name == "turn_left_1" then
    result.x = 32 - result.x - result.width
  end
  if result.x < 0 or result.y < 0 or result.x + result.width > 32
    or result.y + result.height > 32 then
    error("Pose " .. pose.name .. " moves part outside the canvas")
  end
  return result
end

local function drawPose(image, pose)
  for _, part in ipairs(config.parts) do
    local rect = transformedPart(part, pose)
    for y = rect.y, rect.y + rect.height - 1 do
      for x = rect.x, rect.x + rect.width - 1 do
        image:drawPixel(x, y, rect.pixelColor)
      end
    end
  end
end

local function countOpaquePixels(image)
  local count = 0
  for y = 0, 31 do
    for x = 0, 31 do
      if app.pixelColor.rgbaA(image:getPixel(x, y)) > 0 then
        count = count + 1
      end
    end
  end
  return count
end

local sprite = Sprite(32, 32, ColorMode.RGB)
sprite.data = config.subjectDescription
local layer = sprite:newLayer()
layer.name = "Character"
local expectedMass = nil

for frameIndex, pose in ipairs(poses) do
  if frameIndex > 1 then
    sprite:newEmptyFrame(frameIndex)
  end
  local image = Image(32, 32, ColorMode.RGB)
  drawPose(image, pose)
  local mass = countOpaquePixels(image)
  if expectedMass == nil then
    expectedMass = mass
  elseif mass ~= expectedMass then
    error("Opaque pixel mass changed in frame " .. frameIndex
      .. " (expected " .. expectedMass .. ", got " .. mass .. ")")
  end
  sprite:newCel(layer, frameIndex, image, Point(0, 0))
end

local tag = sprite:newTag(1, #poses)
tag.name = "walk13"
local outputPath = config.projectName .. "_walk13.aseprite"
sprite:saveAs(outputPath)
print("Saved " .. outputPath .. " with " .. #sprite.frames .. " frames.")
