--!strict
local function stringEndsWith(str:string, endsWith:string): boolean
	local endStr = string.sub(str, -#endsWith, -1);
	return endsWith == endStr;
end

local function stringStartsWith(str:string, startsWith:string): boolean
	local startStr = string.sub(str, 1, #startsWith);
	return startStr == startsWith;
end

export type Object = {
	Name: string,
	Verts: {Vector3},
	Normals: {Vector3},
	Uvs: {Vector3},
	Faces: {{Vector3}},
}

export type ObjectFile = {
	File: ModuleScript,
	Objects: {Object}
};

local function ParseObj(Object: ModuleScript): ObjectFile
	assert(stringEndsWith(Object.Name, ".obj"), "Module name must end with .obj to indicate an object file.");
	local StringData = require(Object); -- luau moment
	assert(StringData and type(StringData) == "string", "Module returned nil or non string value.");

	local ObjectFile: ObjectFile = {
		File = Object,
		Objects = {},
	};
	local Lines = StringData.split(StringData, "\n");

	for _, Line in ipairs(Lines) do
		if (stringStartsWith(Line, "#")) then -- comment
			continue;
		end
		local Parameters = string.split(Line, " ");
		if (stringStartsWith(Line, "o")) then -- object
			local Name = Parameters[2];
			ObjectFile.Objects[#ObjectFile.Objects + 1] = {
				Name = Name,
				Verts = {},
				Faces = {},
				Normals = {},
				Uvs = {}
			};
		elseif (stringStartsWith(Line, "vn")) then -- Vertex Normals
			local xS, yS, zS, wS = Parameters[2], Parameters[3], Parameters[4], Parameters[5];
			local NormalVec = Vector3.new(tonumber(xS), tonumber(yS), tonumber(zS));
			print "Parsed normal";
			ObjectFile.Objects[#ObjectFile.Objects].Normals[#ObjectFile.Objects[#ObjectFile.Objects].Normals + 1] = NormalVec;
		elseif (stringStartsWith(Line, "v")) then -- Vertex
			local xS, yS, zS, wS = Parameters[2], Parameters[3], Parameters[4], Parameters[5];
			local VertexVec = Vector3.new(tonumber(xS), -(tonumber(yS) or 0), tonumber(zS));
			ObjectFile.Objects[#ObjectFile.Objects].Verts[#ObjectFile.Objects[#ObjectFile.Objects].Verts + 1] = VertexVec;
		elseif (stringStartsWith(Line, "f")) then
			local A, B, C = Parameters[2], Parameters[3], Parameters[4];
			local A1, A2, A3 = unpack(string.split(A, "/"));
			local B1, B2, B3 = unpack(string.split(B, "/"));
			local C1, C2, C3 = unpack(string.split(C, "/"));
			local AVec = Vector3.new(tonumber(A1), tonumber(A2), tonumber(A3));
			local BVec = Vector3.new(tonumber(B1), tonumber(B2), tonumber(B3));
			local CVec = Vector3.new(tonumber(C1), tonumber(C2), tonumber(C3));
			ObjectFile.Objects[#ObjectFile.Objects].Faces[#ObjectFile.Objects[#ObjectFile.Objects].Faces + 1] = { AVec, BVec, CVec };
		else
			print("Unknown line:", Line);
		end
	end

	return ObjectFile;
end

return ParseObj;