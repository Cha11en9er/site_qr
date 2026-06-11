import { apiRequest } from "@/lib/api";

export interface ApiUser {
  id: string;
  email: string | null;
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
  login: string;
  password: string;
  accept_privacy: boolean;
}

export interface LoginPayload {
  login: string;
  password: string;
}

export interface UserProfileUpdatePayload {
  full_name?: string | null;
  email?: string | null;
  phone?: string | null;
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

export async function updateProfileRequest(
  token: string,
  payload: UserProfileUpdatePayload,
): Promise<ApiUser> {
  return apiRequest<ApiUser>("/auth/me", {
    method: "PATCH",
    token,
    body: JSON.stringify(payload),
  });
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
    name: user.full_name ?? user.email ?? user.phone ?? "Пользователь",
    fullName: user.full_name ?? "",
    email: user.email ?? "",
    phone: user.phone ?? "",
    isAdmin: user.is_admin,
    emailVerified: user.email_verified,
    mustChangePassword: user.must_change_password,
  };
}

export type AppUser = ReturnType<typeof mapApiUser>;
