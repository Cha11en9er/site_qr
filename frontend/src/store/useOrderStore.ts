import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface Order {
  id: string;
  userId: string;
  email: string;
  deceasedName: string;
  packageType: 'standard' | 'premium' | 'max';
  quantity: number;
  totalPrice: number;
  deliveryAddress: string;
  phone: string;
  status: 'processing' | 'shipped' | 'delivered';
  qrCodes: string[];
  createdAt: string;
}

interface OrderState {
  orders: Order[];
  createOrder: (order: Omit<Order, 'id' | 'createdAt' | 'status' | 'qrCodes'>) => Order;
  updateOrderStatus: (id: string, status: Order['status']) => void;
}

export const useOrderStore = create<OrderState>()(
  persist(
    (set, get) => ({
      orders: [],
      createOrder: (orderData) => {
        const qrCodes = Array.from({ length: orderData.quantity }).map((_, i) => `QR-${Date.now()}-${i}`);
        const newOrder: Order = {
          ...orderData,
          id: `order-${Date.now()}`,
          status: 'processing',
          qrCodes,
          createdAt: new Date().toISOString(),
        };
        
        set(state => ({
          orders: [newOrder, ...state.orders]
        }));
        
        return newOrder;
      },
      updateOrderStatus: (id, status) => {
        set(state => ({
          orders: state.orders.map(o => o.id === id ? { ...o, status } : o)
        }));
      }
    }),
    {
      name: 'order-storage',
    }
  )
);
