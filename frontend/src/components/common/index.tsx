import { ReactNode } from 'react';

// ── StateBadge ────────────────────────────────────────────────
const stateColours: Record<string, string> = {
  PROPOSED:               'badge-navy',
  COUNCIL_REVIEW:         'badge-accent',
  TENDERING:              'badge-teal',
  AWARDED:                'badge-teal',
  ACTIVE:                 'badge-green',
  MILESTONE_UNDER_REVIEW: 'badge-accent',
  MILESTONE_PAID:         'badge-green',
  COMPLETION_VOTE:        'badge-accent',
  COMPLETED:              'badge-green',
  DISPUTED:               'badge-red',
  EXPIRED:                'badge-navy',
  CLOSED:                 'badge-navy',
};

export function StateBadge({ state }: { state: string }) {
  return (
    <span className={stateColours[state] ?? 'badge-navy'}>
      {state.replace(/_/g, ' ')}
    </span>
  );
}

// ── MilestoneBar ──────────────────────────────────────────────
/**
 * Displays a horizontal milestone progress bar.
 * Each segment represents one milestone, coloured by its state.
 *
 * BUILD: Extend with tooltips showing milestone name + value on hover.
 */
export function MilestoneBar({ milestones }: { milestones: { state: string }[] }) {
  const colours: Record<string, string> = {
    PENDING:      'bg-slate/20',
    UNDER_REVIEW: 'bg-accent',
    PAID:         'bg-teal',
    REJECTED:     'bg-red-400',
  };
  return (
    <div className="flex gap-1 h-2 rounded-full overflow-hidden">
      {milestones.map((m, i) => (
        <div key={i} className={`flex-1 ${colours[m.state] ?? 'bg-slate/20'} rounded-full`} />
      ))}
    </div>
  );
}

// ── VoteTally ─────────────────────────────────────────────────
export function VoteTally({ upvotes, downvotes }: { upvotes: number; downvotes: number }) {
  const total = upvotes + downvotes;
  const pct = total === 0 ? 0 : Math.round((upvotes / total) * 100);
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs text-slate">
        <span>{upvotes} for</span>
        <span>{downvotes} against</span>
      </div>
      <div className="h-2 bg-slate/10 rounded-full overflow-hidden">
        <div className="h-full bg-teal rounded-full transition-all" style={{ width: `${pct}%` }} />
      </div>
      <p className="text-xs text-slate text-right">{pct}% approval</p>
    </div>
  );
}

// ── EmptyState ────────────────────────────────────────────────
export function EmptyState({ icon, title, description, action }: {
  icon?: string;
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center gap-3">
      {icon && <span className="text-4xl">{icon}</span>}
      <h3 className="font-semibold text-navy">{title}</h3>
      {description && <p className="text-sm text-slate max-w-xs">{description}</p>}
      {action}
    </div>
  );
}

// ── Spinner ───────────────────────────────────────────────────
export function Spinner({ size = 24 }: { size?: number }) {
  return (
    <div
      style={{ width: size, height: size }}
      className="border-2 border-slate/20 border-t-teal rounded-full animate-spin"
    />
  );
}

// ── PageHeader ────────────────────────────────────────────────
export function PageHeader({ title, subtitle, action }: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex items-start justify-between pt-6 pb-4">
      <div>
        <h1 className="text-xl font-bold text-navy">{title}</h1>
        {subtitle && <p className="text-sm text-slate mt-0.5">{subtitle}</p>}
      </div>
      {action}
    </div>
  );
}

// ── Card ──────────────────────────────────────────────────────
export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <div className={`card ${className}`}>{children}</div>;
}

// ── SectionDivider ─────────────────────────────────────────────
export function SectionDivider({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-3 my-4">
      <div className="flex-1 h-px bg-slate/10" />
      <span className="text-xs font-semibold text-slate uppercase tracking-widest">{label}</span>
      <div className="flex-1 h-px bg-slate/10" />
    </div>
  );
}

// ── ConfirmDialog ─────────────────────────────────────────────
/**
 * BUILD: Replace with a proper modal using a portal.
 * For now this is a placeholder component interface.
 * Recommended: use the browser's native confirm() for MVP,
 * then upgrade to a custom modal with backdrop.
 */
export function ConfirmDialog({ title, message, onConfirm, onCancel, confirmLabel = 'Confirm', danger = false }: {
  title: string;
  message: string;
  onConfirm: () => void;
  onCancel: () => void;
  confirmLabel?: string;
  danger?: boolean;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/40 p-4">
      <div className="card w-full max-w-sm space-y-4">
        <h2 className="font-bold text-navy text-lg">{title}</h2>
        <p className="text-sm text-slate">{message}</p>
        <div className="flex gap-3 pt-2">
          <button onClick={onCancel} className="btn-ghost flex-1">Cancel</button>
          <button
            onClick={onConfirm}
            className={`flex-1 font-semibold px-5 py-3 rounded-pill active:scale-95 transition-transform ${
              danger ? 'bg-red-600 text-white' : 'btn-primary'
            }`}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
