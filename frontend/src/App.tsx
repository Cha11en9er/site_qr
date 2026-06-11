import { Switch, Route } from "wouter";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { useAuthStore } from "@/store/useAuthStore";
import { useEffect } from "react";

import NotFound from "@/pages/not-found";
import LandingPage from "@/pages/landing";
import CabinetLayout from "@/pages/cabinet/layout";
import CabinetMemorials from "@/pages/cabinet/memorials";
import CabinetCreateMemorial from "@/pages/cabinet/create-memorial";
import CabinetOrders from "@/pages/cabinet/orders";
import CabinetSettings from "@/pages/cabinet/settings";
import PublicMemorial from "@/pages/memorial/public";
import EditMemorial from "@/pages/memorial/edit";
import AdminPanel from "@/pages/admin";
import OrderSuccessPage from "@/pages/order-success";

const queryClient = new QueryClient();

function Router() {
  return (
    <div className="flex flex-col min-h-[100dvh] overflow-x-hidden">
      <Header />
      <main className="flex-1 flex flex-col">
        <Switch>
          <Route path="/" component={LandingPage} />
          <Route path="/cabinet" component={() => <CabinetLayout><CabinetMemorials /></CabinetLayout>} />
          <Route path="/cabinet/create" component={() => <CabinetLayout><CabinetCreateMemorial /></CabinetLayout>} />
          <Route path="/cabinet/orders" component={() => <CabinetLayout><CabinetOrders /></CabinetLayout>} />
          <Route path="/cabinet/settings" component={() => <CabinetLayout><CabinetSettings /></CabinetLayout>} />
          <Route path="/memorial/:id" component={PublicMemorial} />
          <Route path="/memorial/:id/edit" component={EditMemorial} />
          <Route path="/order/success" component={OrderSuccessPage} />
          <Route path="/admin" component={AdminPanel} />
          <Route component={NotFound} />
        </Switch>
      </main>
      <Footer />
    </div>
  );
}

function App() {
  const hydrateSession = useAuthStore((state) => state.hydrateSession);

  useEffect(() => {
    void hydrateSession();
  }, [hydrateSession]);

  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <Router />
        <Toaster position="top-center" richColors />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
