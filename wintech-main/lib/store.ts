import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface User {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'manager' | 'employee';
  avatar?: string;
}

interface AuthStore {
  user: User | null;
  isAuthenticated: boolean;
  _hasHydrated: boolean;
  login: (user: User) => void;
  logout: () => void;
  setHasHydrated: (v: boolean) => void;
}

export const useAuthStore = create<AuthStore>()(
  persist(
    (set) => ({
      user: null,
      isAuthenticated: false,
      _hasHydrated: false,
      login: (user) => set({ user, isAuthenticated: true }),
      logout: () => set({ user: null, isAuthenticated: false }),
      setHasHydrated: (v) => set({ _hasHydrated: v }),
    }),
    {
      name: 'nexerp-auth',
      onRehydrateStorage: () => (state) => {
        state?.setHasHydrated(true);
      },
    }
  )
);

export interface Branch {
  _id: string;
  name: string;
  address?: string;
  location?: string;
  manager?: string;
  phone?: string;
  status: string;
}

export interface Product {
  id: string;
  name: string;
  sku: string;
  category: string;
  price: number;
  cost: number;
  stock: number;
  minStock: number;
  unit: string;
  status: 'active' | 'inactive';
}

export interface Employee {
  id: string;
  name: string;
  email: string;
  department: string;
  position: string;
  salary: number;
  joinDate: string;
  status: 'active' | 'inactive' | 'on-leave';
  phone: string;
}

export interface SaleOrder {
  id: string;
  party: string;
  email?: string;
  date: string;
  items: { productId?: string; name: string; quantity: number; price: number; total?: number }[];
  total: number;
  status: 'draft' | 'confirmed' | 'shipped' | 'delivered' | 'cancelled';
  notes?: string;
}

export interface PurchaseOrder {
  id: string;
  supplier: string;
  date: string;
  items: { name: string; quantity: number; price: number; total?: number }[];
  total: number;
  status: 'draft' | 'ordered' | 'received' | 'cancelled';
  expectedDate?: string;
  notes?: string;
}

export interface Transaction {
  id: string;
  date: string;
  description: string;
  type: 'income' | 'expense';
  category: string;
  amount: number;
  reference?: string;
  method?: string;
}

export interface Lead {
  id: string;
  name: string;
  company: string;
  email: string;
  phone: string;
  stage: 'new' | 'qualified' | 'proposal' | 'negotiation' | 'won' | 'lost';
  value: number;
  assignedTo: string;
  createdAt: string;
}

export interface Supplier {
  id: string;
  name: string;
  email: string;
  phone: string;
  address: string;
  category: string;
  status: 'active' | 'inactive';
  totalOrders: number;
  balance: number;
}

export interface Party {
  id: string;
  name: string;
  email: string;
  phone: string;
  address: string;
  totalOrders: number;
  totalSpent: number;
  balance: number;
  status: 'active' | 'inactive';
  joinDate: string;
}

export interface Quotation {
  id: string;
  party: string;
  email?: string;
  date: string;
  validUntil: string;
  items: { name: string; quantity: number; price: number; total?: number }[];
  total: number;
  status: 'draft' | 'sent' | 'accepted' | 'rejected';
  notes?: string;
}

export interface Asset {
  id: string;
  name: string;
  category: string;
  purchaseDate: string;
  purchaseCost: number;
  currentValue: number;
  depreciationRate: number;
  location: string;
  assignedTo: string;
  status: 'active' | 'disposed' | 'under-maintenance';
  serialNumber?: string;
}

export interface Project {
  id: string;
  name: string;
  client: string;
  manager: string;
  startDate: string;
  endDate: string;
  budget: number;
  spent: number;
  status: 'planning' | 'active' | 'on-hold' | 'completed' | 'cancelled';
  priority: 'low' | 'medium' | 'high';
  progress: number;
  description?: string;
}

export interface ProjectTask {
  id: string;
  projectId: string;
  title: string;
  assignedTo: string;
  dueDate: string;
  status: 'todo' | 'in-progress' | 'review' | 'done';
  priority: 'low' | 'medium' | 'high';
}

export interface ExpenseClaim {
  id: string;
  employee: string;
  date: string;
  category: string;
  description: string;
  amount: number;
  status: 'pending' | 'approved' | 'rejected' | 'paid';
  receipt?: string;
  approvedBy?: string;
}

interface ERPStore {
  employees: Employee[];
  saleOrders: SaleOrder[];
  parties: Party[];
  products: Product[];
  suppliers: Supplier[];
  transactions: Transaction[];
  leads: Lead[];
  assets: Asset[];
  expenseClaims: ExpenseClaim[];
  branches: Branch[];
  addBranch: (b: Branch) => void;
  deleteBranch: (id: string) => void;
  updateBranch: (id: string, updates: Partial<Branch>) => void;
  addLead: (l: Lead) => void;
  updateLead: (id: string, updates: Partial<Lead>) => void;
  deleteLead: (id: string) => void;
  updateSaleOrder: (id: string, updates: Partial<SaleOrder>) => void;
}

// ── Global Branch Filter ──
interface BranchFilterStore {
  selectedBranchId: string;
  selectedBranchName: string;
  selectedBranchLegacyId: number | null;
  setSelectedBranch: (id: string, name: string, legacyId: number | null) => void;
}
export const useBranchStore = create<BranchFilterStore>()(
  persist(
    (set) => ({
      selectedBranchId: '',
      selectedBranchName: '',
      selectedBranchLegacyId: null,
      setSelectedBranch: (id, name, legacyId) =>
        set({ selectedBranchId: id, selectedBranchName: name, selectedBranchLegacyId: legacyId }),
    }),
    { name: 'nexerp-branch-filter' }
  )
);

export const useERPStore = create<ERPStore>()(() => ({
  employees: [],
  saleOrders: [],
  parties: [],
  products: [],
  suppliers: [],
  transactions: [],
  leads: [],
  assets: [],
  expenseClaims: [],
  branches: [],
  addBranch: () => {},
  deleteBranch: () => {},
  updateBranch: () => {},
  addLead: () => {},
  updateLead: () => {},
  deleteLead: () => {},
  updateSaleOrder: () => {},
}));
