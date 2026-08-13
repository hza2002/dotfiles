import type { ServiceConfig, ServiceStatus } from "./types";

const HEALTH_TIMEOUT_MS = 1_500;
const UNAVAILABLE_ERROR_CODES = new Set(["ECONNREFUSED"]);

function errorCauseCode(error: unknown): string | undefined {
  if (
    !(error instanceof Error) ||
    typeof error.cause !== "object" ||
    error.cause === null
  )
    return undefined;
  return "code" in error.cause && typeof error.cause.code === "string"
    ? error.cause.code
    : undefined;
}

export async function checkService(
  service: ServiceConfig,
): Promise<ServiceStatus> {
  const startedAt = performance.now();
  const checkedAt = Date.now();
  try {
    const response = await fetch(service.healthUrl ?? service.url, {
      redirect: "follow",
      signal: AbortSignal.timeout(HEALTH_TIMEOUT_MS),
    });
    const latencyMs = Math.round(performance.now() - startedAt);
    if (response.status >= 200 && response.status < 400) {
      return {
        service,
        state: "running",
        statusCode: response.status,
        latencyMs,
        checkedAt,
      };
    }
    return {
      service,
      state: "error",
      statusCode: response.status,
      latencyMs,
      message: `HTTP ${response.status}`,
      checkedAt,
    };
  } catch (error) {
    const isUnavailable = UNAVAILABLE_ERROR_CODES.has(
      errorCauseCode(error) ?? "",
    );
    return {
      service,
      state: isUnavailable ? "unavailable" : "unknown",
      message:
        error instanceof DOMException && error.name === "TimeoutError"
          ? "Health check timed out"
          : isUnavailable
            ? "Could not connect"
            : error instanceof Error
              ? error.message
              : "Health check failed",
      checkedAt,
    };
  }
}

export async function checkServices(
  services: ServiceConfig[],
): Promise<ServiceStatus[]> {
  return Promise.all(services.map(checkService));
}

export async function waitUntilHealthy(
  service: ServiceConfig,
  timeoutMs = 90_000,
): Promise<ServiceStatus> {
  const deadline = Date.now() + timeoutMs;
  let status = await checkService(service);
  while (status.state !== "running" && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 1_000));
    status = await checkService(service);
  }
  if (status.state !== "running") {
    throw new Error(
      status.message ?? `${service.title} did not become healthy.`,
    );
  }
  return status;
}

export async function waitUntilUnavailable(
  service: ServiceConfig,
  timeoutMs = 15_000,
  pollIntervalMs = 500,
): Promise<ServiceStatus> {
  const deadline = Date.now() + timeoutMs;
  let status = await checkService(service);
  while (status.state !== "unavailable" && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
    status = await checkService(service);
  }
  if (status.state !== "unavailable") {
    throw new Error(
      status.state === "running"
        ? `${service.title} is still responding after it was stopped.`
        : (status.message ?? `${service.title} did not become unavailable.`),
    );
  }
  return status;
}
