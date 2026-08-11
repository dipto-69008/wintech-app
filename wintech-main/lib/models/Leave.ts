import mongoose, { Schema, Document } from 'mongoose';

export interface ILeave extends Document {
  employee: string;
  type: string;
  from: string;
  to: string;
  days: number;
  reason?: string;
  status: 'pending' | 'approved' | 'rejected';
  appliedOn: string;
}

const LeaveSchema = new Schema<ILeave>({
  employee: { type: String, required: true },
  type: { type: String, required: true, default: 'Annual' },
  from: { type: String, required: true },
  to: { type: String, required: true },
  days: { type: Number, required: true, min: 0 },
  reason: String,
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' },
  appliedOn: { type: String },
}, { timestamps: true });

export default mongoose.models.Leave || mongoose.model<ILeave>('Leave', LeaveSchema);
