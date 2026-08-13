export type VpnId = "work" | "school";
export type VpnState =
  "connected" | "disconnected" | "unhealthy" | "not_configured" | "disabled";
export type VpnAction = "connect" | "disconnect" | "reconnect";

export interface VpnProcess {
  role: "vpn" | "proxy";
  pid: number;
  elapsed: string;
}

export interface VpnListener {
  host: string;
  port: number;
  protocol: string;
  listening: boolean;
  owned: boolean;
}

export interface VpnIssue {
  code: string;
  message: string;
}

export interface VpnStatus {
  schemaVersion: 1;
  id: VpnId;
  state: VpnState;
  configured: boolean;
  clientInstalled: boolean;
  clientVersion: string | null;
  processes: VpnProcess[];
  listeners: VpnListener[];
  issues: VpnIssue[];
  logPath: string;
}

export interface RouteChoice {
  name: string;
  resolved: string;
  delay?: number;
  testedAt?: string;
}

export interface RouteStatus {
  id: "default" | "ai";
  title: string;
  group: string;
  available: boolean;
  selected?: string;
  resolved?: string;
  delay?: number;
  testedAt?: string;
  choices: RouteChoice[];
  issue?: string;
}

export interface DashboardData {
  vpns: VpnStatus[];
  routes: RouteStatus[];
}
