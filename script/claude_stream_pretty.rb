#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "time"
require "io/console"

# ───────────────────────────────────────────────────────────────────────────────
# Color & TUI capability detection
# ───────────────────────────────────────────────────────────────────────────────

ENABLE_COLOR =
  if ENV["NO_COLOR"]
    false
  elsif ENV["FORCE_COLOR"] || ENV["CLICOLOR_FORCE"]
    true
  else
    $stdout.tty?
  end

ENABLE_TUI = ENABLE_COLOR && ENV["RALPH_NO_TUI"].nil? && !ENV["RALPH_HEADER_ROWS"].nil?

ANSI = {
  reset:      "\e[0m",
  dim:        "\e[2m",
  bold:       "\e[1m",
  red:        "\e[31m",
  green:      "\e[32m",
  yellow:     "\e[33m",
  blue:       "\e[34m",
  magenta:    "\e[35m",
  cyan:       "\e[36m",
  gray:       "\e[90m",
  br_red:     "\e[91m",
  br_green:   "\e[92m",
  br_yellow:  "\e[93m",
  br_blue:    "\e[94m",
  br_magenta: "\e[95m",
  br_cyan:    "\e[96m"
}.freeze

def c(style, text)
  return text.to_s unless ENABLE_COLOR

  codes = Array(style).map { |s| ANSI.fetch(s) }.join
  "#{codes}#{text}#{ANSI[:reset]}"
end

# ───────────────────────────────────────────────────────────────────────────────
# Tag styling, glyphs, formatters
# ───────────────────────────────────────────────────────────────────────────────

TAG_STYLE = {
  "status"    => :br_blue,
  "assistant" => :br_magenta,
  "tool"      => :br_yellow,
  "read"      => :br_green,
  "done"      => :br_green,
  "result"    => :br_cyan,
  "error"     => :br_red,
  "usage"     => :gray
}.freeze

GLYPHS = {
  "status"    => "▸",
  "assistant" => "◆",
  "tool"      => "⏵",
  "read"      => "↳",
  "done"      => "↳",
  "result"    => "↳",
  "error"     => "✗",
  "usage"     => "Σ"
}.freeze

LABEL_WIDTH = 9

def glyph(name)
  c(TAG_STYLE[name] || :white, GLYPHS[name] || "·")
end

def tag_label(name)
  c(TAG_STYLE[name] || :white, name.ljust(LABEL_WIDTH))
end

def stamp
  "#{c(:gray, Time.now.strftime("%H:%M:%S"))} #{c(:gray, "│")} "
end

def fmt_n(n)
  n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
end

def fmt_duration(seconds)
  s = seconds.to_i
  if s < 60
    "#{s}s"
  elsif s < 3600
    "%d:%02d" % [ s / 60, s % 60 ]
  else
    "%d:%02d:%02d" % [ s / 3600, (s % 3600) / 60, s % 60 ]
  end
end

def fmt_money(amount)
  amount < 1 ? ("$%.4f" % amount) : ("$%.2f" % amount)
end

def freshness_color(seconds)
  if seconds < 10 then :green
  elsif seconds < 60 then :yellow
  else :br_red
  end
end

def compact_path(path)
  return nil if path.nil? || path.empty?

  path.sub("#{Dir.pwd}/", "")
end

def visible_width(text)
  text.gsub(/\e\[[0-9;]*m/, "").length
end

# ───────────────────────────────────────────────────────────────────────────────
# Pricing (USD per 1M tokens). Override via RALPH_PRICING_<KEY> env if needed.
# ───────────────────────────────────────────────────────────────────────────────

PRICING = [
  [ /opus/i,   { in: 15.00, out: 75.00, cache_write: 18.75, cache_read: 1.50 } ],
  [ /sonnet/i, { in:  3.00, out: 15.00, cache_write:  3.75, cache_read: 0.30 } ],
  [ /haiku/i,  { in:  0.80, out:  4.00, cache_write:  1.00, cache_read: 0.08 } ]
].freeze
DEFAULT_PRICE = PRICING.first.last

def price_for(model)
  return DEFAULT_PRICE unless model

  match = PRICING.find { |re, _| re.match?(model) }
  match ? match.last : DEFAULT_PRICE
end

def estimated_cost(model, input:, output:, cache_write:, cache_read:)
  p = price_for(model)
  total = input * p[:in] +
          output * p[:out] +
          cache_write * p[:cache_write] +
          cache_read * p[:cache_read]
  total / 1_000_000.0
end

# ───────────────────────────────────────────────────────────────────────────────
# Session state — persisted across iterations via RALPH_STATE_FILE
# ───────────────────────────────────────────────────────────────────────────────

class State
  HEADER_ROWS = (ENV["RALPH_HEADER_ROWS"] || "4").to_i

  attr_accessor :iteration, :total_iterations,
                :session_started_at, :iter_started_at,
                :model, :last_event_at,
                :iter_input, :iter_output, :iter_cache_write, :iter_cache_read,
                :prev_total_input, :prev_total_output,
                :prev_total_cache_write, :prev_total_cache_read,
                :terminal_height, :terminal_width

  def initialize
    @iteration = (ENV["RALPH_ITER"] || "1").to_i
    @total_iterations = (ENV["RALPH_TOTAL"] || "1").to_i
    sess = ENV["RALPH_SESSION_START"]
    @session_started_at = sess ? Time.at(sess.to_i) : Time.now
    @iter_started_at = Time.now
    @last_event_at = Time.now
    @model = nil
    @iter_input = @iter_output = @iter_cache_write = @iter_cache_read = 0
    @prev_total_input = @prev_total_output = 0
    @prev_total_cache_write = @prev_total_cache_read = 0
    refresh_terminal_size
    load_persisted
  end

  def refresh_terminal_size
    @terminal_height, @terminal_width = IO.console.winsize
  rescue
    @terminal_height, @terminal_width = 24, 80
  end

  def load_persisted
    path = ENV["RALPH_STATE_FILE"]
    return unless path && File.exist?(path) && !File.zero?(path)

    data = JSON.parse(File.read(path)) rescue {}
    @prev_total_input       = data["total_input"].to_i
    @prev_total_output      = data["total_output"].to_i
    @prev_total_cache_write = data["total_cache_write"].to_i
    @prev_total_cache_read  = data["total_cache_read"].to_i
  end

  def persist
    path = ENV["RALPH_STATE_FILE"]
    return unless path

    File.write(path, JSON.generate(
      "total_input"       => total_input,
      "total_output"      => total_output,
      "total_cache_write" => total_cache_write,
      "total_cache_read"  => total_cache_read
    ))
  end

  def add_input_usage(usage)
    return unless usage.is_a?(Hash)

    @iter_input       += usage["input_tokens"].to_i
    @iter_cache_write += usage["cache_creation_input_tokens"].to_i
    @iter_cache_read  += usage["cache_read_input_tokens"].to_i
  end

  def add_output_usage(usage)
    return unless usage.is_a?(Hash)

    @iter_output += usage["output_tokens"].to_i
  end

  def total_input;       @prev_total_input + @iter_input; end
  def total_output;      @prev_total_output + @iter_output; end
  def total_cache_write; @prev_total_cache_write + @iter_cache_write; end
  def total_cache_read;  @prev_total_cache_read + @iter_cache_read; end

  def iter_cost
    estimated_cost(@model, input: @iter_input, output: @iter_output,
                   cache_write: @iter_cache_write, cache_read: @iter_cache_read)
  end

  def total_cost
    estimated_cost(@model, input: total_input, output: total_output,
                   cache_write: total_cache_write, cache_read: total_cache_read)
  end

  def touch
    @last_event_at = Time.now
  end
end

# ───────────────────────────────────────────────────────────────────────────────
# Header — owns rows 1..HEADER_ROWS, repainted in place via absolute cursor moves
# ───────────────────────────────────────────────────────────────────────────────

class Header
  def initialize(state, mutex:)
    @state = state
    @mutex = mutex
    @prev_lines = []
  end

  def redraw
    return unless ENABLE_TUI

    @mutex.synchronize do
      lines = render_lines
      $stdout.write("\e7") # save cursor
      lines.each_with_index do |line, i|
        next if @prev_lines[i] == line

        $stdout.write("\e[#{i + 1};1H\e[2K#{line}")
        @prev_lines[i] = line
      end
      $stdout.write("\e8") # restore cursor
      $stdout.flush
    end
  end

  def invalidate
    @prev_lines = []
  end

  private

  def render_lines
    s = @state
    width = s.terminal_width || 80
    now = Time.now
    session_elapsed = (now - s.session_started_at).to_i
    iter_elapsed    = (now - s.iter_started_at).to_i
    last_event_age  = (now - s.last_event_at).to_i

    sep = c(:gray, " · ")

    line1 = [
      c(%i[bold cyan], "RALPH #{s.iteration}/#{s.total_iterations}"),
      "#{c(:dim, "session")} #{fmt_duration(session_elapsed)}",
      "#{c(:dim, "iter")} #{fmt_duration(iter_elapsed)}",
      "#{c(:dim, "last event")} #{c(freshness_color(last_event_age), "#{last_event_age}s ago")}",
      "#{c(:dim, "model")} #{c(:magenta, s.model || "—")}"
    ].join(sep)

    line2 = format_token_line("iter ",
                              s.iter_input, s.iter_output,
                              s.iter_cache_write, s.iter_cache_read,
                              s.iter_cost)
    line3 = format_token_line("total",
                              s.total_input, s.total_output,
                              s.total_cache_write, s.total_cache_read,
                              s.total_cost)
    line4 = c(:gray, "─" * width)

    [ pad(line1, width), pad(line2, width), pad(line3, width), line4 ]
  end

  def format_token_line(label, input, output, cache_write, cache_read, cost)
    [
      c(:bold, label),
      "#{c(:dim, "in")} #{c(:bold, fmt_n(input).rjust(8))}",
      "#{c(:dim, "out")} #{c(:bold, fmt_n(output).rjust(7))}",
      "#{c(:dim, "cache W")} #{c(:bold, fmt_n(cache_write).rjust(8))}",
      "#{c(:dim, "R")} #{c(:bold, fmt_n(cache_read).rjust(10))}",
      "#{c(:dim, "≈")} #{c(:green, fmt_money(cost))}"
    ].join("  ")
  end

  def pad(line, width)
    visible = visible_width(line)
    visible < width ? line + (" " * (width - visible)) : line
  end
end

# ───────────────────────────────────────────────────────────────────────────────
# Output helpers — guarded by stdout mutex
# ───────────────────────────────────────────────────────────────────────────────

OUT_MUTEX = Mutex.new
@at_line_start = true
@streamed_text = false

def emit(line)
  $stdout.write("#{stamp}#{line}\n")
end

def stream_text(text)
  prefix = c([ :dim, :magenta ], "  │ ")
  text.each_line(chomp: false) do |line|
    if @at_line_start
      $stdout.write("#{stamp}#{prefix}")
      @at_line_start = false
    end
    $stdout.write(line)
    @at_line_start = line.end_with?("\n")
  end
  $stdout.flush
end

def close_open_text
  return if @at_line_start

  $stdout.write("\n")
  @at_line_start = true
end

# ───────────────────────────────────────────────────────────────────────────────
# Per-message-type rendering (rich)
# ───────────────────────────────────────────────────────────────────────────────

def emit_event(name, body)
  emit("#{glyph(name)} #{tag_label(name)} #{body}")
end

def emit_indented(name, body)
  # Result lines aligned under their tool call (2-space gutter + arrow + label).
  emit("  #{glyph(name)} #{c(TAG_STYLE[name] || :white, body)}")
end

def truncate_one_line(text, max_width)
  text = text.to_s
  first = text.lines.first.to_s.chomp
  rest_bytes = text.bytesize - first.bytesize
  if first.length > max_width
    "#{first[0, max_width - 1]}…"
  elsif rest_bytes.positive?
    "#{first} #{c(:dim, "(+#{fmt_n(rest_bytes)} more bytes)")}"
  else
    first
  end
end

def emit_error_block(title, body_text, terminal_width)
  inner = [ terminal_width - visible_width(stamp) - 4, 30 ].max
  body_lines = body_text.to_s.lines.map { |l| l.chomp[0, inner] }
  body_lines = [ "(no output)" ] if body_lines.empty?

  header_text = " ✗ #{title} ".center(inner, "━")
  emit(c(:br_red, "┏#{header_text}┓"))
  body_lines.each do |line|
    pad = inner - line.length
    emit(c(:br_red, "┃ ") + line + (" " * [ pad - 2, 0 ].max) + c(:br_red, " ┃"))
  end
  emit(c(:br_red, "┗" + ("━" * inner) + "┛"))
end

def print_tool_use(tool)
  name = tool["name"] || "Tool"
  input = tool["input"] || {}
  description = input["description"]
  command = input["command"]
  file_path = compact_path(input["file_path"])

  primary = description || command || file_path
  body = primary ? "#{c(:bold, name)}  #{primary}" : c(:bold, name)
  emit_event("tool", body)

  # Show the command if it's not already the primary line — the tool result
  # rarely echoes it back, so this is the only place to see what was run.
  emit_indented("read", c(:dim, command)) if command && command != primary
  # File paths intentionally not echoed here: the matching tool_result line
  # below will show the path (and line count) right under this tool call.
end

def summarize_tool_result(record, state)
  result = record["tool_use_result"]
  content = record.dig("message", "content")&.find { |part| part["type"] == "tool_result" }
  is_error = content && content["is_error"]

  if result.is_a?(Hash) && result["file"].is_a?(Hash)
    file = result["file"]
    path = compact_path(file["filePath"])
    total = file["totalLines"] || file["numLines"]
    suffix = total ? c(:dim, " (#{total} lines)") : ""
    if is_error
      emit_error_block("READ ERROR", "#{path}#{total ? " (#{total} lines)" : ""}", state.terminal_width || 80)
    else
      emit_indented("read", "#{path}#{suffix}")
    end
  elsif result.is_a?(Hash) && (result["stdout"] || result["stderr"])
    stdout = result["stdout"].to_s
    stderr = result["stderr"].to_s
    interrupted = result["interrupted"] ? c(:yellow, " interrupted") : ""
    lines = stdout.lines.size + stderr.lines.size
    if is_error
      body = (stderr.empty? ? stdout : stderr)
      emit_error_block("COMMAND FAILED#{result["interrupted"] ? " (interrupted)" : ""}",
                       body, state.terminal_width || 80)
    else
      emit_indented("done", "command#{interrupted} #{c(:dim, "(#{lines} output lines)")}")
    end
  elsif content
    text = content["content"].to_s
    if is_error
      emit_error_block("TOOL ERROR", text, state.terminal_width || 80)
    else
      max_inner = (state.terminal_width || 80) - visible_width(stamp) - 4
      emit_indented("result", truncate_one_line(text, [ max_inner, 40 ].max))
    end
  end
end

# ───────────────────────────────────────────────────────────────────────────────
# Bootstrap & main loop
# ───────────────────────────────────────────────────────────────────────────────

state  = State.new
header = Header.new(state, mutex: OUT_MUTEX)

resize_pending = false
Signal.trap("WINCH") { resize_pending = true } rescue nil

at_exit do
  state.persist
end

ticker = nil
if ENABLE_TUI
  header.redraw
  ticker = Thread.new do
    Thread.current.abort_on_exception = false
    loop do
      sleep 1
      if resize_pending
        state.refresh_terminal_size
        header.invalidate
        resize_pending = false
      end
      header.redraw
    end
  end
end

def handle(record, state, header)
  case record["type"]
  when "system"
    if record["subtype"] == "status" && record["status"]
      close_open_text
      emit_event("status", c(:dim, record["status"]))
    end
  when "assistant"
    Array(record.dig("message", "content")).each do |part|
      case part["type"]
      when "text"
        next if @streamed_text

        close_open_text
        text = part["text"].to_s
        stream_text(text)
        stream_text("\n") unless text.end_with?("\n")
      when "tool_use"
        close_open_text
        print_tool_use(part)
      end
    end
  when "user"
    close_open_text
    summarize_tool_result(record, state)
  when "stream_event"
    event = record["event"] || {}
    case event["type"]
    when "message_start"
      close_open_text
      @streamed_text = false
      message = event["message"] || {}
      state.model = message["model"] if message["model"]
      state.add_input_usage(message["usage"])
      ttft = record["ttft_ms"]
      meta = ttft ? c(:dim, " (#{ttft}ms ttft)") : ""
      emit_event("assistant", "#{c(:magenta, state.model || "?")}#{meta}")
    when "content_block_delta"
      delta = event["delta"] || {}
      text = delta["text"] || delta["partial_text"]
      if delta["type"] == "text_delta" && text
        stream_text(text)
        @streamed_text = true
      end
    when "message_delta"
      state.add_output_usage(event["usage"])
      output_tokens = event.dig("usage", "output_tokens")
      close_open_text
      emit_event("usage", c(:dim, "+#{fmt_n(output_tokens)} out tokens this turn")) if output_tokens
    end
  end
end

ARGF.each_line do |line|
  OUT_MUTEX.synchronize do
    begin
      record = JSON.parse(line)
      state.touch
      handle(record, state, header)
    rescue JSON::ParserError
      close_open_text
      preview = line.chomp.strip[0, 160]
      preview = "#{preview}…" if line.chomp.length > 160
      emit_event("error", c(:dim, "non-json: #{preview}"))
    end
  end
  header.redraw
end

OUT_MUTEX.synchronize { close_open_text }
ticker&.kill
header.redraw if ENABLE_TUI
