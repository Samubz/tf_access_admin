# js-routes output is gitignored (`app/javascript/routes.js`). Production builds
# must generate it before Vite runs (via vite-ruby / assets:precompile).
if Rake::Task.task_defined?("assets:precompile") && Rake::Task.task_defined?("js:routes")
  Rake::Task["assets:precompile"].enhance([ "js:routes" ])
end
