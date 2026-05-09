#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

def compact_path(path)
  return nil if path.nil? || path.empty?

  path.sub("#{Dir.pwd}/", "")
end

def print_tool_use(tool)
  name = tool["name"] || "Tool"
  input = tool["input"] || {}
  description = input["description"]
  command = input["command"]
  file_path = compact_path(input["file_path"])

  details = description || command || file_path
  puts details ? "[tool] #{name}: #{details}" : "[tool] #{name}"
  puts "       #{command}" if command && description && command != description
  puts "       #{file_path}" if file_path && file_path != details
end

def summarize_tool_result(record)
  result = record["tool_use_result"]
  content = record.dig("message", "content")&.find { |part| part["type"] == "tool_result" }
  is_error = content && content["is_error"]

  if result.is_a?(Hash) && result["file"].is_a?(Hash)
    file = result["file"]
    path = compact_path(file["filePath"])
    total = file["totalLines"] || file["numLines"]
    suffix = total ? " (#{total} lines)" : ""
    puts is_error ? "[error] #{path}#{suffix}" : "[read] #{path}#{suffix}"
  elsif result.is_a?(Hash) && (result["stdout"] || result["stderr"])
    stdout = result["stdout"].to_s
    stderr = result["stderr"].to_s
    interrupted = result["interrupted"] ? " interrupted" : ""
    lines = stdout.lines.size + stderr.lines.size
    puts is_error ? "[error] command#{interrupted} (#{lines} output lines)" : "[done] command#{interrupted} (#{lines} output lines)"
  elsif content
    text = content["content"].to_s
    preview = text.lines.first.to_s.strip
    preview = preview[0, 120]
    puts is_error ? "[error] #{preview}" : "[result] #{preview}"
  end
end

text_open = false
streamed_text = false

ARGF.each_line do |line|
  record = JSON.parse(line)

  case record["type"]
  when "system"
    puts "[status] #{record["status"]}" if record["subtype"] == "status" && record["status"]
  when "assistant"
    Array(record.dig("message", "content")).each do |part|
      case part["type"]
      when "text"
        unless streamed_text
          puts unless text_open
          puts part["text"]
          text_open = false
        end
      when "tool_use"
        puts if text_open
        text_open = false
        print_tool_use(part)
      end
    end
  when "user"
    puts if text_open
    text_open = false
    summarize_tool_result(record)
  when "stream_event"
    event = record["event"] || {}
    case event["type"]
    when "message_start"
      streamed_text = false
      model = event.dig("message", "model")
      ttft = record["ttft_ms"]
      puts "[assistant] #{model}#{ttft ? " (#{ttft}ms)" : ""}"
    when "content_block_delta"
      delta = event["delta"] || {}
      text = delta["text"] || delta["partial_text"]
      if delta["type"] == "text_delta" && text
        print text
        $stdout.flush
        text_open = true
        streamed_text = true
      end
    when "message_delta"
      usage = event["usage"] || {}
      output_tokens = usage["output_tokens"]
      puts if text_open
      text_open = false
      puts "[usage] #{output_tokens} output tokens" if output_tokens
    end
  end
rescue JSON::ParserError
  puts line
end
