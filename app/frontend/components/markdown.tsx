import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"

import { cn } from "@/lib/utils"

type MarkdownProps = {
  content: string
  placeholder?: string
  className?: string
}

export function Markdown({ content, placeholder, className }: MarkdownProps) {
  const trimmed = content.trim()
  if (trimmed.length === 0) {
    if (!placeholder) return null
    return (
      <p className="rounded-xl border border-dashed bg-muted/20 p-4 text-sm text-muted-foreground">
        {placeholder}
      </p>
    )
  }

  return (
    <div
      className={cn(
        "prose prose-sm prose-neutral dark:prose-invert max-w-none text-sm leading-relaxed",
        className,
      )}
    >
      <ReactMarkdown remarkPlugins={[ remarkGfm ]} skipHtml>
        {content}
      </ReactMarkdown>
    </div>
  )
}
