import { create } from "zustand";
import { persist } from "zustand/middleware";
import {
  AppUser,
  loginRequest,
  logoutRequest,
  mapApiUser,
  meRequest,
  registerRequest,
} from "@/lib/auth-api";
import { ApiError } from "@/lib/api";

interface AuthState {
  user: AppUser | null;
  accessToken: string | null;
  refreshToken: string | null;
  isHydrating: boolean;
  login: (email: string, password: string) => Promise<{ ok: true } | { ok: false; error: string }>;
  register: (payload: {
    name: string;
    email: string;
    phone: string;
    password: string;
    acceptPrivacy: boolean;
  }) => Promise<{ ok: true } | { ok: false; error: string }>;
  logout: () => Promise<void>;
  hydrateSession: () => Promise<void>;
  setSession: (user: AppUser, accessToken: string, refreshToken: string) => void;
}

function authErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.detail === "INVALID_CREDENTIALS") return "Неверный email или пароль";
    if (error.detail === "EMAIL_ALREADY_EXISTS") return "Пользователь с таким email уже существует";
    if (error.detail.includes("Phone")) return "Телефон укажите в формате +79001234567";
    return error.detail;
  }
  return "Не удалось выполнить запрос. Проверьте, что API запущен.";
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      accessToken: null,
      refreshToken: null,
      isHydrating: false,

      setSession: (user, accessToken, refreshToken) => {
        set({ user, accessToken, refreshToken });
      },

      hydrateSession: async () => {
        const token = get().accessToken;
        if (!token) return;

        set({ isHydrating: true });
        try {
          const user = await meRequest(token);
          set({ user: mapApiUser(user) });
        } catch {
          set({ user: null, accessToken: null, refreshToken: null });
        } finally {
          set({ isHydrating: false });
        }
      },

      login: async (email, password) => {
        try {
          const response = await loginRequest({ email, password });
          set({
            user: mapApiUser(response.user),
            accessToken: response.tokens.access_token,
            refreshToken: response.tokens.refresh_token,
          });
          return { ok: true };
        } catch (error) {
          return { ok: false, error: authErrorMessage(error) };
        }
      },

      register: async ({ name, email, phone, password, acceptPrivacy }) => {
        try {
          const response = await registerRequest({
            email,
            password,
            full_name: name,
            phone,
            accept_privacy: acceptPrivacy,
          });
          set({
            user: mapApiUser(response.user),
            accessToken: response.tokens.access_token,
            refreshToken: response.tokens.refresh_token,
          });
          return { ok: true };
        } catch (error) {
          return { ok: false, error: authErrorMessage(error) };
        }
      },

      logout: async () => {
        const refreshToken = get().refreshToken;
        if (refreshToken) {
          try {
            await logoutRequest(refreshToken);
          } catch {
            // ignore network errors on logout
          }
        }
        set({ user: null, accessToken: null, refreshToken: null });
      },
    }),
    {
      name: "auth-storage",
      partialize: (state) => ({
        user: state.user,
        accessToken: state.accessToken,
        refreshToken: state.refreshToken,
      }),
    },
  ),
);
