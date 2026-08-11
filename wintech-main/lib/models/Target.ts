import mongoose, { Schema, Document } from 'mongoose';

export interface ITarget extends Document {
  title: string;
  module: string;
  assignedTo: string;
  targetValue: number;
  currentValue: number;
  unit: string;
  deadline: string;
  status: 'on-track' | 'at-risk' | 'completed' | 'overdue';
  branchId?: number;
}

const TargetSchema = new Schema<ITarget>({
  title: { type: String, required: true },
  module: { type: String, required: true },
  assignedTo: String,
  targetValue: { type: Number, default: 0 },
  currentValue: { type: Number, default: 0 },
  unit: { type: String, default: 'BDT' },
  deadline: String,
  status: { type: String, enum: ['on-track', 'at-risk', 'completed', 'overdue'], default: 'on-track' },
  branchId: Number,
}, { timestamps: true });

export default mongoose.models.Target || mongoose.model<ITarget>('Target', TargetSchema);
