--!strict

local ParseObj = require(script:WaitForChild("ParseObj"));

local Player = game.Players.LocalPlayer;
local PlayerGui: PlayerGui = Player:WaitForChild("PlayerGui");
local Canvas: Frame = PlayerGui:WaitForChild("Canvas"):WaitForChild("Inner") :: Frame;

local Obj = game:GetService("ReplicatedStorage"):WaitForChild("Common"):WaitForChild("FpsTest.obj") :: ModuleScript;
local Sus = ParseObj(Obj);

local WIDTH, HEIGHT = 1920, 1080;
local s1, s2 = WIDTH/2, HEIGHT/2;
local LINES = true; -- Draw frames to connect lines (true) or draw each pixel (false) each pixel lets you have variable resolution

local CAMERA_SCALE = 1.5;
local OBJECT_SCALE = 0.3;

local FOV = OBJECT_SCALE;

local CanvasAbsoluteWidth, CanvasAbsoluteHeight = Canvas.AbsoluteSize.X, Canvas.AbsoluteSize.Y;
WIDTH, HEIGHT = math.clamp(WIDTH, 0, CanvasAbsoluteWidth), math.clamp(HEIGHT, 0, CanvasAbsoluteHeight);

local PIXEL_SIZE_X, PIXEL_SIZE_Y = CanvasAbsoluteWidth/WIDTH, CanvasAbsoluteHeight / HEIGHT;

local PixelCache: { [number]: Frame } = {};
local PixelCacheLen = 0;
local Guis: { [number]: Frame }  = {};
local UsedThisFrame: { [number]: number } = {};
local UsedThisFrameLen = 0;

local FAR = UDim2.fromScale(100000, 100000);
local WHITE = Color3.new(1, 1, 1);

local fromOffset = UDim2.fromOffset;
local PixelSizeRef = fromOffset(PIXEL_SIZE_X, PIXEL_SIZE_Y);
local Center = Vector2.new(0.5, 0.5);
local function GetPixel(x:number, y:number, force:boolean?): (Frame?, number?)
	if (not force and (x > WIDTH or y > HEIGHT or x <= 0 or y <= 0)) then return nil; end;
	if (force) then
		if (PixelCacheLen > 0) then
			local Pixel = PixelCache[PixelCacheLen];
			Pixel.Position = fromOffset(
				PIXEL_SIZE_X * (x - 1),
				PIXEL_SIZE_Y * (y - 1)
			);
			Guis[#Guis + 1] = Pixel;
			PixelCache[PixelCacheLen] = nil;
			PixelCacheLen -= 1;
			return Guis[#Guis], #Guis;
		else
			local index = #Guis + 1;
			Guis[index] = Instance.new("Frame");
			Guis[index].Size = PixelSizeRef;
			Guis[index].BorderSizePixel = 0;
			Guis[index].BackgroundColor3 = Color3.new(0, 0, 0);
			Guis[index].Position = fromOffset(PIXEL_SIZE_X * (x - 1), PIXEL_SIZE_Y * (y - 1));
			Guis[index].Parent = Canvas;
			if (LINES) then
				Guis[index].BackgroundColor3 = WHITE;
				Guis[index].AnchorPoint = Center;
			end
			return Guis[index], index;
		end
	end

	local Gui = Guis[x + WIDTH * y];
	if (Gui) then
		return Gui;
	else
		if (PixelCacheLen > 0) then
			local Pixel = PixelCache[PixelCacheLen];
			Pixel.Position = fromOffset(
				PIXEL_SIZE_X * (x - 1),
				PIXEL_SIZE_Y * (y - 1)
			);
			Guis[x + WIDTH * y] = Pixel;
			PixelCache[PixelCacheLen] = nil;
			PixelCacheLen -= 1;
		else
			local index = x + WIDTH * y;
			Guis[index] = Instance.new("Frame");
			Guis[index].Size = fromOffset(PIXEL_SIZE_X, PIXEL_SIZE_Y);
			Guis[index].BorderSizePixel = 0;
			Guis[index].BackgroundColor3 = Color3.new(0, 0, 0);
			Guis[index].Position = fromOffset(PIXEL_SIZE_X * (x - 1), PIXEL_SIZE_Y * (y - 1));
			Guis[index].Parent = Canvas;
		end
	end
	return Guis[x + WIDTH * y], x + WIDTH * y;
end

local function DisposePixel(Pixel: Frame, x:number, y:number)
	Guis[x + WIDTH * y] = nil;
	PixelCache[PixelCacheLen + 1] = Pixel;
	PixelCacheLen += 1;
	Pixel.Position = FAR;
end

local function IfExistsDispose(x:number, y:number)
	debug.profilebegin("If Exists Dipose Pixel");
	if (Guis[x + WIDTH * y]) then
		PixelCache[PixelCacheLen + 1] = Guis[x + WIDTH * y];
		PixelCacheLen += 1;
		Guis[x + WIDTH * y] = nil;
	end
	debug.profileend();
end

local function InitCanvas(Width: number, Height: number, CanvasAbsoluteWidth: number, CanvasAbsoluteHeight: number, Parent: Instance): { [number]: Frame }
	local Guis: { [number]: Frame } = table.create(Width * Height);
	return Guis;
end

Guis = InitCanvas(WIDTH, HEIGHT, Canvas.AbsoluteSize.X, Canvas.AbsoluteSize.Y, Canvas);
local PCache: {[Frame]: {Rotation: number, Position: UDim2, Size: UDim2}} = {};

local deg, atan2, sqrt = math.deg, math.atan2, math.sqrt;
local function DrawLineN(x0:number, x1:number, y0:number, y1:number)
	if (not LINES) then
		local dx = math.abs(x1 - x0);
		local sx = if x0 < x1 then 1 else -1;
		local dy = -math.abs(y1 - y0);
		local sy = if y0 < y1 then 1 else -1;
		local err = dx + dy;
		while (true) do
			local Pixel = GetPixel(x0, y0);
			if (Pixel) then
				UsedThisFrameLen += 1;
				UsedThisFrame[UsedThisFrameLen] = x0 + WIDTH * y0;
				Pixel.BackgroundColor3 = WHITE;
			end
			if (x0 == x1 and y0 == y1) then break; end;
			local e2 = 2 * err;
			if (e2 >= dy) then
				err += dy;
				x0 += sx;
			end
			if (e2 <= dx) then
				err += dx;
				y0 += sy;
			end
		end
	else
		if (
			((x0 > WIDTH and x1 > WIDTH) and (y0 > HEIGHT and y1 > HEIGHT))
				or
			((x0 < 1 and x1 < 1) and y0 < 1 and y1 < 1)
		) then return; end;
		local Pixel, ForcedIndex = GetPixel(x0, y0, true);
		if (Pixel) then
			local absX1 = PIXEL_SIZE_X * (x0 - 1);
			local absX2 = PIXEL_SIZE_X * (x1 - 1);

			local absY1 = PIXEL_SIZE_Y * (y0 - 1);
			local absY2 = PIXEL_SIZE_Y * (y1 - 1);

			local D = sqrt((y1 - y0)^2 + (x1 - x0)^2);
			UsedThisFrameLen += 1;
			UsedThisFrame[UsedThisFrameLen] = ForcedIndex or x0 + WIDTH * y0;

			local NewSize = fromOffset(D, PIXEL_SIZE_Y);
			local NewPosition = fromOffset(
				((absX1) + (absX2)) / 2,
				((absY1) + (absY2)) / 2
			);
			local NewRotation = deg(atan2(y1 - y0, x1 - x0));
			if (PCache[Pixel]) then
				if (NewSize ~= PCache[Pixel].Size) then
					Pixel.Size = NewSize;
					PCache[Pixel].Size = NewSize;
				end
				if (NewPosition ~= PCache[Pixel].Position) then
					Pixel.Position = NewPosition;
					PCache[Pixel].Position = NewPosition;
				end
				if (NewRotation ~= PCache[Pixel].Rotation) then
					Pixel.Rotation = NewRotation;
					PCache[Pixel].Rotation = NewRotation;
				end
			else
				PCache[Pixel] = {
					Position = NewPosition,
					Rotation = NewRotation,
					Size = NewSize
				};
				Pixel.Position = NewPosition;
				Pixel.Rotation = NewRotation;
				Pixel.Size = NewSize;
			end
			--Pixel.Position = fromOffset(
			--	((absX1) + (absX2)) / 2,
			--	((absY1) + (absY2)) / 2
			--);
			--Pixel.Rotation = deg(atan2(y1 - y0, x1 - x0));
		end
	end
end

local function DrawLine(A: Vector2, B: Vector2)
	DrawLineN(A.X, B.X, A.Y, B.Y);
end

local function DrawTriangle(A:Vector2, B:Vector2, C:Vector2)
	DrawLine(A, B);
	DrawLine(B, C);
	DrawLine(C, A);
end

local function Clear()
	debug.profilebegin("Clear Canvas");
	for _, PixelIndex in pairs(UsedThisFrame) do
		if (Guis[PixelIndex]) then
			PixelCacheLen += 1;
			PixelCache[PixelCacheLen] = Guis[PixelIndex];
			Guis[PixelIndex].Position = FAR;
			Guis[PixelIndex] = nil;
		end
	end
	UsedThisFrameLen = 0;
	table.clear(UsedThisFrame);
	debug.profileend();
end

local Camera = workspace.CurrentCamera :: Camera;

local NewVector3 = Vector3.new;
local NewVector2 = Vector2.new;

local function Multiply3x3Matrix(A: {Vector3}, B:{Vector3})
	local Res = {
		A[1].X * B[1].X + A[1].Y * B[2].X + A[1].Z * B[3].X,    A[1].X * B[1].Y + A[1].Y * B[2].Y + A[1].Z * B[3].Y,    A[1].X * B[1].Z + A[1].Y * B[2].Z + A[1].Z * B[3].Z,
		A[2].X * B[1].X + A[2].Y * B[2].X + A[2].Z * B[3].X,    A[2].X * B[1].Y + A[2].Y * B[2].Y + A[2].Z * B[3].Y,    A[2].X * B[1].Z + A[2].Y * B[2].Z + A[2].Z * B[3].Z,
		A[3].X * B[1].X + A[3].Y * B[2].X + A[3].Z * B[3].X,    A[3].X * B[1].Y + A[3].Y * B[2].Y + A[3].Z * B[3].Y,    A[3].X * B[1].Z + A[3].Y * B[2].Z + A[3].Z * B[3].Z,

	};
	return { NewVector3(Res[1], Res[2], Res[3]), NewVector3(Res[4], Res[5], Res[6]), NewVector3(Res[7], Res[8], Res[9]) };
end


local function Multiply3x1Matrix(A: {Vector3}, B: Vector3): Vector3
	return NewVector3(
		(A[1].X * B.X) + (A[1].Y * B.Y) + (A[1].Z * B.Z),
		(A[2].X * B.X) + (A[2].Y * B.Y) + (A[2].Z * B.Z),
		(A[3].X * B.X) + (A[3].Y * B.Y) + (A[3].Z * B.Z)
	);
end

local CameraCFrame = CFrame.new(0, 0, -100);

--[[
Rotation:
	Z: / -> | -> \
	X: Up and down
	Y: Left and Right
Translation:
	X: Left right
	Y: Up down
	Z: Forward back
]]

local cX, cY, cZ = 0, 0, 0;
local Ox, Oy, Oz = 0, 0, 0;

local sin , cos = math.sin, math.cos;
local S = Vector2.new(WIDTH, HEIGHT);
local C1, C2, C3 = Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1);
local function Project3DPoint(A: Vector3): (number, number)
	local R = NewVector3(1, 1, (A - NewVector3(cX, cY, cZ)).Magnitude);
	local D = Multiply3x1Matrix(Multiply3x3Matrix(Multiply3x3Matrix({
		C1,
		NewVector3(0, cos(Ox), sin(Ox)),
		NewVector3(0, -sin(Ox), cos(Ox))
	}, {
		NewVector3(cos(Oy), 0, -sin(Oy)),
		C2,
		NewVector3(sin(Oy), 0, cos(Oy))
	}), {
		NewVector3(cos(Oz), sin(Oz), 0),
		NewVector3(-sin(Oz), cos(Oz), 0),
		C3
	}), NewVector3(
		A.X - cX,
		A.Y - cY,
		A.Z - cZ
	));
	local bx = (D.X * 200) / (D.Z * FOV) + R.Z --/ (D.Z/R.X) * R.Z
	local by = (D.Y * 200) / (D.Z * FOV) + R.Z--/ (D.Z/R.Y) * R.Z
	bx += WIDTH * 2;
	by += HEIGHT * 2;
	return math.floor(bx), math.floor(by);
end

local AveragePos = Vector3.new();
local n = 0;
for _, Vert in ipairs(Sus.Objects[#Sus.Objects].Verts) do
	AveragePos += Vert;
	n += 1;
end
AveragePos /= n;

local Inv = Vector3.new(1, -1, 1);
local TopObject = Sus.Objects[#Sus.Objects];
local Delta = task.wait();
while true do
	debug.profilebegin("Main :: Loop");
	Clear();

	cX, cY, cZ = -CameraCFrame.X, CameraCFrame.Y, CameraCFrame.Z;
	-- (Canvas.Parent:WaitForChild("Dubug") :: TextLabel).Text = "X: " .. cX .. " Y: " .. cY .. " Z: " .. cZ .. "O: " .. Ox .. " " .. Oy .. " " .. Oz;
	local CPos = Vector3.new(cX, cY, cZ);
	Ox, Oy, Oz = CameraCFrame:ToWorldSpace(CFrame.new()):ToOrientation();
	Oy = math.pi*2-Oy;
	Ox = math.pi*2-Ox;
	-- if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then
	-- 	Ox += 1 * Delta;
	-- end

	for _, Face in ipairs(TopObject.Faces) do
		debug.profilebegin("Draw Face");
		local VI1, VNI1 = Face[1].X, Face[1].Z;
		local VI2, VNI2 = Face[2].X, Face[2].Z;
		local VI3, VNI3 = Face[3].X, Face[3].Z;
		local V1, V2, V3 = TopObject.Verts[VI1], TopObject.Verts[VI2], TopObject.Verts[VI3];
		local VN1, VN2, VN3 = TopObject.Normals[VNI1], TopObject.Normals[VNI2], TopObject.Normals[VNI3];

		if (not V1 or not V2 or not V3 or not VN1) then print(VNI1, VN1, #TopObject.Normals) break; end;
		local Dis = VN1:Dot((V1 - CPos).Unit);
		local Dis2 = VN2:Dot((V2 - CPos).Unit);
		local Dis3 = VN3:Dot((V3 - CPos).Unit);
		if (Dis > 0.33 and Dis2 > 0.33 and Dis3 > 0.33) then
			continue;
		end

		V1 *= Inv;
		V2 *= Inv;
		V3 *= Inv;


		local VS1x, VS1y = Project3DPoint(V1);
		local VS2x, VS2y = Project3DPoint(V2);
		local VS3x, VS3y = Project3DPoint(V3);
		VS1x, VS1y = VS1x * OBJECT_SCALE, VS1y * OBJECT_SCALE;
		VS2x, VS2y = VS2x * OBJECT_SCALE, VS2y * OBJECT_SCALE;
		VS3x, VS3y = VS3x * OBJECT_SCALE, VS3y * OBJECT_SCALE;

		if (VS1x < 0 and VS1y < 0 and VS2x < 0 and VS2y < 0 and VS3y < 0 and VS3x < 0) then
			continue;
		end
		if (VS1x > WIDTH and VS1y > HEIGHT and VS2x > WIDTH and VS2y > HEIGHT and VS3y > HEIGHT and VS3x > WIDTH) then
			continue;
		end

		DrawTriangle(
			NewVector2(VS1x, VS1y),
			NewVector2(VS2x, VS2y),
			NewVector2(VS3x, VS3y)
		);
		debug.profileend();
	end

	CameraCFrame = Camera.CFrame;

	debug.profileend();
	Delta = game:GetService("RunService").Heartbeat:Wait();
end

