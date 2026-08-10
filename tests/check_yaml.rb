#!/usr/bin/env ruby
require 'yaml'

root = File.expand_path('..', __dir__)
errors = []
files = Dir.glob(File.join(root, '**', '*.{yaml,yml}')).sort
files.reject! { |file| file.include?('/demo/target-application/templates/') }

files.each do |file|
  begin
    YAML.parse_stream(File.read(file), filename: file)
  rescue Psych::SyntaxError => e
    errors << "#{file.delete_prefix(root + '/')}: #{e.message}"
  end
end

unless errors.empty?
  warn "Ungültiges YAML:\n#{errors.join("\n")}"
  exit 1
end

puts "#{files.length} YAML-Dateien sind syntaktisch gültig."
