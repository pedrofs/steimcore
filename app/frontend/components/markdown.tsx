import { type ReactNode } from "react"
import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"

import { cn } from "@/lib/utils"

type MarkdownProps = {
  content: string
  placeholder?: string
  emptyAction?: ReactNode
  className?: string
}

export function Markdown({ content, placeholder, emptyAction, className }: MarkdownProps) {
  const trimmed = content.trim()
  if (trimmed.length === 0) {
    if (!placeholder) return null
    return (
      <div className="flex flex-col items-start gap-3 rounded-xl border border-dashed bg-muted/20 p-4">
        <p className="text-sm text-muted-foreground">{placeholder}</p>
        {emptyAction}
      </div>
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
