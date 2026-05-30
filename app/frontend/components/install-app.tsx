import { usePage } from "@inertiajs/react"
import { Download, Share, SquarePlus, X } from "lucide-react"
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react"

import { BRAND_NAME } from "@/lib/brand"
import { Button } from "@/components/ui/button"
import { DropdownMenuItem } from "@/components/ui/dropdown-menu"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { cn } from "@/lib/utils"

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>
}

type Platform =
  | "android-chromium"
  | "desktop-chromium"
  | "ios-safari"
  | "other"

type PromptOutcome = "accepted" | "dismissed" | "unavailable"

type InstallAppContextValue = {
  platform: Platform
  isStandalone: boolean
  canNativePrompt: boolean
  promptInstall: () => Promise<PromptOutcome>
  openInstructions: () => void
}

const DISMISSED_KEY = "steimfit:install-banner-dismissed-at"
const DISMISS_WINDOW_MS = 14 * 24 * 60 * 60 * 1000

const InstallAppContext = createContext<InstallAppContextValue | null>(null)

function detectPlatform(): Platform {
  if (typeof navigator === "undefined") return "other"
  const ua = navigator.userAgent
  const isIOS = /iPad|iPhone|iPod/.test(ua) && !("MSStream" in window)
  if (isIOS) {
    const isInAppBrowser = /CriOS|FxiOS|EdgiOS|OPiOS|YaBrowser|FBAN|FBAV|Instagram|Line/.test(ua)
    return isInAppBrowser ? "other" : "ios-safari"
  }
  const isChromium = /Chrome|Chromium|Edg|OPR/.test(ua) && !/Edge\//.test(ua)
  if (!isChromium) return "other"
  const isAndroid = /Android/.test(ua)
  return isAndroid ? "android-chromium" : "desktop-chromium"
}

function detectStandalone(): boolean {
  if (typeof window === "undefined") return false
  if (window.matchMedia?.("(display-mode: standalone)").matches) return true
  const nav = window.navigator as Navigator & { standalone?: boolean }
  return nav.standalone === true
}

export function InstallAppProvider({ children }: { children: ReactNode }) {
  const [deferred, setDeferred] = useState<BeforeInstallPromptEvent | null>(null)
  const [isStandalone, setIsStandalone] = useState<boolean>(() => detectStandalone())
  const [platform, setPlatform] = useState<Platform>(() => detectPlatform())
  const [instructionsOpen, setInstructionsOpen] = useState(false)

  useEffect(() => {
    setPlatform(detectPlatform())
    setIsStandalone(detectStandalone())

    const onPrompt = (e: Event) => {
      e.preventDefault()
      setDeferred(e as BeforeInstallPromptEvent)
    }
    const onInstalled = () => {
      setDeferred(null)
      setIsStandalone(true)
    }
    const mql = window.matchMedia("(display-mode: standalone)")
    const onDisplayChange = (e: MediaQueryListEvent) => setIsStandalone(e.matches)

    window.addEventListener("beforeinstallprompt", onPrompt)
    window.addEventListener("appinstalled", onInstalled)
    mql.addEventListener("change", onDisplayChange)

    return () => {
      window.removeEventListener("beforeinstallprompt", onPrompt)
      window.removeEventListener("appinstalled", onInstalled)
      mql.removeEventListener("change", onDisplayChange)
    }
  }, [])

  const promptInstall = useCallback(async (): Promise<PromptOutcome> => {
    if (!deferred) return "unavailable"
    try {
      await deferred.prompt()
      const choice = await deferred.userChoice
      setDeferred(null)
      return choice.outcome
    } catch {
      return "unavailable"
    }
  }, [deferred])

  const openInstructions = useCallback(() => setInstructionsOpen(true), [])

  const value = useMemo<InstallAppContextValue>(
    () => ({
      platform,
      isStandalone,
      canNativePrompt: deferred !== null,
      promptInstall,
      openInstructions,
    }),
    [platform, isStandalone, deferred, promptInstall, openInstructions],
  )

  return (
    <InstallAppContext.Provider value={value}>
      {children}
      <InstallAppSheet
        open={instructionsOpen}
        onOpenChange={setInstructionsOpen}
      />
    </InstallAppContext.Provider>
  )
}

function useInstallApp(): InstallAppContextValue {
  const ctx = useContext(InstallAppContext)
  if (!ctx) {
    throw new Error("useInstallApp must be used inside InstallAppProvider")
  }
  return ctx
}

function readDismissedAt(): number | null {
  if (typeof window === "undefined") return null
  const raw = window.localStorage.getItem(DISMISSED_KEY)
  if (!raw) return null
  const parsed = Number(raw)
  return Number.isFinite(parsed) ? parsed : null
}

export function InstallAppBanner() {
  const { props } = usePage()
  const { platform, isStandalone, canNativePrompt, promptInstall, openInstructions } =
    useInstallApp()
  const [dismissed, setDismissed] = useState<boolean>(() => {
    const at = readDismissedAt()
    return at !== null && Date.now() - at < DISMISS_WINDOW_MS
  })

  const signedIn = Boolean(props.currentUser)
  const eligible =
    signedIn &&
    !isStandalone &&
    !dismissed &&
    (canNativePrompt || platform === "ios-safari")

  if (!eligible) return null

  const dismiss = () => {
    window.localStorage.setItem(DISMISSED_KEY, String(Date.now()))
    setDismissed(true)
  }

  const handleInstall = async () => {
    if (platform === "ios-safari") {
      openInstructions()
      return
    }
    const outcome = await promptInstall()
    if (outcome === "unavailable") {
      openInstructions()
    } else {
      dismiss()
    }
  }

  return (
    <div className="mx-4 mb-2 flex items-center gap-3 rounded-md border border-primary/20 bg-primary/5 px-3 py-2 text-sm">
      <Download className="size-4 shrink-0 text-primary" />
      <p className="flex-1 leading-snug">
        Instale o {BRAND_NAME} no seu dispositivo para acesso rápido.
      </p>
      <Button size="sm" onClick={handleInstall}>
        Instalar
      </Button>
      <Button
        size="icon-sm"
        variant="ghost"
        aria-label="Dispensar"
        onClick={dismiss}
      >
        <X />
      </Button>
    </div>
  )
}

export function InstallAppMenuItem() {
  const { platform, isStandalone, canNativePrompt, promptInstall, openInstructions } =
    useInstallApp()

  if (isStandalone) return null
  if (platform === "other") return null

  const handleSelect = () => {
    if (platform === "ios-safari" || !canNativePrompt) {
      window.setTimeout(openInstructions, 0)
      return
    }
    void promptInstall()
  }

  return (
    <DropdownMenuItem onSelect={handleSelect}>
      <Download className="mr-2 size-4" />
      Instalar app
    </DropdownMenuItem>
  )
}

function InstallAppSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (next: boolean) => void
}) {
  const { platform, canNativePrompt, promptInstall } = useInstallApp()

  const handleNativePrompt = async () => {
    const outcome = await promptInstall()
    if (outcome !== "unavailable") onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="bottom" className="p-4 pb-6">
        <SheetHeader className="p-0">
          <SheetTitle>Instalar {BRAND_NAME}</SheetTitle>
          <SheetDescription>
            {platform === "ios-safari"
              ? "Adicione o app à tela de início em três passos."
              : "Adicione o app ao seu dispositivo para abrir em uma janela própria."}
          </SheetDescription>
        </SheetHeader>

        {platform === "ios-safari" ? (
          <ol className="mt-4 space-y-3 text-sm">
            <InstructionStep
              index={1}
              icon={<Share className="size-5" />}
              text="Toque no ícone de compartilhar na barra do Safari."
            />
            <InstructionStep
              index={2}
              icon={<SquarePlus className="size-5" />}
              text={<>Role e escolha <strong>Adicionar à Tela de Início</strong>.</>}
            />
            <InstructionStep
              index={3}
              icon={<Download className="size-5" />}
              text={<>Confirme em <strong>Adicionar</strong>. Pronto — o ícone aparece na tela inicial.</>}
            />
          </ol>
        ) : (
          <div className="mt-4 space-y-3 text-sm">
            {canNativePrompt ? (
              <Button className="w-full" onClick={handleNativePrompt}>
                Instalar agora
              </Button>
            ) : (
              <p className="text-muted-foreground">
                Abra o menu do navegador (três pontos) e toque em{" "}
                <strong>Instalar {BRAND_NAME}</strong> ou{" "}
                <strong>Adicionar à tela inicial</strong>.
              </p>
            )}
          </div>
        )}
      </SheetContent>
    </Sheet>
  )
}

function InstructionStep({
  index,
  icon,
  text,
}: {
  index: number
  icon: ReactNode
  text: ReactNode
}) {
  return (
    <li className="flex items-start gap-3">
      <span
        className={cn(
          "flex size-7 shrink-0 items-center justify-center rounded-full",
          "bg-primary/10 font-medium text-primary",
        )}
      >
        {index}
      </span>
      <span className="flex flex-1 items-center gap-2 leading-snug">
        <span className="text-muted-foreground">{icon}</span>
        <span>{text}</span>
      </span>
    </li>
  )
}
