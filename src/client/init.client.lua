--!strict
do
	local ParseObj = require(script:WaitForChild("ParseObj"));

	local Player = game.Players.LocalPlayer;
	local PlayerGui: PlayerGui = Player:WaitForChild("PlayerGui");
	local Canvas: Frame = PlayerGui:WaitForChild("Canvas"):WaitForChild("Inner") :: Frame;
	local Canvas3D: ViewportFrame = workspace :: any; --PlayerGui:WaitForChild("Canvas"):WaitForChild("3DInner") :: ViewportFrame;
	
	local Obj = game:GetService("ReplicatedStorage"):WaitForChild("Common"):WaitForChild("Fox.obj") :: ModuleScript;
	local Sus = ParseObj(Obj);

	local CanvasAbsoluteWidth, CanvasAbsoluteHeight = Canvas.AbsoluteSize.X, Canvas.AbsoluteSize.Y;
	
	local _3DTOGGLE = false; -- Wether it should use a flat plane of parts inside a viewport or gui frames.
	local LINES = true; -- Draw frames to connect lines (true) or draw each pixel (false) each pixel lets you have variable resolution
	local WIDTH, HEIGHT = if not LINES or _3DTOGGLE then 200 else CanvasAbsoluteWidth, if not LINES or _3DTOGGLE then 200 else CanvasAbsoluteHeight;
	local s1, s2 = WIDTH/2, HEIGHT/2;

	local CAMERA_SCALE = 1.5;
	local OBJECT_SCALE = 0.3;

	local FOV = 0.3;

	WIDTH, HEIGHT = math.clamp(WIDTH, 0, CanvasAbsoluteWidth), math.clamp(HEIGHT, 0, CanvasAbsoluteHeight);

	local PIXEL_SIZE_X, PIXEL_SIZE_Y =
		if not _3DTOGGLE then CanvasAbsoluteWidth/WIDTH else 1,
		if not _3DTOGGLE then CanvasAbsoluteHeight/HEIGHT else 1;

	local PixelCache: { [number]: Frame } = {};
	local PixelCacheLen = 0;
	local PartsCache: { [number]: Part } = {};
	local PartsCacheLen = 0;
	local Parts: { [number]: Part } = {};
	local Guis: { [number]: Frame }  = {};
	local UsedThisFrame: { [number]: number } = {};
	local UsedThisFrameLen = 0;
	
	if (_3DTOGGLE) then
		xpcall(function()
			assert(Canvas3D.ClassName == "ViewportFrame");
			local RealCamera = Instance.new("Camera") :: Camera;
			Canvas3D.CurrentCamera = RealCamera;
			RealCamera.CFrame = CFrame.new(0, 0, -1000);
			RealCamera.Parent = Canvas3D;
		end, function()
			print("Error setting some properties.");
		end)
	end
	
	local FAR = UDim2.fromScale(1e6, 1e6);
	local FAR_3D = Vector3.new(1e6, 1e6);
	local WHITE = Color3.new(1, 1, 1);

	local fromOffset = UDim2.fromOffset;
	local NewVector3 = Vector3.new;
	local NewVector2 = Vector2.new;
	
	local PixelSizeRef = fromOffset(PIXEL_SIZE_X, PIXEL_SIZE_Y);
	local PixelSizeRef3D = NewVector3(PIXEL_SIZE_X, PIXEL_SIZE_Y, 1);
	local Center = Vector2.new(0.5, 0.5);
	local function GetPixel(x:number, y:number, force:boolean?): (Frame?|BasePart?, number?)
		if (_3DTOGGLE) then
			if (PartsCacheLen > 0) then
				local Part = PartsCache[PartsCacheLen];
				Part.Position = NewVector3(
					PIXEL_SIZE_X * (x - 1),
					PIXEL_SIZE_Y * (y - 1)
				);
				Parts[#Parts + 1] = Part;
				PartsCache[PartsCacheLen] = nil;
				PartsCacheLen-= 1;
				return Parts[#Parts], #Parts;
			else
				local index = #Parts+ 1;
				Parts[index] = Instance.new("Part");
				Parts[index].Size = PixelSizeRef3D;
				Parts[index].Color = Color3.new(0, 0, 0);
				Parts[index].Position = NewVector3(PIXEL_SIZE_X * (x - 1), PIXEL_SIZE_Y * (y - 1), 0);
				Parts[index].Parent = Canvas3D;
				return Parts[index], index;
			end
		end
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
		if (_3DTOGGLE) then
			if (
				((x0 > WIDTH and x1 > WIDTH) and (y0 > HEIGHT and y1 > HEIGHT))
					or
					((x0 < 1 and x1 < 1) and y0 < 1 and y1 < 1)
				) then return; end;
			local PartR, ForcedIndex = GetPixel(x0, y0, true);
			local Part = PartR :: BasePart?;
			if (Part) then
				local absX1 = PIXEL_SIZE_X * (x0 - 1);
				local absX2 = PIXEL_SIZE_X * (x1 - 1);

				local absY1 = PIXEL_SIZE_Y * -(y0 - 1);
				local absY2 = PIXEL_SIZE_Y * -(y1 - 1);

				local D = sqrt((y1 - y0)^2 + (x1 - x0)^2);
				UsedThisFrameLen += 1;
				UsedThisFrame[UsedThisFrameLen] = ForcedIndex or x0 + WIDTH * y0;

				Part.Size = NewVector3(D, PIXEL_SIZE_Y, 1);
				Part.Position = NewVector3( --TODO(deter): Make these one cframe call
					((absX1) + (absX2)) / 2,
					1,
					((absY1) + (absY2)) / 2
				);
				Part.Orientation = NewVector3(0, deg(atan2(y1 - y0, x1 - x0))); --deg(atan2(y1 - y0, x1 - x0));
			end
			return;
		end
		if (not LINES) then
			local dx = math.abs(x1 - x0);
			local sx = if x0 < x1 then 1 else -1;
			local dy = -math.abs(y1 - y0);
			local sy = if y0 < y1 then 1 else -1;
			local err = dx + dy;
			while (true) do
				local Pixel = GetPixel(x0, y0) :: Frame;
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
			local PixelR, ForcedIndex = GetPixel(x0, y0, true);
			local Pixel = PixelR :: Frame?;
			if (Pixel) then
				local absX1 = PIXEL_SIZE_X * (x0 - 1);
				local absX2 = PIXEL_SIZE_X * (x1 - 1);

				local absY1 = PIXEL_SIZE_Y * (y0 - 1);
				local absY2 = PIXEL_SIZE_Y * (y1 - 1);

				local D = sqrt((y1 - y0)^2 + (x1 - x0)^2);
				UsedThisFrameLen += 1;
				UsedThisFrame[UsedThisFrameLen] = ForcedIndex or x0 + WIDTH * y0;

				Pixel.Size = fromOffset(D, 1);
				Pixel.Position = fromOffset(
					((absX1) + (absX2)) / 2,
					((absY1) + (absY2)) / 2
				);
				Pixel.Rotation = deg(atan2(y1 - y0, x1 - x0)); --deg(atan2(y1 - y0, x1 - x0));
			end
		end
	end
	local floor = math.floor;
	local function FillTriangleN(x0:number, y0:number, x1:number, y1:number, x2:number, y2:number)

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
		if (_3DTOGGLE) then
			for i = UsedThisFrameLen, 1, -1 do
				local PartIndex = UsedThisFrame[i];
				if (Parts[PartIndex]) then
					PartsCacheLen += 1;
					PartsCache[PartsCacheLen] = Parts[PartIndex];
					Parts[PartIndex].Position = FAR_3D;
					Parts[PartIndex] = nil;
				end
			end
			--for _, PartIndex in ipairs(UsedThisFrame) do
			--end
		else
			for _, PixelIndex in ipairs(UsedThisFrame) do
				if (Guis[PixelIndex]) then
					PixelCacheLen += 1;
					PixelCache[PixelCacheLen] = Guis[PixelIndex];
					Guis[PixelIndex].Position = FAR;
					Guis[PixelIndex] = nil;
				end
			end
		end
		UsedThisFrameLen = 0;
		table.clear(UsedThisFrame);
		debug.profileend();
	end

	local Camera = workspace.CurrentCamera :: Camera;

	local function Multiply3x3Matrix(A: {{number}}, B:{{number}}):{{number}}
		local Res = {
			A[1][1] * B[1][1] + A[1][2] * B[2][1] + A[1][3] * B[3][1],    A[1][1] * B[1][2] + A[1][2] * B[2][2] + A[1][3] * B[3][2],    A[1][1] * B[1][3] + A[1][2] * B[2][3] + A[1][3] * B[3][3],
			A[2][1] * B[1][1] + A[2][2] * B[2][1] + A[2][3] * B[3][1],    A[2][1] * B[1][2] + A[2][2] * B[2][2] + A[2][3] * B[3][2],    A[2][1] * B[1][3] + A[2][2] * B[2][3] + A[2][3] * B[3][3],
			A[3][1] * B[1][1] + A[3][2] * B[2][1] + A[3][3] * B[3][1],    A[3][1] * B[1][2] + A[3][2] * B[2][2] + A[3][3] * B[3][2],    A[3][1] * B[1][3] + A[3][2] * B[2][3] + A[3][3] * B[3][3],

		};
		return { {Res[1], Res[2], Res[3]}, {Res[4], Res[5], Res[6]}, {Res[7], Res[8], Res[9]} };
	end

	local function Multiply3x1Matrix(A: {{number}}, B: {number}): {number}
		return {
			(A[1][1] * B[1]) + (A[1][2] * B[2]) + (A[1][3] * B[3]),
			(A[2][1] * B[1]) + (A[2][2] * B[2]) + (A[2][3] * B[3]),
			(A[3][1] * B[1]) + (A[3][2] * B[2]) + (A[3][3] * B[3])
		};
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

	local cX, cY, cZ = 20, 0, -80;
	local Ox, Oy, Oz = 0, 0, 0;

	local sin , cos, floor = math.sin, math.cos, math.floor;
	local S = Vector2.new(WIDTH, HEIGHT);
	local C1, C2, C3 = {1, 0, 0}, {0, 1, 0}, {0, 0, 1};
	local W2, H2 = WIDTH * 2, HEIGHT * 2;
	local function Project3DPoint(A: Vector3): (number, number)
		local R = (A - NewVector3(cX, cY, cZ)).Magnitude;
		local cosOx, sinOx, cosOy, sinOy, cosOz, sinOz = cos(Ox), sin(Ox), cos(Oy), sin(Oy), cos(Oz), sin(Oz);
		local D = Multiply3x1Matrix(Multiply3x3Matrix(Multiply3x3Matrix({
			C1,
			{0, cosOx, Ox},
			{0, -sinOx, cosOx}
		}, {
			{cosOy, 0, -sinOy},
			C2,
			{sin(Oy), 0, cosOy}
		}), {
			{cosOz, sinOz, 0},
			{-sinOz, cosOz, 0},
			C3
		}), {
			A.X - cX,
			A.Y - cY,
			A.Z - cZ
		});
		local bx = (D[1] * 200) / (D[3] * FOV) + R;--/ (D.Z/R.X) * R.Z
		local by = (D[2] * 200) / (D[3] * FOV) + R;--/ (D.Z/R.Y) * R.Z
		bx += W2;
		by += H2;
		return floor(bx * OBJECT_SCALE), floor(by * OBJECT_SCALE);
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

		--cX, cY, cZ = -CameraCFrame.X, CameraCFrame.Y, CameraCFrame.Z;
		---- (Canvas.Parent:WaitForChild("Dubug") :: TextLabel).Text = "X: " .. cX .. " Y: " .. cY .. " Z: " .. cZ .. "O: " .. Ox .. " " .. Oy .. " " .. Oz;
		local CPos = Vector3.new(cX, cY, cZ);
		--Ox, Oy, Oz = CameraCFrame:ToWorldSpace(CFrame.new()):ToOrientation();
		--Oy = math.pi*2-Oy;
		--Ox = math.pi*2-Ox;
		--if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then
		--	Ox += 1 * Delta;
		--end

		local TCenX, TCenY = WIDTH/2, 1;
		local BLefX, BLefY = 1, HEIGHT - 1;
		local BRigX, BRigY = WIDTH - 1, HEIGHT - 1;
		DrawLineN(TCenX, BLefX, TCenY, BLefY);
		DrawLineN(BLefX, BRigX, BLefY, BRigY);
		DrawLineN(BRigX, TCenX, BRigY, TCenY);
		--FillTriangleN(TCenX, BLefX, TCenY, BLefY, BRigX, BRigY);	
		for _, Face in ipairs(TopObject.Faces) do
			debug.profilebegin("Draw Face");
			local VI1, VNI1 = Face[1].X, Face[1].Z;
			local VI2, VNI2 = Face[2].X, Face[2].Z;
			local VI3, VNI3 = Face[3].X, Face[3].Z;
			local V1, V2, V3 = TopObject.Verts[VI1], TopObject.Verts[VI2], TopObject.Verts[VI3];
			--local VN1, VN2, VN3 = TopObject.Normals[VNI1], TopObject.Normals[VNI2], TopObject.Normals[VNI3];

			if (not V1 or not V2 or not V3) then print(VNI1, #TopObject.Normals) break; end;
			--local Dis = VN1:Dot((V1 - CPos).Unit);
			--local Dis2 = VN2:Dot((V2 - CPos).Unit);
			--local Dis3 = VN3:Dot((V3 - CPos).Unit);
			--if (Dis > 0.33 and Dis2 > 0.33 and Dis3 > 0.33) then
			--	continue;
			--end

			--V1 *= Inv;
			--V2 *= Inv;
			--V3 *= Inv;


			local VS1x, VS1y = Project3DPoint(V1);
			local VS2x, VS2y = Project3DPoint(V2);
			local VS3x, VS3y = Project3DPoint(V3);
			VS1x, VS1y = VS1x, VS1y;
			VS2x, VS2y = VS2x, VS2y;
			VS3x, VS3y = VS3x, VS3y;

			if (VS1x < 0 and VS1y < 0 and VS2x < 0 and VS2y < 0 and VS3y < 0 and VS3x < 0) then
				continue;
			end
			if (VS1x > WIDTH and VS1y > HEIGHT and VS2x > WIDTH and VS2y > HEIGHT and VS3y > HEIGHT and VS3x > WIDTH) then
				continue;
			end

			--DrawTriangle(
			--	NewVector2(VS1x, VS1y),
			--	NewVector2(VS2x, VS2y),
			--	NewVector2(VS3x, VS3y)
			--);
			DrawLineN(VS1x, VS2x, VS1y, VS2y);
			DrawLineN(VS2x, VS3x, VS2y, VS3y);
			DrawLineN(VS3x, VS1x, VS3y, VS1y);

			--FillTriangleN(VS1x, VS2x, VS1y, VS2y, VS3x, VS3y);
			debug.profileend();
		end

		CameraCFrame = Camera.CFrame;

		debug.profileend();
		Delta = task.wait();
	end
end