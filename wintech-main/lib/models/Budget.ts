import mongoose, { Schema, Document } from 'mongoose';

export interface IBudget extends Document {
  dept: string;
  budget: number;
  spent: number;
  year: number;
}

const BudgetSchema = new Schema<IBudget>({
  dept: { type: String, required: true, trim: true },
  budget: { type: Number, required: true, default: 0 },
  spent: { type: Number, required: true, default: 0 },
  year: { type: Number, default: () => new Date().getFullYear() },
}, { timestamps: true });

export default mongoose.models.Budget || mongoose.model<IBudget>('Budget', BudgetSchema);
