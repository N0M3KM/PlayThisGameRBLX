--!strict
local mode = game:GetService("ReplicatedStorage"):FindFirstChild("MatchPreviewMode")
if mode and mode:IsA("BoolValue") and mode.Value then
	require(script.Boot.Match).start()
elseif game:GetService("RunService"):IsStudio() then
	require(script.Boot.Foundation).start()
end
