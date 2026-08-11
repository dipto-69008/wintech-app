import mongoose, { Schema, Document } from 'mongoose';

export interface IFollowUp extends Document {
  contact: string;
  company?: string;
  type: 'call' | 'email' | 'meeting';
  date: string;
  time?: string;
  note?: string;
  status: 'pending' | 'done' | 'overdue';
  priority: 'low' | 'medium' | 'high';
  assignedTo?: string;
}

const FollowUpSchema = new Schema<IFollowUp>({
  contact: { type: String, required: true },
  company: String,
  type: { type: String, enum: ['call', 'email', 'meeting'], default: 'call' },
  date: { type: String, required: true },
  time: String,
  note: String,
  status: { type: String, enum: ['pending', 'done', 'overdue'], default: 'pending' },
  priority: { type: String, enum: ['low', 'medium', 'high'], default: 'medium' },
  assignedTo: String,
}, { timestamps: true });

export default mongoose.models.FollowUp || mongoose.model<IFollowUp>('FollowUp', FollowUpSchema);
