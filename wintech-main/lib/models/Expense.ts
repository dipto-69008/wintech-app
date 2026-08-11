import mongoose, { Schema, Document } from 'mongoose';

export interface IExpense extends Document {
  employee: string;
  date: string;
  category: string;
  description: string;
  amount: number;
  status: 'pending' | 'approved' | 'rejected' | 'paid';
  approvedBy?: string;
  branchId?: number;
}

const ExpenseSchema = new Schema<IExpense>({
  employee: { type: String, required: true },
  date: { type: String, required: true },
  category: { type: String, required: true },
  description: { type: String, required: true },
  amount: { type: Number, required: true },
  status: { type: String, enum: ['pending', 'approved', 'rejected', 'paid'], default: 'pending' },
  approvedBy: String,
  branchId: Number,
}, { timestamps: true });

export default mongoose.models.Expense || mongoose.model<IExpense>('Expense', ExpenseSchema);
