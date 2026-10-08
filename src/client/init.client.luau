--!strict
local mode = game:GetService("ReplicatedStorage"):WaitForChild("MatchPreviewMode", 5)
if mode and mode:IsA("BoolValue") and mode.Value then
	require(script.Controllers.MatchPreview).start()
elseif game:GetService("RunService"):IsStudio() then
	print("Play This Game: foundation client booted. Match preview uses match.project.json.")
end
