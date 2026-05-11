type TranscriptDetailsProps = {
  transcript: string | null | undefined
}

export function TranscriptDetails({ transcript }: TranscriptDetailsProps) {
  if (!transcript || transcript.trim() === "") return null

  return (
    <details className="rounded-xl border bg-muted/30 p-4 text-sm">
      <summary className="cursor-pointer font-medium">
        Transcrição da gravação
      </summary>
      <p className="mt-3 whitespace-pre-wrap text-muted-foreground">
        {transcript}
      </p>
    </details>
  )
}
