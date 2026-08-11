import mongoose, { Schema, Document } from 'mongoose';

export interface ILead extends Document {
  name: string;
  company?: string;
  email?: string;
  phone?: string;
  stage: 'new' | 'qualified' | 'proposal' | 'negotiation' | 'won' | 'lost';
  value: number;
  assignedTo?: string;
  notes?: string;
}

const LeadSchema = new Schema<ILead>({
  name: { type: String, required: true },
  company: String,
  email: String,
  phone: String,
  stage: { type: String, enum: ['new', 'qualified', 'proposal', 'negotiation', 'won', 'lost'], default: 'new' },
  value: { type: Number, default: 0 },
  assignedTo: String,
  notes: String,
}, { timestamps: true });

export default mongoose.models.Lead || mongoose.model<ILead>('Lead', LeadSchema);
