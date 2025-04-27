vim.api.nvim_create_user_command("ConvertJsonToGoType", function(opts)
	-- If range is 0, not given, it has been called from normal mode, or visual mode with `<Cmd>` mapping.
	-- Otherwise it must have been called from visual mode.
	require("convert_json_to_go_type").run(opts.args)
end, {
	range = 0,
	nargs = "?",
})
