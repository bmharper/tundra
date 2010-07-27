local _generator = ...
local util = require("tundra.util")
local nodegen = require("tundra.nodegen")

local function install_libs(unit_env, decl)
	for _, item in util.nil_ipairs(nodegen.flatten_list(unit_env:get('BUILD_ID'), decl.Libs)) do
		unit_env:append("LIBS", item)
	end
end

function _generator:eval_native_unit(env, label, suffix, command, decl)
	local build_id = env:get("BUILD_ID")
	local function implicit_make(source_file)
		local t = type(source_file)
		if t == "table" then
			return source_file
		end
		assert(t == "string")

		local make = env:get_implicit_make_fn(source_file)
		if make then
			return make(env, self:resolve_pass(decl.Pass), source_file)
		else
			return nil
		end
	end

	install_libs(env, decl)

	local exts = env:get_list("NATIVE_SUFFIXES")
	local deps = self:resolve_deps(build_id, decl.Depends)
	local source_files = nodegen.flatten_list(build_id, decl.Sources)
	local sources = self:resolve_sources(env, { source_files, deps }, {}, decl.SourceDir)
	local inputs, ideps = self:analyze_sources(sources, exts, implicit_make)
	deps = util.merge_arrays_2(deps, ideps)
	deps = util.merge_arrays_2(deps, decl.Dependencies)
	deps = util.uniq(deps)
	local libnode = env:make_node {
		Label = label .. " $(@)",
		Pass = self:resolve_pass(decl.Pass),
		Action = command,
		InputFiles = inputs,
		OutputFiles = { self:get_target(decl, suffix) },
		Dependencies = deps,
	}
	return libnode
end

nodegen.add_evaluator("Program", function (self, env, decl)
	return self:eval_native_unit(env, "Program", "$(PROGSUFFIX)", "$(PROGCOM)", decl)
end)

nodegen.add_evaluator("StaticLibrary", function (self, env, decl)
	return self:eval_native_unit(env, "StaticLib", "$(LIBSUFFIX)", "$(LIBCOM)", decl)
end)
