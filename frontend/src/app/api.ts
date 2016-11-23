export interface InitData {
    data_sources: string[],
    notification_channels: string[],
    checks: Check[],
}

export interface Check {
    id?: number,
    name: string,
    dataSource: string,
    query: string,
    threshold: number,
    state: string,
    subscriptions: Subscription[]
}

export interface Subscription {
    type: string,
    value: string
}

export interface Serie {
    name: string,
    data: [number, number][]
}
