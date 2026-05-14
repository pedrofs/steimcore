declare module "@rails/actioncable" {
  export type ConsumerReceivedHandler = (data: unknown) => void
  export type SubscriptionMixin = {
    received?: ConsumerReceivedHandler
    connected?: () => void
    disconnected?: () => void
    rejected?: () => void
    initialized?: () => void
  }
  export interface Subscription {
    unsubscribe(): void
    perform(action: string, data?: object): void
    send(data: object): boolean
  }
  export interface Subscriptions {
    create(channel: string | object, mixin?: SubscriptionMixin): Subscription
  }
  export interface Consumer {
    subscriptions: Subscriptions
    disconnect(): void
  }
  export function createConsumer(url?: string): Consumer
}
