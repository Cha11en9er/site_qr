import { apiRequest } from "@/lib/api";

export interface ApiUser {
  id: string;
  email: string;
  full_name: string | null;
  phone: string | null;
  role: string;
  is_admin: boolean;
  email_verified: boolean;
  must_change_password: boolean;
}

export interface TokenPair {
  access_token: string;
  refresh_token: string;
  token_type: string;
}

export interface AuthResponse {
  user: ApiUser;
  tokens: TokenPair;
}

export interface RegisterPayload {
  email: string;
  password: string;
  full_name: string;
  phone: string;
  accept_privacy: boolean;
}

export interface LoginPayload {
  email: string;
  password: string;
}

export async function registerRequest(payload: RegisterPayload): Promise<AuthResponse> {
  return apiRequest<AuthResponse>("/auth/register", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function loginRequest(payload: LoginPayload): Promise<AuthResponse> {
  return apiRequest<AuthResponse>("/auth/login", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function meRequest(token: string): Promise<ApiUser> {
  return apiRequest<ApiUser>("/auth/me", { token });
}

export async function logoutRequest(refreshToken: string): Promise<void> {
  await apiRequest("/auth/logout", {
    method: "POST",
    body: JSON.stringify({ refresh_token: refreshToken }),
  });
}

export function mapApiUser(user: ApiUser) {
  return {
    id: user.id,
    name: user.full_name ?? user.email,
    email: user.email,
    phone: user.phone ?? "",
    isAdmin: user.is_admin,
    emailVerified: user.email_verified,
    mustChangePassword: user.must_change_password,
  };
}

export type AppUser = ReturnType<typeof mapApiUser>;
