import mongoose, { Schema, Document } from 'mongoose';

export interface ITransaction extends Document {
  date: string;
  description: string;
  type: 'income' | 'expense';
  category: string;
  amount: number;
  reference?: string;
  method?: string;
  branchId?: number;
}

const TransactionSchema = new Schema<ITransaction>({
  date: { type: String, required: true },
  description: { type: String, required: true },
  type: { type: String, enum: ['income', 'expense'], required: true },
  category: { type: String, required: true },
  amount: { type: Number, required: true },
  reference: String,
  method: String,
  branchId: Number,
}, { timestamps: true });

export default mongoose.models.Transaction || mongoose.model<ITransaction>('Transaction', TransactionSchema);
