import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { useAuthStore } from "@/store/useAuthStore";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";

const loginSchema = z.object({
  email: z.string().email("Неверный формат email"),
  password: z.string().min(4, "Минимум 4 символа"),
});

const registerSchema = z.object({
  name: z.string().min(2, "Введите ФИО"),
  email: z.string().email("Неверный формат email"),
  phone: z.string().min(10, "Введите телефон"),
  password: z.string().min(4, "Минимум 4 символа"),
  acceptPrivacy: z.boolean().refine((value) => value, {
    message: "Необходимо согласие с политикой конфиденциальности",
  }),
});

interface AuthModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function AuthModal({ open, onOpenChange }: AuthModalProps) {
  const { login, register } = useAuthStore();
  const [tab, setTab] = useState<"login" | "register">("login");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const loginForm = useForm<z.infer<typeof loginSchema>>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
  });

  const registerForm = useForm<z.infer<typeof registerSchema>>({
    resolver: zodResolver(registerSchema),
    defaultValues: { name: "", email: "", phone: "", password: "", acceptPrivacy: false },
  });

  useEffect(() => {
    if (!open) {
      loginForm.reset();
      registerForm.reset();
      setIsSubmitting(false);
    }
  }, [open, loginForm, registerForm]);

  const onLogin = async (data: z.infer<typeof loginSchema>) => {
    setIsSubmitting(true);
    const result = await login(data.email, data.password);
    setIsSubmitting(false);

    if (result.ok) {
      toast.success("Вы успешно вошли в систему");
      onOpenChange(false);
      return;
    }
    toast.error(result.error);
  };

  const onRegister = async (data: z.infer<typeof registerSchema>) => {
    setIsSubmitting(true);
    const result = await register({
      name: data.name,
      email: data.email,
      phone: data.phone,
      password: data.password,
      acceptPrivacy: data.acceptPrivacy,
    });
    setIsSubmitting(false);

    if (result.ok) {
      toast.success("Регистрация успешна");
      onOpenChange(false);
      return;
    }
    toast.error(result.error);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle className="font-serif text-2xl text-center">Добро пожаловать</DialogTitle>
          <DialogDescription className="text-center">
            Войдите в личный кабинет или создайте аккаунт
          </DialogDescription>
        </DialogHeader>

        <Tabs value={tab} onValueChange={(value) => setTab(value as "login" | "register")} className="w-full mt-4">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="login">Вход</TabsTrigger>
            <TabsTrigger value="register">Регистрация</TabsTrigger>
          </TabsList>

          <TabsContent value="login">
            <Form {...loginForm}>
              <form onSubmit={loginForm.handleSubmit(onLogin)} className="space-y-4 mt-4">
                <FormField
                  control={loginForm.control}
                  name="email"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Email</FormLabel>
                      <FormControl>
                        <Input placeholder="email@example.com" autoComplete="email" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={loginForm.control}
                  name="password"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Пароль</FormLabel>
                      <FormControl>
                        <Input type="password" placeholder="••••" autoComplete="current-password" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <Button type="submit" className="w-full" disabled={isSubmitting}>
                  {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : "Войти"}
                </Button>
              </form>
            </Form>
          </TabsContent>

          <TabsContent value="register">
            <Form {...registerForm}>
              <form onSubmit={registerForm.handleSubmit(onRegister)} className="space-y-4 mt-4">
                <FormField
                  control={registerForm.control}
                  name="name"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>ФИО</FormLabel>
                      <FormControl>
                        <Input placeholder="Иванов Иван Иванович" autoComplete="name" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={registerForm.control}
                  name="email"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Email</FormLabel>
                      <FormControl>
                        <Input placeholder="email@example.com" autoComplete="email" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={registerForm.control}
                  name="phone"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Телефон</FormLabel>
                      <FormControl>
                        <Input placeholder="+79001234567" autoComplete="tel" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={registerForm.control}
                  name="password"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Пароль</FormLabel>
                      <FormControl>
                        <Input type="password" placeholder="••••" autoComplete="new-password" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={registerForm.control}
                  name="acceptPrivacy"
                  render={({ field }) => (
                    <FormItem className="flex flex-row items-start space-x-3 space-y-0">
                      <FormControl>
                        <Checkbox checked={field.value} onCheckedChange={field.onChange} />
                      </FormControl>
                      <div className="space-y-1 leading-none">
                        <FormLabel>Согласен с политикой конфиденциальности и обработкой персональных данных</FormLabel>
                        <FormMessage />
                      </div>
                    </FormItem>
                  )}
                />
                <Button type="submit" className="w-full" disabled={isSubmitting}>
                  {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : "Зарегистрироваться"}
                </Button>
              </form>
            </Form>
          </TabsContent>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
}
