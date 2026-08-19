#!/usr/bin/env ruby
# Verifies relative Markdown links. Web URLs and standalone anchors are outside
# the scope of this static repository check.

root = File.expand_path('..', __dir__)
errors = []

Dir.glob(File.join(root, '**', '*.md')).sort.each do |file|
  File.read(file).scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |raw|
    target = raw.strip
    target = target[1..-2] if target.start_with?('<') && target.end_with?('>')
    next if target.empty? || target.start_with?('#')
    next if target.match?(%r{^[a-z][a-z0-9+.-]*://}i)

    path = target.split('#', 2).first
    next if path.empty? || path.include?('$') || path.include?('<')

    resolved = File.expand_path(path, File.dirname(file))
    errors << "#{file.delete_prefix(root + '/')}: #{target}" unless File.exist?(resolved)
  end
end

unless errors.empty?
  warn "Unresolvable Markdown links:\n#{errors.join("\n")}"
  exit 1
end

puts 'Relative Markdown links are valid.'
