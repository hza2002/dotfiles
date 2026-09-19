export interface SshTarget {
  user: string;
  hostname: string;
  port: number;
}

export interface Host {
  alias: string;
  title: string;
  note?: string;
  target: SshTarget;
  /** Every effective option from `ssh -G`, as printed. */
  sshOptions: Map<string, string[]>;
  tmuxSession: string;
  lastConnectedAt?: number;
}

export interface KnownHost {
  alias: string;
  hostname: string;
}

export interface GeoInfo {
  countryCode: string;
  city: string;
  isp: string;
}

export interface HostInfo {
  addresses: string[];
  private: boolean;
  geo?: GeoInfo;
}

export interface OverlayHost {
  title?: string;
  tmuxSession?: string;
}

export interface Overlay {
  include: string[];
  exclude: string[];
  hosts: Record<string, OverlayHost>;
}
