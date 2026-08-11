'use client';

import { useState, useCallback } from 'react';
import { Modal } from './Modal';
import { Button } from './Button';
import { AlertTriangle } from 'lucide-react';

export function useConfirm() {
  const [state, setState] = useState<{
    open: boolean;
    title: string;
    message: string;
    onConfirm?: () => void;
  }>({ open: false, title: '', message: '' });

  const confirm = useCallback(
    ({ title, message, onConfirm }: { title: string; message: string; onConfirm: () => void }) => {
      setState({ open: true, title, message, onConfirm });
    },
    []
  );

  const Confirmation = (
    <Modal
      open={state.open}
      onClose={() => setState({ ...state, open: false })}
      title={state.title}
      size="sm"
      footer={
        <>
          <Button variant="outline" onClick={() => setState({ ...state, open: false })}>
            Cancel
          </Button>
          <Button
            variant="danger"
            onClick={() => {
              state.onConfirm?.();
              setState({ ...state, open: false });
            }}
          >
            Confirm
          </Button>
        </>
      }
    >
      <div className="flex gap-3">
        <div className="flex-shrink-0 w-10 h-10 rounded-full bg-red-50 text-red-600 flex items-center justify-center">
          <AlertTriangle className="w-5 h-5" />
        </div>
        <p className="text-sm text-slate-600">{state.message}</p>
      </div>
    </Modal>
  );

  return { confirm, Confirmation };
}
