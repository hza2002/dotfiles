export type ServiceGroup = "local" | "remote";
export type ServiceIcon = "blog" | "terminal" | "document" | "dashboard";
export type ServiceState = "running" | "unavailable" | "error" | "unknown";

export interface CommandAction {
  type: "command" | "background";
  cwd: string;
  executable: string;
  args?: string[];
  logPath?: string;
}

export interface HomebrewAction {
  type: "homebrew";
  service: string;
}

export interface ListenerAction {
  type: "listener";
  host: string;
  port: number;
  process: string;
}

export type ServiceAction = CommandAction | HomebrewAction | ListenerAction;

export interface ServiceConfig {
  id: string;
  title: string;
  group: ServiceGroup;
  url: string;
  healthUrl?: string;
  icon: ServiceIcon;
  projectPath?: string;
  logPath?: string;
  start?: ServiceAction;
  stop?: ServiceAction;
  restart?: ServiceAction;
}

export interface ServiceStatus {
  service: ServiceConfig;
  state: ServiceState;
  statusCode?: number;
  latencyMs?: number;
  message?: string;
  checkedAt: number;
}
