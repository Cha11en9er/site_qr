import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuthStore } from "@/store/useAuthStore";

export default function CabinetSettings() {
  const { user } = useAuthStore();

  return (
    <div className="max-w-md">
      <h1 className="text-3xl font-serif font-medium mb-6">Настройки аккаунта</h1>

      <Card>
        <CardHeader>
          <CardTitle>Личные данные</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label>ФИО</Label>
            <Input value={user?.name || ""} disabled className="bg-muted" />
          </div>
          <div className="space-y-2">
            <Label>Email</Label>
            <Input value={user?.email || ""} disabled className="bg-muted" />
          </div>
          <div className="space-y-2">
            <Label>Телефон</Label>
            <Input value={user?.phone || ""} disabled className="bg-muted" />
          </div>
          <p className="text-sm text-muted-foreground">
            Редактирование профиля будет доступно в следующей версии API.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
