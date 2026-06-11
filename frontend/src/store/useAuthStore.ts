import { create } from "zustand";
import { persist } from "zustand/middleware";
import {
  AppUser,
  loginRequest,
  logoutRequest,
  mapApiUser,
  meRequest,
  registerRequest,
  updateProfileRequest,
  UserProfileUpdatePayload,
} from "@/lib/auth-api";
import { ApiError } from "@/lib/api";

interface AuthState {
  user: AppUser | null;
  accessToken: string | null;
  refreshToken: string | null;
  isHydrating: boolean;
  login: (login: string, password: string) => Promise<{ ok: true } | { ok: false; error: string }>;
  register: (payload: {
    login: string;
    password: string;
    acceptPrivacy: boolean;
  }) => Promise<{ ok: true } | { ok: false; error: string }>;
  updateProfile: (
    payload: UserProfileUpdatePayload,
  ) => Promise<{ ok: true } | { ok: false; error: string }>;
  logout: () => Promise<void>;
  hydrateSession: () => Promise<void>;
  setSession: (user: AppUser, accessToken: string, refreshToken: string) => void;
}

function authErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.detail === "INVALID_CREDENTIALS") return "Неверный email или пароль";
    if (error.detail === "LOGIN_ALREADY_EXISTS") return "Пользователь с такой почтой уже существует";
    if (error.detail === "EMAIL_ALREADY_EXISTS") return "Этот email уже занят";
    if (error.detail === "PHONE_ALREADY_EXISTS") return "Этот телефон уже занят";
    if (error.detail === "INVALID_LOGIN") return "Введите корректный email";
    if (error.detail === "PRIVACY_CONSENT_REQUIRED") return "Необходимо согласие с политикой конфиденциальности";
    if (error.detail.includes("Phone")) return "Телефон укажите в формате +79001234567";
    if (error.detail === "EMAIL_OR_PHONE_REQUIRED") return "Укажите email или телефон";
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

      login: async (login, password) => {
        try {
          const response = await loginRequest({ login, password });
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

      register: async ({ login, password, acceptPrivacy }) => {
        try {
          const response = await registerRequest({
            login,
            password,
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

      updateProfile: async (payload) => {
        const token = get().accessToken;
        if (!token) {
          return { ok: false, error: "Требуется авторизация" };
        }
        try {
          const user = await updateProfileRequest(token, payload);
          set({ user: mapApiUser(user) });
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
