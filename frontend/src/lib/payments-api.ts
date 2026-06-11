import { apiRequest } from '@/lib/api';
import { useAuthStore } from '@/store/useAuthStore';

export interface CheckoutPayload {
  package_type: 'standard' | 'premium' | 'max';
  quantity: number;
  deceased_name: string;
  email: string;
  phone: string;
  delivery_address: string;
}

export interface CheckoutResponse {
  order_id: string;
  payment_id: string;
  confirmation_url: string;
  amount_rub: string;
}

export interface OrderStatusResponse {
  order_id: string;
  status: string;
  is_paid: boolean;
  total_amount: string;
}

export async function createCheckout(payload: CheckoutPayload): Promise<CheckoutResponse> {
  const token = useAuthStore.getState().accessToken;
  return apiRequest<CheckoutResponse>('/orders/checkout', {
    method: 'POST',
    body: JSON.stringify(payload),
    token,
  });
}

export async function getOrderStatus(orderId: string): Promise<OrderStatusResponse> {
  return apiRequest<OrderStatusResponse>(`/orders/${orderId}/status`);
}
