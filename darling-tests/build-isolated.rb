#!/usr/bin/env ruby
# Rebuild all objc_SRCS from a selected checkout with an existing Darling SDK.
# Does not regenerate parent CMake or establish a clean dependency/toolchain build.
require 'shellwords'
require 'fileutils'
require 'open3'
checkout, build, local_source, output = ARGV
abort 'usage: ruby build-isolated-objc.rb CHECKOUT STAGE_BUILD LOCAL_SOURCE NEW_OUTPUT' unless output
[checkout, build, local_source].each { |p| abort "not a directory: #{p}" unless File.directory?(p) }
abort "output already exists: #{output}" if File.exist?(output)
FileUtils.mkdir_p(output)
cmake = File.read("#{checkout}/runtime/CMakeLists.txt")
sources = cmake[/set\(objc_SRCS\s+(.*?)\n\)/m, 1]&.split or abort 'objc_SRCS missing'
def command(build, target)
  result, status = Open3.capture2('ninja', '-C', build, '-t', 'commands', target)
  abort "cannot get command for #{target}" unless status.success?
  result.lines.last
end
remap = lambda do |line|
  line.gsub('/work/source/src/external/objc4', checkout)
      .gsub('/work/source', local_source).gsub('/work/build', build)
end
templates = {
  '.mm' => 'objc-runtime-new.mm',
  '.S' => 'Messengers.subproj/objc-msg-arm64.S'
}.transform_values do |name|
  args = Shellwords.split(remap.call(command(build, "src/external/objc4/runtime/CMakeFiles/objc_obj.dir/#{name}.o")))
  args.take(args.index('-MD'))
end
queue = Queue.new
sources.each { |name| queue << name }
failed = Queue.new
workers = 4.times.map do
  Thread.new do
    loop do
      name = queue.pop(true) rescue break
      object = "#{output}/#{name.gsub('/', '_')}.o"
      args = templates.fetch(File.extname(name)) + ['-c', "#{checkout}/runtime/#{name}", '-o', object]
      ok = system(*args, out: "#{object}.log", err: [:child, :out])
      puts "#{ok ? 'PASS' : 'FAIL'} #{name}"
      failed << name unless ok
    end
  end
end
workers.each(&:join)
abort "#{failed.size} compilation failures; see #{output}/*.log" unless failed.empty?
line = command(build, 'src/external/objc4/runtime/libobjc.A.dylib')
args = Shellwords.split(remap.call(line)).drop_while { |arg| arg != '&&' }.drop(1)
args = args.take(args.index('&&'))
args[args.index('-o') + 1] = "#{output}/libobjc.A.dylib"
args.reject! { |arg| arg.end_with?('.o') }
args += sources.map { |name| "#{output}/#{name.gsub('/', '_')}.o" }
# Link dependencies in the existing build are relative to that build directory.
ok = system(*args, chdir: build, out: "#{output}/link.log", err: [:child, :out])
abort "link failed; see #{output}/link.log" unless ok
puts "PASS: linked #{output}/libobjc.A.dylib from #{sources.size} selected-source objects"
