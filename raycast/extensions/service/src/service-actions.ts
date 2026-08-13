import type { ServiceConfig, ServiceState } from "./types";

export function canStartService(
  service: ServiceConfig,
  state: ServiceState,
): boolean {
  return state === "unavailable" && Boolean(service.start);
}

export function canRestartService(
  service: ServiceConfig,
  state: ServiceState,
): boolean {
  return (
    (state === "running" || state === "error") &&
    Boolean(service.restart || (service.start && service.stop))
  );
}

export function canStopService(
  service: ServiceConfig,
  state: ServiceState,
): boolean {
  return (state === "running" || state === "error") && Boolean(service.stop);
}
